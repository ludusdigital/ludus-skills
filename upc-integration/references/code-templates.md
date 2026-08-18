# UPC Code Templates — šabloni sinhronizovani sa live kodom (avgust 2026)

> **VAŽNO**: ovo su SAŽETI šabloni za orijentaciju. **Live kod u repou je izvor istine** — pre izmena uvek pročitaj: `apps/web/lib/upc/*`, `apps/web/app/api/upc/*`, `apps/web/app/home/(user)/billing/_lib/server/upc*.ts`, `apps/web/lib/crypto/token-encryption.ts`. Sledeće stvari su ranije bile pogrešno dokumentovane i sada su ISPRAVLJENE: Delay=0 (bio 1), callback aktivacija SAMO uz dokaz (bio trust TranCode), webhook greške → HTTP 500 (bio reverse), token format base64 (bio hex), TEST status endpoint `service/01` (bio izmišljeni getOrderStatus), fail-closed verifikacija (bio `return true` bez ključa), RPC write kroz admin klijent (bio session klijent).

---

## 1. `apps/web/lib/upc/config.ts` (ključni delovi)

```typescript
import { z } from 'zod';

const upcEnvSchema = z.object({
  UPC_MERCHANT_ID: z.string().min(1),
  UPC_TERMINAL_ID: z.string().min(1),
  UPC_PRIVATE_KEY: z.string().optional(),
  UPC_PRIVATE_KEY_BASE64: z.string().optional(),
  UPC_PUBLIC_KEY: z.string().optional(),
  UPC_IS_PRODUCTION: z.string().transform((v) => v === 'true').default('false'),
  NEXT_PUBLIC_APP_URL: z.string().url(),
});

// fail-fast: bar jedan od UPC_PRIVATE_KEY / UPC_PRIVATE_KEY_BASE64 je OBAVEZAN

export const UPC_ENDPOINTS = {
  TEST: {
    GATEWAY: 'https://ecg.test.upc.ua/rbrs/pay',
    PAY_BY_TOKEN: 'https://ecg.test.upc.ua/rbrs/payByToken',
    STATUS: 'https://ecg.test.upc.ua/rbrs/service/01', // NE getOrderStatus (izmišljen path)
    REVERSAL: 'https://ecg.test.upc.ua/rbrs/reversal',
    REFUND: 'https://ecg.test.upc.ua/rbrs/refund',
    COMPLETE: 'https://ecg.test.upc.ua/rbrs/complete',
  },
  PRODUCTION: {
    GATEWAY: 'https://ecommerce.raiffeisenbank.rs/rbrs/pay',
    PAY_BY_TOKEN: 'https://ecommerce.raiffeisenbank.rs/rbrs/payByToken',
    STATUS: 'https://ecommerce.raiffeisenbank.rs/rbrs/service/01',
    REVERSAL: 'https://ecommerce.raiffeisenbank.rs/rbrs/repayment',
    REFUND: 'https://ecommerce.raiffeisenbank.rs/rbrs/repayment',
    COMPLETE: 'https://ecommerce.raiffeisenbank.rs/rbrs/capture',
  },
} as const;

export const CURRENCY_CODES = { RSD: '941', EUR: '978', USD: '840' } as const;

export const UPC_SUBSCRIPTION_PLANS = {
  monthly: { id: 'monthly', amount: 1870, currencyCode: '941', interval: 'monthly' },
  yearly: { id: 'yearly', amount: 29000, currencyCode: '941', interval: 'yearly' },
} as const;

// OrderID: max 12 karaktera — 8 timestamp + 4 random
export function generateUpcOrderId(_accountId: string): string {
  const timestamp = Date.now().toString().slice(-8);
  const random = Math.floor(Math.random() * 10000).toString().padStart(4, '0');
  return `${timestamp}${random}`;
}

export function formatUpcAmount(amount: number): string {
  return Math.round(amount * 100).toString(); // RSD 290.00 -> "29000"
}
```

---

## 2. `client.ts` — buildPaymentFormData (ključno: Delay=0 + PurchaseTime opcija)

