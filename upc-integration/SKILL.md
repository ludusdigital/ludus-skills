---
name: upc-integration
description: Vodi kroz kompletnu integraciju UPC (UniCredit/Raiffeisen) payment gateway-a u Next.js + Supabase aplikaciju — uključujući RSA potpisivanje, inicijalno plaćanje sa tokenizacijom, MIT (Merchant Initiated Transactions) za rekurzivne pretplate, webhook handler, callback handler i cron za obnavljanje. Koristi ovaj skill kad god korisnik kaže "integriši UPC", "dodaj UPC plaćanja", "UPC payment gateway", "Raiffeisen kartično plaćanje", "rekurzivna pretplata sa karticom", "MIT transakcije", "ECG gateway", "ecommerce.raiffeisenbank.rs", "platni servis Raiffeisen banke", ili bilo koju varijantu integracije UPC e-Commerce Connect Gateway-a (RBRS terminal). Skill obuhvata generisanje ključeva, env varijable, SQL migracije, lib/upc/ modul, API rute, server actions, checkout formu i kritične nijanse naučene na produkciji (Delay=0 u formi i potpisu, SHA1 za potpisivanje payment-a a RS256 za JWS, verifikacija notifikacija RSA-SHA512 uz SHA1 fallback, OrderID max 12 karaktera, locale=en, tri aktivaciona puta sa dokazom uplate, nikad automatski reverse, Cloudflare WAF skip pravilo za NOTIFY, PurchaseTime identičan u status query-ju).
---

# UPC Payment Gateway Integracija

Skill koji vodi kroz integraciju **UPC e-Commerce Connect Gateway-a** (Raiffeisen Bank Serbia / RBRS terminal) u Next.js + Supabase aplikaciju. Odražava stanje **live implementacije u ovom repou** (avgust 2026) — kod je izvor istine, reference ispod su sažetak.

UPC pokriva:
- Jednokratna plaćanja kartice + tokenizacija (UseToken=1, TokenRecurringModel=M)
- **MIT (Merchant Initiated Transactions)** za rekurzivne pretplate (JWS RS256 na payByToken)
- Token-based naplata bez prisustva korisnika (token se čuva AES-256-GCM enkriptovan)
- Refund / Reversal (endpoint repayment u produkciji)
- Order status query (JSON/JWS na service/01)

---

## Najvažnije invarijante (ako ništa drugo ne čitaš)

1. **Delay=0** — direktna naplata, u FORMI i u POTPISU. Delay=1 je pre-autorizacija koja zahteva ručni capture svake transakcije u merchant portalu i lomi automatsku aktivaciju. Banka je avgusta 2026. eksplicitno tražila 0.
2. **Potpisivanje (naša strana)** = RSA-SHA1 (PKCS1 v1.5), base64; **verifikacija bankinih notifikacija** = RSA-**SHA512** primarno, SHA1 samo fallback (PHP primer sa SHA1 NE važi za RBRS produkciju — dokazano brute-force-om stvarnog webhook-a 2026-08-07). MIT ide kao JWS **RS256** (RSA-SHA256).
3. **Aktivacija SAMO uz dokaz uplate** — redirect/query parametri se NIKAD ne veruju. Tri dokaziva puta: (1) NOTIFY webhook sa validnim potpisom banke (primarni), (2) callback forma koja NOSI isti RSA potpis kao webhook + TranCode=000 + iznos match sa DB, (3) server-to-server status query.
4. **Response.action= reverse se NIKAD ne šalje automatski** — to je nalog banci da stornira transakciju. Sve greške na našoj strani → HTTP 500 (UPC ponovi notifikaciju 3× sa ~20s pauze).
5. **Status query zahteva IDENTIČAN PurchaseTime** koji je payment forma poslala — 12-cifreni YYMMDDHHMMSS u TZ servera. Čuva se u platform_subscriptions.purchase_time pri checkout-u (migracija 20260807120000); 14-cifreni format iz zvanične dokumentacije NE radi na RBRS.
6. **UPC_PUBLIC_KEY je javni ključ GATEWAY-A** (iz work-server.CRT), ne naš merchant ključ. Bez njega verifikacija fail-closed odbija sve notifikacije.
7. **Cloudflare Browser Integrity Check obara bankin S2S POST pre aplikacije** — obavezan WAF Custom Rule Skip za /api/upc/webhook POST sa IP 217.13.180.171 (+ 195.85.198.15).
8. Webhook odgovor je **tekst** (text/plain), ne JSON; Response.action= approve (sa razmakom posle =).

