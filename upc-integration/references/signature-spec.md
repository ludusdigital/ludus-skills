# UPC Signature Spec — kompletna specifikacija (sinkronizovano sa live kodom, avgust 2026)

UPC koristi **RSA potpise** za autentifikaciju zahteva. Algoritam zavisi od smera i tipa operacije:

| Operacija | Algoritam | Padding | Encoding | Endpoint |
|---|---|---|---|---|
| Inicijalno plaćanje (redirect) — MI potpisujemo | **RSA-SHA1** | PKCS1 v1.5 | base64 | /rbrs/pay |
| Webhook/callback NOTIFY — BANKA potpisuje, mi verifikujemo | **RSA-SHA512** (RBRS produkcija; SHA1 samo fallback) | PKCS1 v1.5 | base64 | NOTIFY_URL / browser callback |
| MIT (Recurring) — spoljašnji JWS potpis | **RS256 (RSA-SHA256)** | PKCS1 v1.5 | base64url | /rbrs/payByToken |
| MIT (Recurring) — unutrašnje Signature polje payload-a | **RSA-SHA1** nad mit bazom | PKCS1 v1.5 | base64 | (unutar JWS payload-a) |
| Order status query — mi potpisujemo | **RS256** nad header.payload | PKCS1 v1.5 | standardni base64 | /rbrs/service/01 |
| Order status query — BANKA potpisuje odgovor | **RS512** (trenutno se samo dekodira, ne verifikuje) | PKCS1 v1.5 | standardni base64 | /rbrs/service/01 |
| Reversal / Refund — mi potpisujemo | **RSA-SHA1** | PKCS1 v1.5 | base64 | /rbrs/repayment (prod) |

**ZAPAMTI**: potpisivanje naših zahteva = SHA1 (legacy zahtev banke) osim JWS-a; verifikacija bankinih notifikacija = **SHA512 pa SHA1 fallback** — PHP primer iz dokumentacije (openssl_verify default SHA1) NE važi za RBRS produkciju (dokazano 2026-08-07 brute-force-om pravog uhvaćenog webhook-a).

---

## 1. Generisanje RSA ključeva

### config.dat (za sertifikat)

```ini
[ req ]
prompt = no
distinguished_name = req_distinguished_name

[ req_distinguished_name ]
C=RS                            # Država (2 slova)
ST=Serbia                       # Region
L=Belgrade                      # Grad
O=YourCompany                   # Naziv organizacije (kako je registrovana)
OU=ECOMMERCE                    # Odeljenje (uvek "ECOMMERCE")
CN={MerchantID}                 # Common Name = MerchantID (broj koji ti banka daje)
emailAddress=tech@example.com
```

### Generisanje (OpenSSL)

```bash
# Privatni ključ — 2048-bit RSA
openssl genrsa -out {MerchantID}.pem 2048

# Javni ključ — kao backup (banci NE treba)
openssl rsa -in {MerchantID}.pem -pubout -out {MerchantID}.pub

# Sertifikat — ovo ide banci
openssl req -new -x509 -key {MerchantID}.pem -out {MerchantID}.crt -days 365 -config config.dat
```

### Provera

```bash
openssl rsa -in {MerchantID}.pem -check -noout
openssl rsa -in {MerchantID}.pem -pubout
```

### Encoding za env varijable

```bash
# UPC_PRIVATE_KEY_BASE64 — PREPORUKA za produkciju
base64 -i {MerchantID}.pem | tr -d '\n'

# Test da možeš da je dekoduješ nazad
echo "$BASE64_STRING" | base64 -d | head -3
# Trebalo bi da vidiš: -----BEGIN RSA PRIVATE KEY-----
```

Napomena: key loader u live `signature.ts` toleriše duplo base64-enkodovane vrednosti (Coolify), escaped `\n`, PKCS#1 i PKCS#8 PEM i golie Base64 body — nemoj to da "pojednostavljuješ". `UPC_PUBLIC_KEY` se parsira kao SPKI PEM / PKCS#1 / X.509 sertifikat / goli Base64 i **nikad ne baca** (fail-closed: vraća null).

---

## 2. Signature data format

### 2.1 Inicijalno plaćanje (payment)

**Format stringa za hash:**
```
MerchantID;TerminalID;PurchaseTime;OrderID,Delay;Currency;TotalAmount;SD;
```