```typescript
export function buildPaymentFormData(
  orderId: string,
  planId: SubscriptionPlanId,
  options?: {
    locale?: 'en' | 'ru' | 'uk'; // 'sr' NIJE podržan
    requestToken?: boolean;
    overrideAmount?: number;  // discount iznos u RSD
    discountDisplay?: string; // npr. "-99%" za PurchaseDesc
    purchaseTime?: string;    // PRE-generisan YYMMDDHHMMSS — caller ga persista na pending red
  },
): UpcPaymentRequest {
  const purchaseTime = options?.purchaseTime ?? formatPurchaseTime();
  const amount = options?.overrideAmount ?? plan.amount;

  // Baza: MerchantID;TerminalID;PurchaseTime;OrderID,Delay;Currency;TotalAmount;SD;
  const signature = generateSignatureNodeJS(
    buildPaymentSignatureData({
      MerchantID: config.UPC_MERCHANT_ID,
      TerminalID: config.UPC_TERMINAL_ID,
      PurchaseTime: purchaseTime,
      OrderID: orderId,
      Delay: '0',          // DIREKTNA naplata (bank traži 0, avgust 2026)
      Currency: plan.currencyCode,
      TotalAmount: formatUpcAmount(amount),
      SD: '',               // uvek prazno u potpisu
    }),
  );

  const formData: UpcPaymentRequest = {
    Version: '1',
    MerchantID: config.UPC_MERCHANT_ID,
    TerminalID: config.UPC_TERMINAL_ID,
    PurchaseTime: purchaseTime,
    OrderID: orderId,
    Delay: '0',            // ISTO i u formi i u potpisu
    Currency: plan.currencyCode,
    TotalAmount: formatUpcAmount(amount),
    SD: '',
    PurchaseDesc: plan.description,
    Signature: signature,
    Locale: options?.locale ?? 'en',
    URL_RETURN: urls.successUrl,
    URL_RETURN_OK: urls.successUrl,
    URL_RETURN_NO: urls.failUrl,
    NOTIFY_URL: urls.notifyUrl,
  };

  if (options?.requestToken !== false) {
    formData.UseToken = '1';
    formData.TokenRecurringModel = 'M';
  }
  return formData;
}
```

---

## 3. `client.ts` — getOrderStatus (JSON/JWS na service/01)

```typescript
export async function getOrderStatus(orderId, amount, currencyCode, purchaseTime?) {
  // Request = JSON {"header","payload","signature"}:
  //   header  = b64({"alg":"RS256"}),
  //   payload = b64({MerchantID, TerminalID, OrderID, Currency, TotalAmount, PurchaseTime}),
  //   signature = RS256 nad "header.payload" (standardni base64)
  const envelope = buildJsonJwsRequest({
    MerchantID: config.UPC_MERCHANT_ID,
    TerminalID: config.UPC_TERMINAL_ID,
    OrderID: orderId,
    Currency: currencyCode,
    TotalAmount: formatUpcAmount(amount),
    PurchaseTime: purchaseTime ?? formatPurchaseTime(),
  });

  const response = await fetch(endpoints.STATUS, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(envelope),
  });

  // Odgovor: isti envelope (gateway potpisuje RS512 — samo dekodiramo payload)
  const responseEnvelope = JSON.parse(await response.text());
  const payload = decodeJsonJwsPayload<{ results?: UpcStatusResult[] }>(responseEnvelope);
  const results = payload.results ?? [];

  // uspeh = tranCode "000" uz operType "PURCHASE" (REFUND redovi se ignorišu)
  const successful = results.find((r) => r.tranCode === '000' && (r.operType ? r.operType === 'PURCHASE' : true));
  return { success: Boolean(successful), response: {...} };
}
```

PurchaseTime MORA biti identičan onome iz payment forme (12-cifreni YYMMDDHHMMSS, TZ servera) — čita se iz `platform_subscriptions.purchase_time` (created_at samo legacy fallback).

---

## 4. Webhook route — greške su HTTP 500, NIKAD reverse

```typescript
export const POST = enhanceRouteHandler(
  async ({ request }) => {
    const rawBody = await request.text(); // raw text: dijagnostika baze potpisa
    const params: Record<string, string> = {};
    new URLSearchParams(rawBody).forEach((v, k) => { params[k] = String(v); });

    const notification = processWebhookNotification(params);
    if (!notification.isValid) {
      return new Response('Signature verification failed', { status: 500 }); // NE reverse
    }
    if (!notification.OrderID || !notification.TranCode) {
      return new Response('Missing required fields', { status: 500 });
    }

    const admin = getSupabaseServerAdminClient<Database>(); // service-role: RLS bypass je nameran
    const { data: sub } = await admin.from('platform_subscriptions').select('*')
      .eq('order_id', notification.OrderID).single();

    if (!sub) return new Response('Subscription lookup failed', { status: 500 });

    const isSuccess = notification.TranCode === '000';

    // Idempotentno: upsert po order_id
    await admin.from('subscription_transactions').upsert({ /* ... */ }, { onConflict: 'order_id' });

    if (isSuccess) {
      // aktivacija + token storage + 4 post-purchase hooka
      // Pad bilo kog upisa POSLE naplate -> return 500 (retry), NIKAD reverse
    } else if (sub.status === 'pending') {
      await admin.from('platform_subscriptions').update({ status: 'failed' }).eq('id', sub.id);
    }

    return new Response(buildUpcResponse(params, 'approve', 'ok'), {
      status: 200,
      headers: { 'Content-Type': 'text/plain; charset=utf-8' },
    });
  },
  { auth: false },
);
```

