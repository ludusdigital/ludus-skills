# UPC Webhook + Callback specifikacija (sinkronizovano sa live kodom, avgust 2026)

UPC ima **dva odvojena toka** za obaveštavanje merchanta o ishodu plaćanja:

1. **NOTIFY_URL (webhook)** — server-to-server POST, **primarni izvor istine** (RSA potpis banke)
2. **URL_RETURN / URL_RETURN_OK / URL_RETURN_NO (callback)** — browser POST redirect; **callback forma NOSI isti RSA potpis kao webhook** pa je verifikovana forma validan dokaz uplate (fallback kad webhook ne stigne)

Aktivacija pretplate se dešava SAMO uz dokaz (potpis banke ili server-to-server status query). Redirect/query parametri bez potpisa se NIKAD ne tretiraju kao dokaz uplate.

---

## 1. Webhook (NOTIFY_URL)

### 1.1 Request od UPC-a

**Endpoint**: `POST {NOTIFY_URL}` koji šalješ u inicijalnom payment request-u.

**Content-Type**: `application/x-www-form-urlencoded`

**Polja u body-ju** (primer sa tokenizacijom — banka još ne šalje UPCToken na RBRS, ali kod pokriva oba slučaja):

```
MerchantID=1752493
TerminalID=E7880293
OrderID=240115123456
PurchaseTime=240115140000
Delay=0
Currency=941
TotalAmount=187000
XID=A1B2C3D4E5F6G7H8I9J0K1L2M3N4
SD=
TranCode=000
ApprovalCode=758508
Rrn=827512375132
ProxyPan=499999*******0011
UPCToken=254484C162EEC13E5B012736288683AC
UPCTokenExp=2912
Signature=BASE64_RSA_SHA512_SIGNATURE
```

| Polje | Format | Šta znači |
|---|---|---|
| `OrderID` | string | Tvoj ID koji si poslao u initial request (max 12 char) |
| `TranCode` | `000` = success | Bilo šta drugo = fail (vidi tran-codes.md) |
| `ApprovalCode` | n6 | Autorizacioni kod, čuvaj za refund |
| `Rrn` | n12 | Retrieval Reference Number, takođe za refund |
| `XID` | an28 | Transaction identifier |
| `ProxyPan` | string | Maskirani PAN (npr. `499999*******0011`) — čuva se u `masked_pan` |
| `UPCToken` | an..32 | **Token za buduće naplate** (SAČUVAJ enkriptovano, NIKAD u log) |
| `UPCTokenExp` | YYMM | Datum isteka tokena |
| `Signature` | base64 | RBRS produkcija potpisuje **RSA-SHA512** |

### 1.2 Verifikacija potpisa

```typescript
import { processWebhookNotification } from '~/lib/upc';

// Čitaj RAW TEXT body (dijagnostika baze potpisa), pa parsiraj:
const rawBody = await request.text();
const params: Record<string, string> = {};
new URLSearchParams(rawBody).forEach((value, key) => { params[key] = String(value); });

const notification = processWebhookNotification(params);
if (!notification.isValid) {
  // NIKAD Response.action= reverse!
  // 5xx = UPC ponovi notifikaciju (3× sa ~20s pauze)
  return new Response('Signature verification failed', { status: 500 });
}
```

`processWebhookNotification` proba 4 varijante baze (notify / notifyToken / notifyNoDelay / notifyTokenNoDelay — redosled u signature-spec.md) i algoritme sha512 → sha1. Nevalidan potpis može značiti i nepodešen/pogrešan `UPC_PUBLIC_KEY` — verifikacija je fail-closed.

### 1.3 Response format (OBAVEZAN)

**KRITIČNO**: Webhook NE vraća JSON. Vraća **tekstualni format** sa parovima `key = value`:

```
MerchantID = 1752493
TerminalID = E7880293
OrderID = 240115123456
Delay = 0
Currency = 941
TotalAmount = 187000
XID = A1B2C3D4E5F6G7H8I9J0K1L2M3N4
PurchaseTime = 240115140000
Response.action= approve
Response.reason= ok
Response.forwardUrl= 
```

**Pravila:**
- `Content-Type: text/plain; charset=utf-8`
- HTTP status **200** SAMO uz `approve` i uspešnu obradu
- `Response.action` može biti **`approve`** (prihvati) ili **`reverse`** (UPC će STORNIRATI transakciju)
- `Response.forwardUrl` — prazno ili puni URL za redirect korisnika
- `Response.action= approve` — **razmak posle `=`**