---

## Pre nego što počneš

Pitaj korisnika:

1. **Imaš li već ugovor sa Raiffeisen bankom + MerchantID/TerminalID?** (Bez ovoga ne može da se testira)
2. **Imaš li već generisane RSA ključeve i poslat .crt fajl banci?**
3. **Da li ti treba samo jednokratno plaćanje ili rekurzivne pretplate (subscription)?**
4. **Koja je arhitektura projekta?** — Personal accounts (auth.users.id = accounts.id) ili team accounts?

Ako koraci 1-2 nisu završeni — uputi korisnika na sekciju **„Setup sa bankom"** ispod i pauziraj dok ne dobiješ MerchantID i TerminalID.

---

## Setup sa bankom (jednokratno)

### 1. Generisanje RSA ključeva (OpenSSL)

```bash
# 1. Privatni ključ (čuvaj tajno!)
openssl genrsa -out {MerchantID}.pem 2048

# 2. Javni ključ
openssl rsa -in {MerchantID}.pem -pubout -out {MerchantID}.pub

# 3. Sertifikat za banku (CN = MerchantID)
openssl req -new -x509 -key {MerchantID}.pem -out {MerchantID}.crt -days 365 -config config.dat
```

config.dat šablon je u [references/signature-spec.md](references/signature-spec.md).

### 2. Slanje banci

