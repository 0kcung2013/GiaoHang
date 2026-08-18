# Driver Wallet, COD, and VNPAY Finance Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add customer goods pricing and prepaid/COD choice, atomic driver-wallet accounting, VNPAY Sandbox top-up, amount-first driver UI, and an Admin-configurable platform fee while creating only two database tables.

**Architecture:** Reuse `orders` as the per-order financial snapshot and `order_items.price` as goods value. Store every wallet effect and VNPAY request in `driver_wallet_transactions`; derive balances through secured RPCs. Store the current fee in `system_settings`; all balance-changing operations run atomically in PostgreSQL and Flutter remains read-only for ledger data.

**Tech Stack:** Flutter 3.35.1, Dart 3.9.0, Riverpod, Supabase PostgreSQL/RLS/RPC/Edge Functions, VNPAY Sandbox HMAC-SHA512.

## Global Constraints

- Create exactly two new tables: `driver_wallet_transactions` and `system_settings`.
- Never store VNPAY secrets in source, migrations, logs, fixtures, or documentation.
- Use integer VND for all new money fields and basis points for the platform fee.
- New UI must use `AppColors`, `AppTextStyles`, `AppSpacing`, and `AppRadius`.
- Do not add finance logic to the 436-line `create_order_screen.dart`; extract focused models/widgets/controllers.
- Only run focused tests and analyze the touched feature paths.

---

### Task 1: Minimal finance schema and atomic wallet commands

**Files:**
- Create: `supabase/migrations/<generated>_driver_wallet_finance.sql`
- Test: `apps/delivery_app/test/driver_wallet_finance_migration_test.dart`

**Interfaces:**
- Produces: order finance columns, the two approved tables, RLS policies, `get_driver_wallet_summary()`, `get_driver_wallet_transactions()`, `update_platform_fee_rate(integer)`, top-up commands, and finance-aware replacements for existing order lifecycle RPCs.

- [ ] Write a migration contract test that requires exactly the two approved `CREATE TABLE` statements, integer-VND constraints, RLS, grants, fixed `search_path`, idempotency keys, and COD/prepaid settlement branches.
- [ ] Run `flutter test test/driver_wallet_finance_migration_test.dart` and confirm it fails because the migration is missing.
- [ ] Generate the migration name with `supabase migration new driver_wallet_finance`.
- [ ] Implement schema, backfill, policies, indexes, balance RPCs, top-up RPCs, Admin settings RPC, and atomic integration into create/accept/cancel/advance-status commands.
- [ ] Re-run the focused migration test and confirm it passes.

### Task 2: Domain finance model and order command payload

**Files:**
- Create: `apps/delivery_app/lib/core/models/order_finance.dart`
- Modify: `apps/delivery_app/lib/core/models/order_model.dart`
- Modify: `apps/delivery_app/lib/core/services/customer_order_command_service.dart`
- Modify: `apps/delivery_app/lib/core/services/order_assignment_service.dart`
- Test: `apps/delivery_app/test/order_finance_test.dart`
- Test: `apps/delivery_app/test/customer_order_command_service_test.dart`

**Interfaces:**
- Produces: `OrderPaymentMode`, integer money calculations, order JSON parsing, correct `p_item_price`, finance RPC parameters, and an insufficient-wallet error mapping.

- [ ] Write failing tests for 15% fee rounding, COD advance/collection, prepaid zero collection, JSON defaults, and create-order RPC arguments.
- [ ] Run only the two listed tests and confirm the expected failures.
- [ ] Implement the immutable finance value object and extend `OrderModel`/services minimally.
- [ ] Re-run the two tests and confirm they pass.

### Task 3: Customer goods value and payment-mode UI

**Files:**
- Create: `apps/delivery_app/lib/features/customer/screens/create_order/controllers/order_finance_form_controller.dart`
- Create: `apps/delivery_app/lib/features/customer/screens/create_order/widgets/order_payment_section.dart`
- Modify: `apps/delivery_app/lib/features/customer/screens/create_order/widgets/create_order_body.dart`
- Modify: `apps/delivery_app/lib/features/customer/screens/create_order/utils/order_form_data.dart`
- Modify: `apps/delivery_app/lib/features/customer/screens/create_order/create_order_screen.dart`
- Modify: `apps/delivery_app/lib/features/customer/screens/create_order/widgets/order_confirmation_content.dart`
- Modify: `apps/delivery_app/lib/features/customer/screens/create_order/order_confirmation_screen.dart`
- Test: `apps/delivery_app/test/customer_order_finance_form_test.dart`

**Interfaces:**
- Consumes: `OrderPaymentMode` and finance calculation from Task 2.
- Produces: validated goods-value input, prepaid/COD selection, and three-line confirmation summary.

- [ ] Write widget tests for currency input, selected-state semantics, COD/prepaid totals, and compact confirmation copy.
- [ ] Run the focused widget test and confirm it fails.
- [ ] Implement controller/wiring and the token-based amount-first widgets without growing `create_order_screen.dart` beyond its current responsibility.
- [ ] Re-run the focused widget test and confirm it passes.

### Task 4: Driver financial order card and acceptance guard