**Pravila:**
- Polja su odvojena tačka-zarezom (`;`)
- String se **ZAVRŠAVA tačka-zarezom**
- `OrderID,Delay` je **jedna sekcija** sa zarezom unutra (NE dve sekcije)
- `SD` (Session Data) je **uvek prazno** u potpisu (čak i kad ga šaljemo u formi)
- Ako neko polje nedostaje, ostavi prazno ali ne briši `;` (broj separatora mora biti konstantan)
- **Delay je "0"** u produkciji (direktna naplata) — i u formi i u potpisu

**Primer (Delay=0):**
```
{MerchantID};E0000000;260129160000;123456789012,0;941;187000;;
                                 ^^^
                                 OrderID=123456789012, Delay=0
                                                           ^
                                                           SD prazno
```

### 2.2 NOTIFY webhook / callback — baze za verifikaciju

> **Dokazano na produkciji (2026-08-07, brute-force pravog uhvaćenog webhook-a):** RBRS potpisuje NOTIFY bazom `MerchantID;TerminalID;PurchaseTime;OrderID,Delay;XID;Currency;TotalAmount;SD;TranCode;ApprovalCode;` pod **RSA-SHA512**.

Live `processWebhookNotification()` proba 4 varijante baze (redosled zavisi od prisustva UPCToken-a):

| Varijanta | Baza | Kada |
|---|---|---|
| `notify` | `MerchantID;TerminalID;PurchaseTime;OrderID,Delay;XID;Currency;TotalAmount;SD;TranCode;ApprovalCode;` | server-to-server NOTIFY (sadrži Delay polje) — **dokazana produkcijska** |
| `notifyToken` | ista + sufiks `UPCToken,UPCTokenExp;` | tokenizovane transakcije (UseToken=1) — banka još ne uključuje tokenizaciju na RBRS, ostavljeno za budućnost |
| `notifyNoDelay` | ista ali bez `,Delay` posle OrderID | browser callback forma NEMA Delay polje |
| `notifyTokenNoDelay` | NoDelay + token sufiks | callback forma sa tokenom |

Sa UPCToken-om redosled: `notifyToken → notify → notifyTokenNoDelay → notifyNoDelay`. Bez njega: `notify → notifyToken → notifyNoDelay → notifyTokenNoDelay`.

**Pre verifikacije**: potpis se normalizuje (` ` → `+` — form-parser pretvara `+` u razmak), i probaju se algoritmi `sha512` pa `sha1`. Ako nijedna varijanta ne prođe → `isValid=false`. Ako prođe fallback varijanta — warn log (koja je varijanta prošla ti govori kako RBRS stvarno potpisuje).

### 2.3 MIT (Recurring) — JWS payload

**Polja u JSON payload-u** (pre encoding-a):
```json
{
  "MerchantID": "{MerchantID}",
  "TerminalID": "E0000000",
  "OrderID": "260201123456",
  "Currency": "941",
  "TotalAmount": "187000",
  "UPCToken": "254484C162EEC13E5B012736288683AC",
  "PurchaseTime": "260201120000",
  "SCAExemption": "03",
  "MITReason": "S",
  "Signature": "<RSA-SHA1 potpis>"
}
```

**Sekvenca operacija:**
1. Unutrašnji potpis (mit baza — bez Delay/SD):
   ```
   MerchantID;TerminalID;PurchaseTime;OrderID;Currency;TotalAmount;UPCToken;
   ```
   RSA-SHA1, base64 → ide u `Signature` polje payload-a
2. Ceo JSON payload se enkoduje u JWS (RS256):
   - Header: `{"alg":"RS256","typ":"JWT"}` → base64url
   - Payload: ceo JSON → base64url
   - Signature: RSA-SHA256 potpis `header.payload` → base64url
3. Slanje: `POST /rbrs/payByToken` body: `headerB64.payloadB64.sigB64`
4. Content-Type: `text/plain`; odgovor se dekodira kao JWS (`decodeJws`)

### 2.4 Order status query — JSON/JWS envelope (service/01)

Form-encoded varijanta vraća "text page" nedefinisanog formata i NE koristi se. Live kod koristi JSON/JWS:

- Request: JSON objekat `{"header","payload","signature"}`
  - header = standardni Base64 od `{"alg":"RS256"}`
  - payload = standardni Base64 od JSON-a: `MerchantID, TerminalID, OrderID, Currency, TotalAmount, PurchaseTime`
  - signature = RS256 nad `header.payload` (standardni Base64, openssl stil)
- POST `application/json` na `/rbrs/service/01`
- Odgovor: isti envelope (gateway potpisuje RS512 — live kod trenutno samo dekodira payload)
- payload sadrži `{"results":[{tranCode, approvalCode, rrn, amount, operType, ...}]}` — uspeh = `tranCode: "000"` uz `operType: "PURCHASE"` (REFUND redovi se ignorišu)

**KRITIČNO — PurchaseTime**: mora biti **IDENTIČAN** vrednosti koju je payment forma poslala: 12-cifreni `YYMMDDHHMMSS` u TZ servera (produkcija CEST). Vrednost se čuva u `platform_subscriptions.purchase_time` pri checkout-u; `created_at` je samo racy legacy fallback. 14-cifreni `DDMMYYYYHHMMSS` primer iz zvanične dokumentacije NE radi na RBRS (empirijski 2026-08-04) — `formatStatusPurchaseTime()` postoji samo za dijagnostički sweep u `scripts/check-upc-order-status.ts`.

---

## 3. Code reference: signature.ts (kondenzovano, tačno)

```typescript
import 'server-only';
import crypto from 'crypto';

const SIGNATURE_FIELDS = {
  payment: ['MerchantID', 'TerminalID', 'PurchaseTime', 'OrderID,Delay', 'Currency', 'TotalAmount', 'SD'],
  notify: ['MerchantID', 'TerminalID', 'PurchaseTime', 'OrderID,Delay', 'XID', 'Currency', 'TotalAmount', 'SD', 'TranCode', 'ApprovalCode'],
  notifyToken: ['MerchantID', 'TerminalID', 'PurchaseTime', 'OrderID,Delay', 'XID', 'Currency', 'TotalAmount', 'SD', 'TranCode', 'ApprovalCode', 'UPCToken,UPCTokenExp'],
  notifyNoDelay: ['MerchantID', 'TerminalID', 'PurchaseTime', 'OrderID', 'XID', 'Currency', 'TotalAmount', 'SD', 'TranCode', 'ApprovalCode'],
  notifyTokenNoDelay: ['MerchantID', 'TerminalID', 'PurchaseTime', 'OrderID', 'XID', 'Currency', 'TotalAmount', 'SD', 'TranCode', 'ApprovalCode', 'UPCToken,UPCTokenExp'],
  mit: ['MerchantID', 'TerminalID', 'PurchaseTime', 'OrderID', 'Currency', 'TotalAmount', 'UPCToken'],
  status: ['MerchantID', 'TerminalID', 'OrderID', 'Currency', 'TotalAmount', 'TranCode', 'ApprovalCode'],
  reversal: ['MerchantID', 'TerminalID', 'OrderID', 'Currency', 'TotalAmount'],
  refund: ['MerchantID', 'TerminalID', 'OrderID', 'Currency', 'TotalAmount'],
} as const;

function buildSignatureData(params: Record<string, string | undefined>, fields: readonly string[]): string {
  return fields
    .map((field) => {
      if (field.includes(',')) {
        // Compound field (npr. "OrderID,Delay") — zarezom odvojeno unutar iste sekcije
        return field.split(',').map((sf) => params[sf] ?? '').join(',');
      }
      return params[field] ?? '';
    })
    .join(';') + ';';
}

export function generateSignature(params, type) {
  const data = buildSignatureData(params, SIGNATURE_FIELDS[type]);
  return crypto
    .sign('sha1', Buffer.from(data, 'utf8'), {
      key: getPrivateKey(), // robustni loader iz signature.ts
      padding: crypto.constants.RSA_PKCS1_PADDING,
    })
    .toString('base64');
}

export function verifySignature(params, signature, type): boolean {
  // NIKAD ne baca — bacaenje ovde obara webhook/callback i njihove fallback puteve
  try {
    const publicKey = getUpcPublicKey(); // ključ GATEWAY-a (work-server.CRT), ne naš
    if (!publicKey) {
      // FAIL-CLOSED: bez bankinog ključa ne možemo ništa da verifikujemo.
      // (Stara verzija je ovde vraćala true — to je dozvoljavalo falsifikate!)
      return false;
    }
    const data = buildSignatureData(params, SIGNATURE_FIELDS[type]);
    // form-parser pretvara + u razmak u Base64 potpisu — vrati ih
    const normalizedSignature = signature.replace(/ /g, '+');
    // RBRS produkcija: RSA-SHA512. SHA1 ostaje fallback (test gateway).
    for (const algorithm of ['sha512', 'sha1'] as const) {
      const verify = crypto.createVerify(algorithm);
      verify.update(data);
      verify.end();
      if (verify.verify(publicKey, normalizedSignature, 'base64')) return true;
    }
    return false;
  } catch (error) {
    console.error('UPC signature verification error:', error);
    return false;
  }
}
```