**Šablon helper-a (live kod):**
```typescript
function buildUpcResponse(
  params: Record<string, string>,
  action: 'approve' | 'reverse',
  reason: string,
): string {
  const lines = [
    `MerchantID = ${params.MerchantID ?? ''}`,
    `TerminalID = ${params.TerminalID ?? ''}`,
    `OrderID = ${params.OrderID ?? ''}`,
    `Delay = ${params.Delay ?? ''}`,
    `Currency = ${params.Currency ?? ''}`,
    `TotalAmount = ${params.TotalAmount ?? ''}`,
    `XID = ${params.XID ?? ''}`,
    `PurchaseTime = ${params.PurchaseTime ?? ''}`,
    `Response.action= ${action}`,
    `Response.reason= ${reason}`,
    `Response.forwardUrl= `,
  ];
  return lines.join('\n');
}
```

### 1.4 Kada vratiti `reverse`? — NIKAD automatski

`Response.action= reverse` je **nalog banci da stornira transakciju** (TranCode 503 „Transaction canceled by the store"). Automatski reverse:
- stornira legitimne uplate kad je greška na NAŠOJ strani (nepodešen UPC_PUBLIC_KEY, pad DB upisa POSLE naplate),
- omogućava falsifikatoru da stornira TUĐU uplatu podmetanjem pravog OrderID-a.

| Situacija | Odgovor | Zašto |
|---|---|---|
| Signature ne prolazi verifikaciju | **HTTP 500** | UPC ponavlja; može biti naš pogrešan ključ — ne storniraj |
| `OrderID` nije pronađen u bazi | **HTTP 500** | Checkout uvek pravi pending red pre gateway-a — ovo je DB outage/anomalija |
| Fali OrderID/TranCode | **HTTP 500** | malformisan payload ne sme ništa da poništi |
| Update u bazi fail-uje (POSLE uspešne naplate) | **HTTP 500** | uplata je PROŠLA — retry aktivaciju, ne storno |
| Neočekivani exception | **HTTP 500** | isto kao gore |
| Sve OK | 200 + `approve` | |

`reverse` se šalje isključivo ručnom, svesnom odlukom (npr. eksplicitni refund kroz admin tooling), nikad iz webhook handlera na grešku.

### 1.5 Idempotentnost

- UPC pokušava webhook **3 puta** sa razmakom od **20 sekundi**
- Webhook se može pozvati i više puta (retry + callback + status query rade paralelno)
- Live kod: transakcija se **upsert-uje po `order_id`** (`onConflict: order_id`) — duplikat ne pravi duplikat
- Aktivacija i token storage su idempotentni po prirodi (update istih vrednosti; deaktivacija postojećih tokena pre inserta novog)
- Post-purchase hookovi (discount usage, affiliate, attribution, welcome email) su svi idempotentni

### 1.6 IP adrese + Cloudflare (produkcija)

| Okruženje | NOTIFY IP |
|---|---|
| Production | **`217.13.180.171`** (Raiffeisen Informatik, AT — empirijski potvrđen) i `195.85.198.15` (starija dokumentacija) |
| Test | `18.196.61.127`, `3.120.143.246`, `18.197.170.36` |

**⚠️ Cloudflare WAF obara webhook**: bankin S2S POST (User-Agent tipa `Jakarta Commons-HttpClient/3.1`, bez browser fingerprinta) pada na **Browser Integrity Check PRE aplikacije** — u app logovima nema NIČEGA. Fix:
- WAF Custom Rule sa akcijom **Skip** (min. Browser Integrity Check; preporuka i Managed rules — ruta ionako verifikuje RSA potpis)
- Uslov: `http.request.uri.path eq "/api/upc/webhook" and http.request.method eq "POST" and ip.src in {217.13.180.171 195.85.198.15}`
- „Allow" u IP Access Rules NE preskače Browser Integrity Check — mora Skip pravilo
- Dijagnoza: Cloudflare Security Analytics, filter na source IP

---

## 2. Callback (URL_RETURN_OK / URL_RETURN_NO)

### 2.1 Šta je callback

Browser redirect nakon plaćanja: korisnik klikne „Plati" na UPC stranici → UPC ga POST-om šalje na `URL_RETURN_OK` ili `URL_RETURN_NO`. Live ruta je `/api/upc/callback` (query `status=success|failed&order=...`).

**Karakteristike:
- Dolazi od korisnika u browser-u — **redirect parametri se NIKAD ne veruju kao dokaz**
- POST body NOSI **isti RSA potpis kao NOTIFY webhook** (ista polja, bez `Delay` polja u formi — zato `notifyNoDelay` varijante) — verifikovana forma + TranCode 000 + iznos match sa DB **jeste** validan dokaz
- Može da fail-uje (korisnik zatvori tab) — zato postoji i status query fallback
- GET callback **nikad ništa ne aktivira** — samo redirektuje

### 2.2 CSRF

U ovom repou `proxy.ts` matcher isključuje ceo `/api/` prefiks (`/((?!_next/static|_next/image|images|locales|assets|api/).*)`) — callback je već izuzet. U drugom projektu isključi `/api/upc/callback` iz CSRF middleware-a (eksterni POST bez CSRF tokena).

### 2.3 Implementacija (live logika, kondenzovano)

```typescript
export async function POST(request: NextRequest) {
  const formData = await request.formData();
  const searchParams = request.nextUrl.searchParams;

  const formParams: Record<string, string> = {};
  formData.forEach((value, key) => { formParams[key] = value.toString(); });

  const status = searchParams.get('status') ?? formData.get('status')?.toString();
  const orderId = searchParams.get('order') ?? formData.get('OrderID')?.toString();
  const tranCode = formData.get('TranCode')?.toString();

  // Šta browser TVRDI — NIJE dokaz
  const clientReportedSuccess = tranCode === '000' || status === 'success';
  let paymentVerified = false; // postavlja se SAMO server-side dokazom

  if (clientReportedSuccess && orderId) {
    const sub = /* lookup po order_id */;

    if (sub.status === 'active' || sub.status === 'paid') {
      paymentVerified = true; // webhook je već aktivirao
    } else if (sub.status === 'pending') {
      // PUT 1: potpisana forma (isti RSA potpis kao webhook) + TranCode 000 + amount match
      const formNotification = processWebhookNotification(formParams);
      const formAmountMatches = parseUpcAmount(formParams.TotalAmount ?? '') === Number(sub.amount);

      if (formNotification.isValid && isUpcTransactionSuccessful(formNotification.TranCode) && formAmountMatches) {
        paymentVerified = true;
      } else {
        // PUT 2: server-to-server status query — PurchaseTime iz DB (purchase_time, created_at samo fallback)
        const verification = await getOrderStatus(orderId, Number(sub.amount), '941',
          sub.purchase_time ?? formatPurchaseTime(new Date(sub.created_at)));
        paymentVerified = verification.success && isUpcTransactionSuccessful(verification.response.TranCode);
      }
    }

    if (paymentVerified && sub.status === 'pending') {
      // aktivacija (period, token, hookovi) — ista logika kao webhook, sve idempotentno
    }
  }

  const baseUrl = process.env.NEXT_PUBLIC_APP_URL ?? request.nextUrl.origin;
  const redirectUrl = paymentVerified
    ? `${baseUrl}/home/courses?purchase_order=${orderId}&amount=${amount}&currency=RSD`
    : `${baseUrl}/home/billing?status=failed&provider=upc${tranCode ? `&error=${tranCode}` : ''}`;
  return NextResponse.redirect(redirectUrl, { status: 303 });
}
```

Napomene: raw payload se NIKAD ne loguje (UPCToken); fail-redirect uvek 303 na billing sa `status=failed`; success ide na `/home/courses` sa `purchase_order` parametrima zbog GA4 PurchaseTracker (URL mode).

---

## 3. Šta ide u inicijalni payment request

Da bi webhook + callback funkcionisali, payment forma mora da nosi URL-ove (live `buildUpcCallbackUrls`):

```typescript
const urls = {
  successUrl: `${baseUrl}/api/upc/callback?status=success&order=${orderId}`,
  failUrl: `${baseUrl}/api/upc/callback?status=failed`,
  notifyUrl: `${baseUrl}/api/upc/webhook`,
};

const formData = {
  // ... ostala polja ...
  URL_RETURN: urls.successUrl,
  URL_RETURN_OK: urls.successUrl,
  URL_RETURN_NO: urls.failUrl,
  NOTIFY_URL: urls.notifyUrl,
};
```

Zašto `/api/upc/callback` umesto direktnih stranica: (1) API rute su već van CSRF middleware-a u ovom repou, (2) server-side verifikacija uplate mora da se desi pre redirect-a, (3) redirect može da nosi GA4 purchase parametre.