Token storage pri uspehu (live redosled):
1. `UPCToken && isEncryptionConfigured()` → deaktiviraj sve aktivne tokene za (account_id, provider=upc) → insert novi red u `payment_tokens` (encrypted_token, token_fingerprint, token_exp iz YYMM, masked_pan)
2. `UPCToken` bez enkripcije → legacy fallback: `upc_token`/`upc_token_exp` kolone na pretplati + warn log

---

## 5. Recurring route — fail-closed auth + legacy token fallback + discount

```typescript
export async function POST(request: NextRequest) {
  const cronSecret = process.env.CRON_SECRET;
  if (!cronSecret) {
    // FAIL-CLOSED: bez tajne ruta NE sme da naplaćuje
    return NextResponse.json({ error: 'Server misconfigured' }, { status: 500 });
  }
  if (request.headers.get('authorization') !== `Bearer ${cronSecret}`) {
    return NextResponse.json({ error: 'Unauthorized' }, { status: 401 });
  }

  const admin = getSupabaseServerAdminClient<Database>();
  const { data: subscriptions } = await admin.rpc('get_subscriptions_due_for_renewal');

  for (const sub of subscriptions) {
    // Novi format (payment_tokens) ili legacy upc_token sa reda
    let token: string | null = null;
    if (sub.encrypted_token && isEncryptionConfigured()) {
      token = decryptToken(sub.encrypted_token);
    } else if (sub.upc_token) {
      token = sub.upc_token;
    }
    if (!token) { results.failed++; continue; }

    // Discount: kad remaining padne na 0, naplati originalnu cenu
    let recurringAmount = Number(sub.amount);
    if (sub.discount_code_id && sub.discount_remaining_months === 0 && sub.original_amount) {
      recurringAmount = Number(sub.original_amount);
    }

    const orderId = generateUpcOrderId(sub.account_id);
    const result = await executeMitPayment(orderId, token, recurringAmount, '941');
    // insert subscription_transactions ...

    if (result.success) {
      await admin.rpc('extend_subscription_period', { p_subscription_id: sub.id });
      if (sub.discount_code_id && sub.discount_remaining_months > 0) {
        const newRemaining = sub.discount_remaining_months - 1;
        await admin.from('platform_subscriptions').update({
          discount_remaining_months: newRemaining,
          ...(newRemaining === 0 && sub.original_amount ? { amount: Number(sub.original_amount) } : {}),
        }).eq('id', sub.id);
      }
    } else {
      const PERMANENT = ['101','102','103','104','116','119','121','200','903'];
      if (PERMANENT.includes(result.response.TranCode)) {
        await admin.from('platform_subscriptions').update({ status: 'expired' }).eq('id', sub.id);
        await admin.from('payment_tokens').update({ is_active: false, revoked_at: ..., revocation_reason: ... })
          .eq('subscription_id', sub.id).eq('is_active', true);
      } else {
        await admin.from('platform_subscriptions').update({ status: 'past_due' }).eq('id', sub.id);
      }
    }
  }
  return NextResponse.json(results);
}
```

---

## 6. `lib/crypto/token-encryption.ts` — base64 format (NE hex!)

```typescript
import 'server-only';
import crypto from 'crypto';

const ALGORITHM = 'aes-256-gcm';
const IV_LENGTH = 12;        // 96 bita, random po tokenu
const AUTH_TAG_LENGTH = 16;  // 128 bita

function getEncryptionKey(): Buffer {
  const keyBase64 = process.env.TOKEN_ENCRYPTION_KEY;
  if (!keyBase64) throw new Error('TOKEN_ENCRYPTION_KEY is not set');
  const key = Buffer.from(keyBase64, 'base64'); // base64, NE hex!
  if (key.length !== 32) {
    throw new Error('TOKEN_ENCRYPTION_KEY must be 32 bytes. Generate with: openssl rand -base64 32');
  }
  return key;
}

export function encryptToken(plaintext: string): string {
  const key = getEncryptionKey();
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv(ALGORITHM, key, iv, { authTagLength: AUTH_TAG_LENGTH });
  const ciphertext = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  return JSON.stringify({
    iv: iv.toString('base64'),
    authTag: cipher.getAuthTag().toString('base64'),
    ciphertext: ciphertext.toString('base64'),
  });
}

export function decryptToken(encryptedJson: string): string {
  const { iv, authTag, ciphertext } = JSON.parse(encryptedJson);
  const decipher = crypto.createDecipheriv(ALGORITHM, getEncryptionKey(), Buffer.from(iv, 'base64'), { authTagLength: AUTH_TAG_LENGTH });
  decipher.setAuthTag(Buffer.from(authTag, 'base64'));
  return Buffer.concat([decipher.update(Buffer.from(ciphertext, 'base64')), decipher.final()]).toString('utf8');
}

export function generateTokenFingerprint(token: string): string {
  return crypto.createHash('sha256').update(token, 'utf8').digest('hex');
}
```