- .crt fajl pošalji Raiffeisen banci (pos@raiffeisenbank.rs)
- Traži aktivaciju:
  - **tokenizacije** (UseToken=1)
  - **MIT transakcija** sa SCAExemption=03 (Recurring) ako trebaju pretplate
  - **Delay=0** (direktna naplata) — Delay=1 (pre-auth) uvodi ručni capture svake transakcije
  - **Refund preko API-ja** — bez toga refund vraća TranCode 455 („odbijen, omogućava se na zahtev") i ide ručno kroz portal

### 3. Šta ćeš dobiti od banke

- MerchantID (15 karaktera)
- TerminalID (8 karaktera, počinje slovom — npr. E7880293)
- Pristup test konzoli: https://ecg.test.upc.ua/rbrs/merchant/
- Pristup produkcijskoj konzoli: https://ecommerce.raiffeisenbank.rs/rbrs/merchant
- UPC javni ključ (server.cert / **work-server.CRT**) za verifikaciju potpisa u webhook-u — **OVO je vrednost za UPC_PUBLIC_KEY** (openssl x509 -in work-server.CRT -pubkey -noout), NE tvoj merchant ključ! Sertifikat može imati istekao rok (UPC-ov je iz 2005!) — nebitno, koristi se samo javni ključ. Ako fali, traži od banke „production server certificate for NOTIFY signature verification".

---

## Implementacija — workflow

Implementiraj po koracima, **NE skoči redove**:

### Korak 1 — Env varijable

Dodaj u apps/web/.env.development (i produkcijski equivalent):

```bash
# UPC obavezne
UPC_MERCHANT_ID=                    # od banke (15 char)
UPC_TERMINAL_ID=                    # od banke (8 char, npr. E7880293)
UPC_IS_PRODUCTION=false             # true u produkciji
NEXT_PUBLIC_APP_URL=                # https://yourdomain.com

# UPC ključevi — OBAVEZAN je bar jedan od UPC_PRIVATE_KEY_BASE64 / UPC_PRIVATE_KEY
UPC_PRIVATE_KEY_BASE64=             # PREPORUKA: ceo PEM base64-enkodovan u jednu liniju
# ili UPC_PRIVATE_KEY (raw PEM sa \n karakterima)
# (UPC_PRIVATE_KEY_PATH se čita u key loader-u, ali Zod config validacija
#  zahteva bar jedan od prva dva — path-only setup pada na validaciji.)

UPC_PUBLIC_KEY=                     # javni ključ UPC GATEWAY-a (iz work-server.CRT) — bez njega webhook/callback fail-closed

# Za enkripciju tokena u bazi (AES-256-GCM)
TOKEN_ENCRYPTION_KEY=               # base64 od 32 bajta (vidi generisanje dole)

# Za cron za rekurzivne pretplate
CRON_SECRET=                        # random secret za zaštitu /api/upc/recurring (ruta fail-closed bez njega)
```

**Generisanje UPC_PRIVATE_KEY_BASE64:**
```bash
base64 -i {MerchantID}.pem | tr -d '\n'
```

Napomena: Coolify često čuva env vrednosti duplo base64-enkodovane — key loader u signature.ts to toleriše (takođe escaped \n, PKCS#1 i PKCS#8 format). Ne menjaj tu robusnost.

**Generisanje TOKEN_ENCRYPTION_KEY:**
```bash
openssl rand -base64 32
```
Kod radi Buffer.from(env, base64) i zahteva tačno 32 bajta — **base64, NE hex** (stari skill je pisao rand -hex 32; to NE radi sa live kodom).

### Korak 2 — SQL migracije

U ovom repou UPC šema je već primenjena. Live migracije (izvor istine — čitaj ih pre izmena):

| Migracija | Šta dodaje |
|---|---|
| 20260126100000_recurring_subscription_support.sql | enum-ovi (payment_provider sa raiaccept+upc, subscription_interval), UPC kolone na platform_subscriptions (provider, plan_id/name, interval, upc_token(_exp), masked_pan, current_period_*, cancel_at_period_end, order_id), status CHECK, subscription_transactions, RPC-ovi has_active_platform_subscription, get_current_platform_subscription, upsert_upc_subscription, record_subscription_transaction, get_subscriptions_due_for_renewal, extend_subscription_period |
| 20260201100000_payment_tokens.sql | payment_tokens (encrypted_token, token_fingerprint unique, is_active/revoked_at), token RPC-ovi, get_subscriptions_due_for_renewal prebačen na payment_tokens INNER JOIN, cancel_subscription/resume_subscription (ownership-check preko auth.uid()) |
| 20260324100000_discount_codes.sql | discount kolone (discount_code_id, original_amount, discount_remaining_months) + RPC proširen za njih |
| 20260403200000_fix_upsert_order_id.sql | UPDATE grana upsert_upc_subscription sada ažurira i order_id/amount/plan/interval (retry checkout sa novim order_id) |
| 20260801200000_subscription_write_lockdown.sql | **BEZBEDNOST**: upsert_upc_subscription/record_subscription_transaction samo service_role; REVOKE UPDATE ON platform_subscriptions od korisnika; brisanje RLS policy-ja za update. Cancel/resume idu isključivo kroz ownership-checked RPC-ove |
| 20260807120000_upc_purchase_time.sql | platform_subscriptions.purchase_time (TEXT) — tačan PurchaseTime iz payment forme za status query |
| 20260808150000_discount_claim_on_payment.sql | potrošnja discount koda se beleži tek pri uplati |

Za novi projekat: sažetak šeme u [references/database-schema.sql](references/database-schema.sql). Posle svake migracije ručno ažuriraj tipove u apps/web/lib/database.types.ts i packages/supabase/src/database.types.ts (produkcija je izvor istine; typegen generiše tačno tako).

### Korak 3 — Core UPC modul (apps/web/lib/upc/)

| Fajl | Šta radi |
|---|---|
| config.ts | Zod env validacija (fail-fast na pogrešnom env-u), endpoint mapa TEST vs PRODUCTION, pricing planovi (monthly 1870 RSD, yearly 29000 RSD), generateUpcOrderId() (max 12 char!), formatUpcAmount()/parseUpcAmount(), buildUpcCallbackUrls() |
| types.ts | TypeScript interfejsi za request/response, UPC_TRAN_CODES, getUpcErrorMessage() na srpskom, SubscriptionStatus |
| signature.ts | getPrivateKey() (robustni loader), getUpcPublicKey() (SPKI/PKCS#1/X.509/goli base64, nikad ne baca), generateSignature() (RSA-SHA1), verifySignature() (**sha512 → sha1 fallback, fail-closed, nikad ne baca**), formatPurchaseTime() (12-cifreni), formatStatusPurchaseTime() (14-cifreni, SAMO za dijagnostički sweep), debugSignatureGeneration() |
| openssl-sign.ts | generateSignatureNodeJS() + buildPaymentSignatureData() + legacy OpenSSL-CLI varijanta (PHP paritet) |
| jws.ts | JWS compact encoder/decoder za MIT (RS256) + **JSON/JWS envelope za status query** (buildJsonJwsRequest, decodeJsonJwsPayload) |
| client.ts | buildPaymentFormData() (Delay=0, UseToken=1, PurchaseTime opcija), buildPaymentRedirectHtml(), executeMitPayment(), processWebhookNotification() (4 varijante baze), getOrderStatus() (JSON/JWS), reverseTransaction(), refundTransaction() |
| index.ts | Barrel export |

Šabloni sinhronizovani sa live kodom: [references/code-templates.md](references/code-templates.md).

**KRITIČNO — ne improvizuj signature:**
- Payment forma se POTPISUJE RSA-SHA1 (PKCS1 v1.5): crypto.sign(sha1, data, { padding: RSA_PKCS1_PADDING })
- Verifikacija bankinih notifikacija: crypto.createVerify(sha512) pa fallback sha1 (RBRS produkcija potpisuje SHA512!)
- MIT (JWS) spoljašnji potpis je RS256 (RSA-SHA256); unutrašnje Signature polje MIT payload-a je RSA-SHA1 nad mit bazom
- Payment baza: MerchantID;TerminalID;PurchaseTime;OrderID,Delay;Currency;TotalAmount;SD; — **OrderID i Delay zarezom-odvojeni unutar jedne tačka-zarez sekcije**, sve se završava ;, SD uvek prazno u potpisu
- Detalji + sve baze: [references/signature-spec.md](references/signature-spec.md)

### Korak 4 — API rute

#### app/api/upc/webhook/route.ts (server-to-server NOTIFY, primarni aktivacioni put)

- POST, form-encoded; enhanceRouteHandler(..., { auth: false })
- Čitaj **raw text** body-ja (potreban za dijagnostiku baze potpisa), parsiraj u URLSearchParams
- processWebhookNotification(params) proba 4 varijante baze: sa UPCToken-om notifyToken → notify → notifyTokenNoDelay → notifyNoDelay, bez njega notify → notifyToken → notifyNoDelay → notifyTokenNoDelay
- **Nevalidan potpis / fali OrderID-TranCode / pretplata nije nađena / pad DB upisa POSLE uspešne naplate → HTTP 500** (UPC ponavlja). NIKAD Response.action= reverse — to stornira legitimnu uplatu; falsifikator bi njime mogao stornirati TUĐU uplatu.
- Pronađi platform_subscriptions po order_id (admin/service-role client — RLS bypass je nameran, autorizacija = RSA potpis banke)
- Upsert transakcije u subscription_transactions (onConflict: order_id — idempotentnost pri retry-ju)
- TranCode=000: aktiviraj pretplatu (status active, paid_at, period start/end po intervalu, expires_at), sačuvaj ProxyPan u masked_pan, sačuvaj token (vidi Korak 5), pa pokreni post-purchase hookove (vidi Korak 6b)
- Fail (≠000) i pretplata pending → status=failed
- Odgovor je TEKST (ne JSON!), Content-Type: text/plain; charset=utf-8, HTTP 200:
```
MerchantID = ...
TerminalID = ...
OrderID = ...
Delay = 0
Currency = 941
TotalAmount = ...
XID = ...
PurchaseTime = ...
Response.action= approve
Response.reason= ok
Response.forwardUrl= 
```
- **Nikad ne loguj raw payload** — nosi plaintext UPCToken.

#### app/api/upc/callback/route.ts (browser redirect nakon plaćanja)

- POST i GET. GET **nikad ništa ne aktivira** — samo redirektuje (za GA4 purchase parametre).
- CSRF: u ovom repou proxy.ts matcher već isključuje ceo /api/ — ništa se ne dodaje. U drugom projektu isključi /api/upc/callback iz CSRF middleware-a (UPC POST-uje sa eksternog domena).
- POST: redirect parametri su **nepouzdan dokaz** (korisnik ih može falsifikovati). Aktivacija ide isključivo:
  1. webhook je već aktivirao (status = active/paid) → samo redirect na success;
  2. **potpisana forma**: UPC callback forma nosi ISTI RSA potpis kao NOTIFY webhook → processWebhookNotification(formParams) + TranCode=000 + parseUpcAmount(TotalAmount) === amount u DB → dokaz uplate, aktiviraj;
  3. inače **status query** server-to-server (getOrderStatus sa purchase_time iz DB) → aktiviraj samo uz tranCode 000.
- Aktivacija ponavlja istu logiku kao webhook (period, token, hookovi — sve idempotentno).
- Redirect: uspeh → /home/courses?purchase_order={orderId}&amount={...}&currency=RSD (PurchaseTracker URL mode); fail → /home/billing?status=failed&provider=upc&error={tranCode} — uvek 303.

#### app/api/upc/recurring/route.ts (cron za obnavljanje)

- POST i GET (Coolify/Vercel cron), auth Authorization: Bearer ${CRON_SECRET}; **fail-closed**: bez CRON_SECRET u env-u ruta vraća 500 i NE radi ništa (ne naplaćuje se ništa bez zaštite).
- get_subscriptions_due_for_renewal() (service-role RPC): UPC pretplate statusa active/paid/past_due, cancel_at_period_end=false, current_period_end <= now() + 1 day, aktivan neistekao token u payment_tokens.
- Za svaku: token = decryptToken(encrypted_token) (novi format) ili legacy upc_token sa samog reda; nov orderId; executeMitPayment() (JWS RS256, SCAExemption=03, MITReason=S); insert transakcije; uspeh → extend_subscription_period() + discount dekrement (discount_remaining_months - 1; kad padne na 0 → amount = original_amount).
- Fail: **PERMANENT_FAILURE_CODES** (101, 102, 103, 104, 116, 119, 121, 200, 903) → status=expired + revoke aktivnog tokena; sve ostalo → status=past_due (retry sledeći ciklus).

Detalji request/response formata: [references/webhook-spec.md](references/webhook-spec.md).

### Korak 5 — Token enkripcija (lib/crypto/token-encryption.ts)

UPC token omogućava naplatu bez korisnika — **mora biti enkriptovan u bazi** (live kod: apps/web/lib/crypto/token-encryption.ts):
- AES-256-GCM; IV 12 random bajtova; AuthTag 16 bajtova
- Format u bazi (JSON, **base64** vrednosti): {"iv":"<b64>","authTag":"<b64>","ciphertext":"<b64>"}
- TOKEN_ENCRYPTION_KEY = base64 od 32 bajta (openssl rand -base64 32)
- Fingerprint = SHA-256 hex plaintext-a → payment_tokens.token_fingerprint (UNIQUE indeks)
- Pri čuvanju novog tokena: deaktiviraj sve postojeće aktivne tokene za (account_id, provider), pa insertuj novi
- Ako enkripcija NIJE konfigurisana → legacy fallback: upc_token/upc_token_exp kolone na samoj pretplati (sa warn logom)

### Korak 6 — Servisni sloj i server actions

Lokacija (data fetching arhitektura iz apps/web/AGENTS.md):

```
apps/web/app/home/(user)/billing/
├── _lib/server/
│   ├── upc.service.ts                # createUpcService() klasa (server-only)
│   ├── upc-server-actions.ts         # "use server" + enhanceAction
│   ├── upc-billing-page.loader.ts    # Async loader za page.tsx (read-only)
│   └── discount.service.ts           # validateDiscountCode + recordDiscountUsageOnPayment
├── _components/
│   └── upc-checkout-form.tsx         # "use client" checkout UI (samo yearly plan)
├── page.tsx                          # Server component (SubscriptionStatusCard + UpcCheckoutForm)
└── success/page.tsx                  # verifyAndUpdatePayment() + PurchaseTracker (props mode)
```

**Server actions** (upc-server-actions.ts): createUpcCheckoutSession({planId, discountCode}), validateDiscountCodeAction, getUpcSubscriptionStatus, verifyUpcPayment({orderId}), cancelUpcSubscription({reason}), resumeUpcSubscription, getUpcTransactionHistory.

**Service** (upc.service.ts):
- createPlatformCheckout(planId, discountCode) — requireUser, provera aktivne pretplate, generisanje orderId, validacija discount koda (BEZ trošenja), **generisanje purchaseTime PRE forme i persistanje na pending red** (status query zahteva tačnu vrednost; created_at je racy legacy fallback), pending red preko upsert_upc_subscription **admin klijentom** (service_role only od lockdown-a), potom update purchase_time/discount/affiliate kolona, signed form HTML
- executeRecurringPayment(subscriptionId) — MIT poziv (legacy varijanta; cron koristi route direktno)
- cancelSubscription() / resumeSubscription() — kroz ownership-checked RPC-ove (korisnici više nemaju UPDATE pravo na tabelu!)
- verifyAndUpdatePayment(orderId) — treći aktivacioni put (status query) + isti post-purchase hookovi
- getCurrentSubscription() / hasActiveSubscription() / getTransactionHistory()

### Korak 6b — Post-purchase hookovi (SVAKI aktivacioni put ih MORA zvati)

Posle potvrđene uplate (webhook, callback, status query) — sve **best-effort + idempotentne**, redom:
1. recordDiscountUsageOnPayment(subscription) — potrošnja discount koda TEK uz uplatu (napušten checkout ne blokira kod)
2. recordAffiliateReferral(...) — samo ako affiliate_code postoji na redu (UNIQUE affiliate+kupac)
3. recordPaymentAttribution(account_id) — marketing first_payment_at
4. sendWelcomeEmail(account_id, subscription_id) — dedupe kroz lifecycle_email_log

Atribucija: ?ref=KOD → proxy upisuje lv_ref httpOnly cookie (30 dana) → pri checkout-u affiliate_code na pending redu → konverzija pri aktivaciji. Svaki NOVI aktivacioni put MORA dodati sva četiri bloka.

### Korak 7 — Checkout UI komponenta (upc-checkout-form.tsx)

1. Prikaz plana sa cenom + discount input (validacija kroz validateDiscountCodeAction)
2. **OBAVEZAN checkbox: "Upoznat/a sam sa opštim uslovima kupovine"** — Raiffeisen banka eksplicitno zahteva; bez njega odbijaju merchant aplikaciju
3. **OBAVEZNI logotipi**: Raiffeisen co-brand (Visa/Mastercard/DinaCard) + Visa Secure + Mastercard Identity Check (live fajlovi: /images/Logo_Co_brand_RGB_svetla_pozadina_96dpi.svg, /images/visa-secure_blu_2021.png, /images/mc_idcheck_vrt_rgb_pos.png)
4. Klik → trackEvent(checkout_started, ...) → createUpcCheckoutSession() → ubaci vraćeni HTML u DOM i form.submit() (auto-redirect na UPC)
5. GA4 purchase event: PurchaseTracker — URL mode (callback redirect nosi purchase_order params) + props mode (billing/success stranica); dedup po order id-u u localStorage

### Korak 8 — Cron za rekurzivne pretplate

Coolify Scheduled Task:

```bash
# Svako jutro, npr. 6:00
curl -fsS -X POST https://yourdomain.com/api/upc/recurring \
  -H "Authorization: Bearer ${CRON_SECRET}"
```

### Korak 9 — Verifikacija

```bash
bun run typecheck
bun run lint
bun run format
```

Plus test transakcije sa test karticama (banka daje listu) preko test gateway-a, i dijagnostičke skripte (ispod).

---

## Pravila i nijanse (često se promaše)

1. **Locale**: UPC NE PODRŽAVA sr — koristi en. sr fail-uje sa nejasnom greškom.
2. **OrderID**: max **12 karaktera**. timestamp.slice(-8) + 4 random cifre (živi generateUpcOrderId).
3. **Delay=0**: direktna naplata — u FORMI i POTPISU (kompozitna sekcija OrderID,Delay). Delay=1 = pre-autorizacija, ručni capture svake transakcije, status upit ne vraća uspeh do capture-a → lomi automatiku.
4. **SD (Session Data)**: u potpisu **uvek prazno**, čak i ako je u formi popunjeno.
5. **PurchaseTime format**: 12 cifara YYMMDDHHMMSS, lokalno vreme servera (produkcija CEST). **Status query zahteva identičnu vrednost** — čuvaj je u platform_subscriptions.purchase_time pri checkout-u; created_at je samo legacy fallback (trka: red se upisuje posle forme i može u sledeću sekundu). 14-cifreni DDMMYYYYHHMMSS iz zvanične dokumentacije NE radi na RBRS (postoji samo kao formatStatusPurchaseTime za dijagnostički sweep).
6. **TotalAmount**: najmanje jedinice (pare), bez decimala. RSD 290.00 → "29000".
7. **Currency code**: 941=RSD, 978=EUR, 840=USD (ISO 4217 numerički). Platforma naplaćuje samo RSD.
8. **SCAExemption=03** za MIT recurring — bez ovoga UPC odbija kodom 450 („Recurrent payments are prohibited"). Banka mora da omogući.
9. **MITReason=S** (Subscription); U=unscheduled, D=delayed, R=resubmission.
10. **Webhook response format**: tekst (NE JSON), Content-Type: text/plain; charset=utf-8, HTTP 200 samo uz approve. Greške na našoj strani → HTTP 500. Response.action= approve (razmak posle =!).
11. **CSRF**: u ovom repou proxy.ts matcher isključuje ceo api/ — callback je već pokriven. U drugim projektima dodaj izuzetak za /api/upc/callback (UPC POST-uje sa eksternog domena).
12. **TranCode=000 = success**; sve drugo je fail. Mapiranje u [references/tran-codes.md](references/tran-codes.md).
13. **Token enkripcija je OBAVEZNA** u produkciji (compliance + ako curi baza neko naplaćuje sve korisnike).
14. **Tri aktivaciona puta, svaki sa dokazom**: webhook (RSA potpis banke, primarni) → potpisana callback forma (isti potpis + TranCode 000 + amount match) → status query (server-to-server). Redirect parametri BEZ dokaza se NIKAD ne tretiraju kao uplata. Idempotentnost: webhook upsert-uje transakciju po order_id i može stići više puta; callback/success aktiviraju samo pending redove.
15. **UPC retry-uje webhook 3×** sa ~20s pauze — zato 5xx (ne reverse) za prolazne greške.
16. **reverse NIKAD automatski**: Response.action= reverse = nalog banci da stornira (TranCode 503 „Transaction canceled by the store"). Samo ručna, svesna odluka (npr. eksplicitni refund zahtev korisnika kroz admin), nikad na grešku integracije.
17. **⚠️ CLOUDFLARE/WAF OBARA WEBHOOK**: bankin S2S POST (User-Agent Jakarta Commons-HttpClient/3.1, bez browser fingerprinta) pada na Browser Integrity Check PRE aplikacije — u app logovima nema NIČEGA. Fix: WAF Custom Rule **Skip** (min. Browser Integrity Check; preporuka i Managed rules — ruta ionako verifikuje RSA potpis) za uslov http.request.uri.path eq "/api/upc/webhook" and http.request.method eq "POST" and ip.src in {217.13.180.171 195.85.198.15}. Dokumentovani NOTIFY IP-evi: PROD 217.13.180.171 (Raiffeisen Informatik, AT — empirijski potvrđen) i 195.85.198.15; TEST 18.196.61.127, 3.120.143.246, 18.197.170.36. „Allow" u IP Access Rules NE preskače Browser Integrity Check — mora WAF Skip pravilo.
18. **Refund preko API-ja banka mora da OMOGUĆI** — TranCode 455 znači „odbijen, omogućava se na zahtev". Inače refund ručno kroz merchant portal.
19. **Ključevi**: UPC_PUBLIC_KEY mora biti ključ GATEWAY-a, ne naš. getUpcPublicKey() toleriše SPKI PEM / PKCS#1 / X.509 sertifikat / goli Base64 i **nikad ne baca** — pogrešan format je avgusta 2026. (ERR_OSSL_ASN1_WRONG_TAG) oborio i webhook i callback. Verifikacija fail-closed: bez ključa → false (odbij sve, nikad return true).
20. **Potpis normalizacija**: form-parser pretvara + u razmak u Base64 potpisu — pre verifikacije vrati razmak u + (verifySignature to radi).
21. **Status query** (getOrderStatus): request = JSON {"header","payload","signature"} (RS256 nad header.payload, standardni Base64), POST application/json na service/01; payload = MerchantID, TerminalID, OrderID, Currency, TotalAmount, PurchaseTime; odgovor = isti oblik (gateway potpisuje RS512 — trenutno se samo dekodira), payload.results[] sa tranCode/operType/amount... uspeh = tranCode: "000" uz operType: "PURCHASE" (REFUND redovi se ignorišu).
22. **Lockdown**: korisnici NEMAJU write pristup platform_subscriptions — sve write operacije idu kroz admin (service-role) klijent ili ownership-checked RPC (cancel_subscription, resume_subscription). Ne vraćaj stare grantove.
23. **Endpoints (produkcija)**: GATEWAY .../rbrs/pay, PAY_BY_TOKEN .../rbrs/payByToken, STATUS .../rbrs/service/01, REVERSAL i REFUND .../rbrs/repayment, COMPLETE .../rbrs/capture. TEST: isti putevi na ecg.test.upc.ua (REVERSAL reversal, REFUND refund, COMPLETE complete).

---

## Dijagnostičke skripte (apps/web/scripts/)

| Skripta | Šta radi |
|---|---|
| check-upc-keys.ts | Da li je UPC_PUBLIC_KEY slučajno NAŠ merchant ključ umesto gateway-ovog (poredi SHA-256 fingerprint-e, ne ispisuje ključeve) |
| check-upc-order-status.ts | Ručni status query nad realnim orderom (--order, --amount u dinarima, --created-at ISO ili --time); automatski proba varijante PurchaseTime-a. Lokalno uz TZ=Europe/Belgrade |
| find-upc-notify-base.ts | Brute-force baze potpisa iz uhvaćenog raw body-ja + work-server.CRT (offline, kad verifikacija opet zakaže) |

Pokretanje skripti zahteva env (grep iz .env.development) i NODE_OPTIONS=--conditions=react-server (zbog server-only importa).

---

## Production checklist (pre go-live)

- [ ] Generisani i banci poslati RSA ključevi (.crt)
- [ ] Dobijeni produkcijski MerchantID i TerminalID
- [ ] Tokenizacija + MIT omogućeni na terminalu; **Delay=0** u kodu; refund preko API-ja omogućen od banke
- [ ] Test transakcije uspešne (success, fail, recurring, refund)
- [ ] Webhook vraća tekstualni format; **reverse se NIKAD ne šalje automatski** (sopstvene greške → HTTP 500)
- [ ] **UPC_PUBLIC_KEY** = javni ključ gateway-a (openssl x509 -in work-server.CRT -pubkey -noout) — bez njega sve notifikacije fail-closed
- [ ] Verifikacija potpisa radi — uključujući tokenizovanu varijantu (notifyToken baze)
- [ ] **Cloudflare/WAF Skip pravilo za NOTIFY IP** (217.13.180.171 + 195.85.198.15 → /api/upc/webhook, min. Browser Integrity Check) — pa PROVERI u logovima da webhook stvarno stiže (Security Analytics filter na IP ako ne stiže)
- [ ] Status query testiran nad realnim orderom (scripts/check-upc-order-status.ts vraća tranCode 000)
- [ ] Probno plaćanje end-to-end: u logu proveri KOJI put je aktivirao (webhook / potpis forme / status query) — bar dva od tri
- [ ] UPC_IS_PRODUCTION=true; NEXT_PUBLIC_APP_URL = produkcijski HTTPS domen
- [ ] TOKEN_ENCRYPTION_KEY (base64 32 bajta) postavljen i NIKADA u repo; tokeni idu u payment_tokens enkriptovani
- [ ] CRON_SECRET postavljen; cron za /api/upc/recurring podešen
- [ ] Logotipi + „Opšti uslovi kupovine" checkbox na checkout strani; Terms of Service sa svim obaveznim sekcijama
- [ ] Idempotentnost webhook-a testirana (duplikat ne pravi duplikat transakcije ni produženje perioda)
- [ ] Logging kroz @kit/shared/logger; raw payload (UPCToken!) se NE loguje

---

## Kontakti za podršku

- UPC tehnička: ec@upc.ua (samo engleski)
- Raiffeisen merchant: pos@raiffeisenbank.rs
- Test merchant portal: https://ecg.test.upc.ua/rbrs/merchant/
- Production merchant portal: https://ecommerce.raiffeisenbank.rs/rbrs/merchant

---

## Reference fajlovi

- [references/signature-spec.md](references/signature-spec.md) — Sve potpisne baze, algoritmi, JWS i JSON/JWS status encoding, primeri i edge case-evi
- [references/database-schema.sql](references/database-schema.sql) — Referentni sažetak šeme (tabele + RPC); live migracije u apps/web/supabase/migrations/ su izvor istine
- [references/webhook-spec.md](references/webhook-spec.md) — Webhook/callback request/response formati, verifikacija, IP + Cloudflare, retry strategija
- [references/tran-codes.md](references/tran-codes.md) — Lista UPC TranCode-ova sa srpskim porukama + PERMANENT vs TEMPORARY klasifikacija za recurring
- [references/code-templates.md](references/code-templates.md) — TypeScript šabloni sinhronizovani sa live kodom (config, signature, jws, client, webhook, callback, recurring, service, crypto)

Live kod (izvor istine): apps/web/lib/upc/*, apps/web/app/api/upc/*, apps/web/app/home/(user)/billing/_lib/server/upc*.ts, apps/web/lib/crypto/token-encryption.ts, migracije apps/web/supabase/migrations/*upc* + 20260126100000_recurring_subscription_support.sql + 20260201100000_payment_tokens.sql + 20260801200000_subscription_write_lockdown.sql.
