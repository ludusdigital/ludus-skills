# UPC TranCode reference

Svaka UPC transakcija vraća `TranCode` u response-u. **`000` znači success, sve drugo je fail.**

---

## Success

| Kod | Značenje |
|---|---|
| `000` | Transaction successful / Approved |

---

## Decline (banka odbila karticu — najčešće)

| Kod | Engleski | Srpski (poruka za korisnika) |
|---|---|---|
| `002` | General decline | Transakcija odbijena |
| `003` | Contact issuer | Kontaktirajte banku |
| `004` | Pick up card | Zadržite karticu (problem sa karticom) |
| `005` | Do not honor | Banka odbila — kontaktirajte banku |
| `012` | Invalid transaction | Nevalidna transakcija |
| `013` | Invalid amount | Nevalidan iznos |
| `014` | Invalid card | Nevalidna kartica |
| `033` | Expired card | Kartica je istekla |
| `034` | Fraud suspected | Sumnja na prevaru |
| `036` | Restricted card | Kartica je ograničena |
| `038` | PIN attempts exceeded | Prekoračen broj pokušaja PIN-a |
| `051` | Insufficient funds | Nedovoljno sredstava |
| `057` | Transaction not permitted to cardholder | Transakcija nije dozvoljena za karticu |
| `058` | Transaction not permitted to terminal | Vrsta transakcije nije dozvoljena |
| `061` | Exceeds withdrawal limit | Prekoračen dnevni/mesečni limit |
| `063` | Security violation | Bezbednosna greška |

---

## Authorization (problemi sa kartom)

| Kod | Engleski | Komentar |
|---|---|---|
| `101` | Invalid card / Invalid expiration date | Kartica neispravna ili istekla |
| `105` | Not approved by issuer | Banka kartice nije odobrila |
| `108` | Lost or stolen card | Prijavljena kao izgubljena/ukradena |
| `111` | Non-existent card | Kartica ne postoji |
| `116` | Insufficient funds | Nema dovoljno sredstava |
| `130` | Limit exceeded | Prekoračen limit |
| `290` | Issuer not accessible | Banka kartice nije dostupna |
| `291` | Technical/Communication problem | Tehnički problem (mreža) |

---

## Gateway errors (problem sa našim zahtevom — debug u kodu)

| Kod | Engleski | Šta proveriti |
|---|---|---|
| `401` | Invalid format | Polja u request-u — format, dužina, tip |
| `402` | Invalid Acquirer/Merchant data | `MerchantID` / `TerminalID` pogrešni |
| `405` | **Signature is invalid** | RSA potpis nije validan — vidi signature-spec.md |
| `406` | Quota of transactions exceeded | Rate limit (test okruženje strože) |
| `407` | Merchant is not active | Merchant nije aktiviran kod banke |
| `410` | Order was already paid (replay) | Pokušaj re-use istog `OrderID` |
| `432` | Card is in stop list | Kartica je na stop listi |
| `450` | **Recurrent payments are prohibited** | MIT nije aktiviran — banka mora da omogući |
| `460` | Token service not enabled | Tokenizacija nije aktivirana — banka mora |

---

## Operational errors

| Kod | Engleski | Komentar |
|---|---|---|
| `501` | Canceled by user | Korisnik je odustao na UPC stranici |
| `502` | Web session expired | Korisnik je predugo stajao na UPC stranici |
| `503` | Canceled by merchant | Mi smo poslali `Response.action= reverse` |
| `506` | Preauthorization expired | Pre-auth nije captured u 30 dana |
| `507` | Already processed | Ovaj `OrderID` je već obrađen |
| `510` | Refund expired | Prošlo je preko 6 meseci od originalne transakcije |
| `512` | Repeated reversal/refund | Već je urađen reversal/refund |

---

## Klasifikacija za recurring cron

Kad MIT (recurring) plaćanje fail-uje, treba da odlučiš da li je **permanentni fail** (pretplata expired, token revoked) ili **privremeni** (past_due, retry sledeći ciklus):

### PERMANENT_FAILURE_CODES (subscription → `expired`, token → revoked)

```typescript
const PERMANENT_FAILURE_CODES = [
  '101', // Card expired
  '102', // Card suspended
  '103', // Card blocked
  '104', // Card lost/stolen
  '116', // Insufficient funds (posle više pokušaja)
  '119', // Transaction not permitted
  '121', // Exceeds withdrawal limit
  '200', // Do not honor
  '903', // Invalid transaction
];

function isPermanentFailure(tranCode: string): boolean {
  return PERMANENT_FAILURE_CODES.includes(tranCode);
}
```

### TEMPORARY_FAILURE (subscription → `past_due`, retry sledeći cron)

Sve ostalo (npr. `051` insufficient funds prvi put, `290` issuer down, `291` network issue).

Postavi `status = 'past_due'`, sledeći cron pokušaj će retry-ovati.

---

## Srpske poruke za UI

```typescript
export function getUpcErrorMessage(tranCode: string): string {
  const messages: Record<string, string> = {
    '000': 'Transakcija uspešna',
    '002': 'Transakcija odbijena',
    '003': 'Kontaktirajte banku',
    '004': 'Zadržite karticu',
    '005': 'Banka odbila plaćanje',
    '012': 'Nevalidna transakcija',
    '013': 'Nevalidan iznos',
    '014': 'Nevalidna kartica',
    '033': 'Kartica je istekla',
    '034': 'Sumnja na prevaru',
    '036': 'Kartica je ograničena',
    '038': 'Prekoračen broj pokušaja PIN-a',
    '051': 'Nedovoljno sredstava na kartici',
    '057': 'Transakcija nije dozvoljena za karticu',
    '058': 'Vrsta transakcije nije dozvoljena',
    '061': 'Prekoračen limit',
    '063': 'Bezbednosna greška',
    '100': 'Nevalidan trgovac',
    '101': 'Nevalidan terminal',
    '102': 'Narudžbina nije pronađena',
    '103': 'Duplikat narudžbine',
    '104': 'Nevalidan potpis',
    '106': 'Sistemska greška',
    '107': 'Isteklo vreme za plaćanje',
    '108': 'Nevalidan token',
    '109': 'Token istekao',
    '110': '3DS verifikacija neuspešna',
    '501': 'Plaćanje otkazano',
    '502': 'Sesija istekla',
  };
  return messages[tranCode] ?? `Greška pri plaćanju (kod ${tranCode})`;
}
```

---

## Debug saveti

| Problem | Šta proveriti |
|---|---|
| Stalno dobijam `405 Invalid signature` | Provierili da li koristiš SHA1 (ne SHA256), da li je Delay unutar `OrderID,Delay` sekcije, da li PEM ključ matchuje `.crt` poslat banci |
| Test transakcija prolazi sa kodom `000` ali se ne aktivira pretplata | Webhook nije pozvan ili je vratio reverse — proveri logove i `NOTIFY_URL` da li je validan HTTPS URL dostupan iz interneta |
| MIT odbija sa `450 Recurrent prohibited` | Banka nije aktivirala MIT — pošalji email `pos@raiffeisenbank.rs` da omoguće SCAExemption='03' |
| `460 Token service not enabled` | Tokenizacija nije aktivirana — banka mora da uključi `UseToken` flag na terminalu |
| `406 Quota exceeded` u test okruženju | Test ima striktan rate limit — sačekaj 1h ili koristi novi `OrderID` |
| `502 Session expired` | Korisnik je predugo stajao na UPC stranici (>15min) — sačekaj retry |