---

## 4. JWS encoding (za MIT) — korektan sažetak

```typescript
function base64UrlEncode(data: string | Buffer): string {
  const base64 = Buffer.isBuffer(data) ? data.toString('base64') : Buffer.from(data).toString('base64');
  return base64.replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '');
}

export function encodeJws<T extends object>(payload: T): string {
  const header = { alg: 'RS256', typ: 'JWT' };
  const headerB64 = base64UrlEncode(JSON.stringify(header));
  const payloadB64 = base64UrlEncode(JSON.stringify(payload));
  const sign = crypto.createSign('RSA-SHA256');
  sign.update(headerB64 + '.' + payloadB64);
  sign.end();
  // getPrivateKey() se deli sa signature.ts — jedan izvor istine
  return headerB64 + '.' + payloadB64 + '.' + base64UrlEncode(sign.sign(getPrivateKey()));
}
```

---

## 5. Verifikacija — pre nego što pošalješ banci

### Self-verify (sanity check):

```typescript
const params = {
  MerchantID: '{MerchantID}',
  TerminalID: 'E0000000',
  PurchaseTime: '260129160000',
  OrderID: '123456789012',
  Delay: '0', // Delay=0 — direktna naplata
  Currency: '941',
  TotalAmount: '187000',
  SD: '',
};

const signature = generateSignature(params, 'payment');
const privKey = getPrivateKey();
const merchantPubKey = crypto.createPublicKey(privKey);
const data = buildSignatureData(params, SIGNATURE_FIELDS.payment);
const verify = crypto.createVerify('SHA1');
verify.update(data);
verify.end();
console.log('Self-verify:', verify.verify(merchantPubKey, signature, 'base64')); // mora biti true
```

### Slanje banci za verifikaciju (rana faza):

Pošalji banci konkretan signature data string, base64 potpis i public key extrahovan iz privatnog (`openssl rsa -in {MerchantID}.pem -pubout`). Ako ne prolazi — najčešći razlozi: mešanje SHA1 vs SHA256, Delay van OrderID sekcije, izostavljen trailing `;`, PKCS#1 vs PKCS#8 konfuzija.

---

## 6. Common errors

| Greška | Uzrok | Fix |
|---|---|---|
| `405 Signature is invalid` | Pogrešan data format ili algoritam | Proveri da je `Delay` u istoj sekciji kao `OrderID`, da li SHA1 za payment |
| `406 Quota of transactions exceeded` | Više pokušaja u kratkom roku | Sačekaj, banka ima rate limit u test okruženju |
| `460 Token service not enabled` | Tokenizacija nije aktivirana | Banka mora da uključi UseToken na terminalu |
| `450 Recurrent payments are prohibited` | MIT/SCAExemption=03 nije aktivirana | Banka mora da odobri MIT na terminalu |
| `455` na refund | Refund preko API-ja nije omogućen | Banka mora da omogući; inače refund ručno kroz portal |
| `crypto.createPrivateKey threw` | Loš PEM format u env varijabli | Koristi UPC_PRIVATE_KEY_BASE64; loader toleriše dupli base64 i oba PKCS formata |
| Webhook stalno `Signature verification failed` | UPC_PUBLIC_KEY je naš ključ, pogrešan format ili WAF obara POST | Pokreni `scripts/check-upc-keys.ts`; proveri Cloudflare Security Analytics na source IP |
| Verifikacija je obarala rutu (exception) | getUpcPublicKey je bacao na loš format | Live kod nikad ne baca — fail-closed false (ne vraćaj staro ponašanje) |