**Files:**
- Create: `apps/delivery_app/lib/features/driver/screens/home/widgets/driver_order_finance_panel.dart`
- Modify: `apps/delivery_app/lib/features/driver/screens/home/widgets/driver_order_card.dart`
- Modify: `apps/delivery_app/lib/features/driver/screens/home/widgets/driver_order_card_components.dart`
- Test: `apps/delivery_app/test/driver_order_finance_panel_test.dart`
- Test: `apps/delivery_app/test/order_assignment_service_test.dart`

**Interfaces:**
- Consumes: finance fields from `OrderModel` and the server-side balance guard.
- Produces: orange COD/green prepaid panels, prominent advance/collection/net amounts, and `Nạp thêm` error feedback when the server rejects insufficient balance.

- [ ] Write failing widget/service tests for COD, prepaid, and `INSUFFICIENT_WALLET_BALANCE`.
- [ ] Run the two focused tests and confirm expected failures.
- [ ] Implement the finance panel and concise error mapping; keep the database RPC authoritative.
- [ ] Re-run the two tests and confirm they pass.

### Task 5: Driver wallet and earnings screen

**Files:**
- Create: `apps/delivery_app/lib/core/models/driver_wallet.dart`
- Create: `apps/delivery_app/lib/core/services/driver_wallet_service.dart`
- Create: `apps/delivery_app/lib/core/providers/driver_wallet_providers.dart`
- Create: `apps/delivery_app/lib/features/driver/screens/earnings/widgets/wallet_balance_hero.dart`
- Create: `apps/delivery_app/lib/features/driver/screens/earnings/widgets/wallet_transaction_list.dart`
- Create: `apps/delivery_app/lib/features/driver/screens/earnings/widgets/wallet_topup_sheet.dart`
- Modify: `apps/delivery_app/lib/features/driver/screens/earnings/driver_earnings_screen.dart`
- Test: `apps/delivery_app/test/driver_wallet_service_test.dart`
- Test: `apps/delivery_app/test/driver_earnings_screen_test.dart`

**Interfaces:**
- Produces: wallet summary/history loading, quick top-up amounts, VNPAY URL launch, refresh-on-resume, and the approved navy hero/orange CTA layout.

- [ ] Write failing service/widget tests for parsing, top-up validation, hero amounts, empty history, and transaction signs.
- [ ] Run only the listed tests and confirm expected failures.
- [ ] Implement the service/providers and focused widgets.
- [ ] Re-run the two focused tests and confirm they pass.

### Task 6: VNPAY Sandbox Edge Functions

**Files:**
- Create: `supabase/functions/_shared/vnpay.ts`
- Create: `supabase/functions/vnpay-create-wallet-topup/index.ts`
- Create: `supabase/functions/vnpay-wallet-ipn/index.ts`
- Create: `supabase/functions/vnpay-wallet-return/index.ts`
- Modify: `supabase/config.toml`
- Test: `supabase/functions/tests/vnpay_test.ts`

**Interfaces:**
- Consumes: server-only `VNPAY_TMN_CODE`, rotated `VNPAY_HASH_SECRET`, project URL/keys, and top-up RPCs from Task 1.
- Produces: signed payment URLs, checksum verification, idempotent IPN credit, and a Return endpoint that never credits money.

- [ ] Write failing Deno tests for canonical parameter sorting, HMAC verification, amount mismatch, and repeated IPN behavior.
- [ ] Run the single VNPAY test file and confirm expected failures.
- [ ] Implement shared signing and three narrowly scoped functions; configure IPN/Return with gateway JWT verification disabled and internal validation enabled.
- [ ] Re-run the focused Deno test when Deno is available; otherwise record that it was not run.

### Task 7: Admin platform-fee control

**Files:**
- Create: `apps/operations_web/lib/features/admin/screens/settings/admin_finance_settings_card.dart`
- Create: `apps/operations_web/lib/features/admin/services/admin_finance_service.dart`
- Modify: `apps/operations_web/lib/features/admin/screens/settings/admin_settings_screen.dart`
- Test: `apps/operations_web/test/admin_finance_settings_test.dart`

**Interfaces:**
- Consumes: settings RPCs from Task 1.
- Produces: compact 15% settings card with validated update confirmation; no direct table mutation.

- [ ] Write the failing widget/service test for loading, range validation, confirmation, and RPC payload.
- [ ] Run only that test and confirm it fails.
- [ ] Implement the compact settings card and service.
- [ ] Re-run the focused test and confirm it passes.

### Task 8: Focused integration verification

**Files:**
- Modify only files needed to resolve failures in Tasks 1-7.

**Interfaces:**
- Produces: verified Phase A implementation and a precise list of unrun checks.

- [ ] Format only changed Dart files.
- [ ] Run the finance migration contract, finance model/service, create-order finance widget, driver order finance, wallet/earnings, and Admin finance tests in one focused batch.
- [ ] Run `flutter analyze` only on the touched Delivery App and Operations Web files.
- [ ] Apply the approved migration to Supabase, query both new tables/columns/RPC privileges, and run Supabase security/performance advisors.
- [ ] Do not deploy Edge Functions or configure the exposed VNPAY secret until a rotated secret is supplied; report this as the only external configuration step.
