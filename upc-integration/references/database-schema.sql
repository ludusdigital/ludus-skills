-- ============================================================
-- UPC Payment Integration — Referentni sažetak SQL šeme
-- ============================================================
--
-- PAŽNJA: ovo je SAŽETAK za nove projekte. U ovom repou izvor istine su
-- live migracije u apps/web/supabase/migrations/:
--   20260126100000_recurring_subscription_support.sql
--   20260201100000_payment_tokens.sql
--   20260324100000_discount_codes.sql
--   20260403200000_fix_upsert_order_id.sql
--   20260801200000_subscription_write_lockdown.sql   (BEZBEDNOSNI LOCKDOWN)
--   20260807120000_upc_purchase_time.sql
--   20260808150000_discount_claim_on_payment.sql
--
-- Razlike ovog sažetka u odnosu na stare verzije skill-a:
--   * enum payment_provider sadrži i raiaccept (postojeći provider)
--   * dodata kolona purchase_time (status query!)
--   * upsert/record RPC-ovi su SAMO service_role (lockdown)
--   * REVOKE UPDATE ON platform_subscriptions od authenticated/anon
-- ============================================================

-- ============================================
-- 1. ENUM tipovi
-- ============================================

DO $$ BEGIN
  CREATE TYPE public.payment_provider AS ENUM ('raiaccept', 'upc');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

DO $$ BEGIN
  CREATE TYPE public.subscription_interval AS ENUM ('monthly', 'yearly', 'one_time');
EXCEPTION
  WHEN duplicate_object THEN null;
END $$;

-- ============================================
-- 2. platform_subscriptions (bitne kolone)
-- ============================================

-- provider, plan_id/plan_name, "interval", order_id (UNIQUE), amount,
-- original_amount, currency, status CHECK (pending/active/paid/past_due/
-- paused/canceled/expired/failed/refunded),
-- upc_token/upc_token_exp (LEGACY token fallback), masked_pan,
-- current_period_start/current_period_end, paid_at, expires_at,
-- cancel_at_period_end, canceled_at, cancellation_reason,
-- discount_code_id, discount_remaining_months,
-- purchase_time TEXT  <-- UPC PurchaseTime iz payment forme (migracija
--                         20260807120000); status query zahteva tačnu vrednost

-- RLS: SELECT own rows (account_id = auth.uid()). NEMA user UPDATE/INSERT/DELETE
--      policy-ja (lockdown) — write ide isključivo kroz service_role klijent
--      ili ownership-checked RPC-ove (cancel_subscription, resume_subscription).

-- ============================================
-- 3. subscription_transactions (audit log)
-- ============================================

-- id, subscription_id (FK, ON DELETE SET NULL), account_id (FK),
-- order_id TEXT NOT NULL + UNIQUE indeks (idempotentnost webhook upsert-a),
-- provider, amount NUMERIC(10,2), currency, tran_code, approval_code, rrn, xid,
-- status CHECK (pending/processing/succeeded/failed/refunded), failure_reason,
-- transaction_type CHECK (initial/recurring/refund/reversal),
-- created_at, processed_at
-- RLS: SELECT own rows only.

-- ============================================
-- 4. payment_tokens (enkriptovani tokeni)
-- ============================================

-- id, account_id (FK), subscription_id (FK, ON DELETE SET NULL),
-- provider, encrypted_token TEXT NOT NULL (AES-256-GCM JSON, base64),
-- token_fingerprint TEXT NOT NULL + UNIQUE indeks (SHA-256 hex plaintext-a),
-- token_exp DATE, masked_pan, card_brand,
-- is_active BOOLEAN DEFAULT TRUE, revoked_at, revocation_reason,
-- created_at, updated_at (+ trigger za updated_at)
-- RLS: SELECT own rows only. Svi write-ovi idu kroz service_role.

-- ============================================
-- 5. RPC funkcije (grantovi su OBAVEZAN deo!)
-- ============================================

-- 5.1 has_active_platform_subscription(user_id UUID DEFAULT auth.uid())
--     SECURITY DEFINER; GRANT EXECUTE TO authenticated
--     status IN (paid, active) AND (expires_at > now() OR current_period_end > now())

-- 5.2 get_current_platform_subscription(user_id UUID DEFAULT auth.uid())
--     SECURITY DEFINER; GRANT EXECUTE TO authenticated
--     najnovija pretplata statusa paid/active/past_due sa neisteklim periodom

-- 5.3 upsert_upc_subscription(...)
--     SECURITY DEFINER; GRANT EXECUTE **SAMO service_role** (lockdown migracija
--     20260801200000 — ranije je bio authenticated i bio je free-subscription
--     exploit!). UPDATE grana ažurira i order_id/amount/plan/interval
--     (fix 20260403200000).

-- 5.4 record_subscription_transaction(...)
--     SECURITY DEFINER; SAMO service_role (lockdown). ON CONFLICT (order_id)
--     DO UPDATE — idempotentno.

-- 5.5 get_subscriptions_due_for_renewal()
--     SAMO service_role. INNER JOIN payment_tokens (is_active, token_exp > danas),
--     status IN (active, paid, past_due), cancel_at_period_end = FALSE,
--     current_period_end <= now() + INTERVAL '1 day'.
--     Vraća i discount_code_id / discount_remaining_months (proširenje
--     20260324100000).

-- 5.6 extend_subscription_period(p_subscription_id)
--     SAMO service_role. current_period_start = stari end; end += interval;
--     expires_at = novi end; status = active.

-- 5.7 cancel_subscription(p_subscription_id, p_reason)
--     GRANT authenticated. SECURITY DEFINER + ownership check:
--     account_id != auth.uid() -> RAISE EXCEPTION. Postavlja cancel_at_period_end.

-- 5.8 resume_subscription(p_subscription_id)
--     GRANT authenticated. Isti ownership check + odbija istekle periode.

-- 5.9 Token RPC-ovi (store_payment_token, get_active_payment_token[_by_account],
--     revoke_payment_token[_by_subscription]) — SAMO service_role.

-- ============================================
-- 6. Lockdown (NE PRESKAČI u novom projektu!)
-- ============================================

REVOKE EXECUTE ON FUNCTION public.upsert_upc_subscription(...) FROM PUBLIC, anon, authenticated;
REVOKE EXECUTE ON FUNCTION public.record_subscription_transaction(...) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.upsert_upc_subscription(...) TO service_role;
GRANT EXECUTE ON FUNCTION public.record_subscription_transaction(...) TO service_role;

-- Korisnici više ne smeju ništa da UPDATE-uju na platform_subscriptions:
DROP POLICY IF EXISTS "Users can update own subscription cancellation" ON public.platform_subscriptions;
REVOKE UPDATE ON public.platform_subscriptions FROM anon, authenticated;