---

## 7. Service — RPC write isključivo kroz admin klijent + purchase_time persist

```typescript
class UpcService {
  private adminClient() { return getSupabaseServerAdminClient<Database>(); }

  async createPlatformCheckout(planId = 'yearly', discountCode?) {
    const { data: user } = await requireUser(this.client);
    if (await this.hasActiveSubscription(user.id)) throw new Error('Već imate aktivnu pretplatu');

    const orderId = generateUpcOrderId(user.id);
    const plan = UPC_SUBSCRIPTION_PLANS[planId];
    const purchaseTime = formatPurchaseTime(); // PRE forme — status query traži tačnu vrednost

    // Lockdown: upsert_upc_subscription je service_role only -> admin klijent
    await this.adminClient().rpc('upsert_upc_subscription', {
      p_account_id: user.id, p_order_id: orderId, p_amount: finalAmount,
      p_currency: plan.currency, p_status: 'pending',
      p_plan_id: planId, p_plan_name: plan.name, p_interval: plan.interval,
    });

    // purchase_time / discount / affiliate kolone — RPC ih ne zna, zaseban update
    await this.adminClient().from('platform_subscriptions')
      .update({ purchase_time: purchaseTime }).eq('order_id', orderId);
    // ... discount_code_id, original_amount, discount_remaining_months ...
    // ... affiliate_code iz lv_ref cookie ...

    const formData = buildPaymentFormData(orderId, planId, {
      locale: 'en', requestToken: true, purchaseTime,
      overrideAmount: discountCode ? finalAmount : undefined,
    });
    return { html: buildPaymentRedirectHtml(formData), orderId };
  }

  async cancelSubscription(subscriptionId?, reason?) {
    // korisnici NEMAJU UPDATE pravo na tabelu — ownership-checked RPC (auth.uid() unutra)
    return (await this.client.rpc('cancel_subscription', {
      p_subscription_id: subscription.id, p_reason: reason ?? null,
    })).error ? { success: false } : { success: true };
  }
}
```

---

## 8. Checkout forma — obavezni elementi (live fajlovi)

- Checkbox uslova: „Upoznat/a sam sa opštim uslovima kupovine" (link `/terms-of-service`, target=_blank) — dugme disabled dok nije čekirano
- Logotipi (live putanje): `/images/Logo_Co_brand_RGB_svetla_pozadina_96dpi.svg` (Raiffeisen co-brand), `/images/visa-secure_blu_2021.png`, `/images/mc_idcheck_vrt_rgb_pos.png` — svi u `next/image`
- `trackEvent('checkout_started', { provider: 'upc', plan_id: 'yearly', value, currency: 'RSD' })` pre poziva akcije
- HTML iz akcije → `container.innerHTML = result.html` → `container.querySelector('form')?.submit()` (auto-redirect)

---

## 9. Cron setup (Coolify)

```bash
# Schedule: 0 6 * * *
curl -fsS -X POST https://yourdomain.com/api/upc/recurring \
  -H "Authorization: Bearer ${CRON_SECRET}"
```

---

## 10. Verifikacija da sve radi (test plan)

1. **Signature self-verify** — `debugSignatureGeneration()` vraća `selfVerifyPassed: true`
2. **Test transakcija** — UPC test kartice; prati: webhook stiže (app log), `status=active`, token u `payment_tokens`
3. **MIT (recurring)** — ručno POST `/api/upc/recurring` sa Bearer CRON_SECRET: nov red u `subscription_transactions` + pomeren `current_period_end`
4. **Idempotentnost** — isti webhook 2×: drugi put upsert ne duplira transakciju
5. **Cancel + resume** — `cancel_at_period_end` kroz RPC; resume pre isteka perioda
6. **Status query** — `scripts/check-upc-order-status.ts` nad plaćenim orderom vraća tranCode 000
