# Phase 1 Cleanup Plan

This document tracks safe cleanup work for the current DATN GiaoHang Flutter project.

## Architecture Decision

- Keep one Flutter app for all three roles: customer, driver, admin.
- Do not split the repository into `customer_app/`, `driver_app/`, `admin_web/`, or `shared/`.
- Keep the current runtime behavior intact during Phase 1.
- Do not modify Supabase schema, RLS, migrations, Edge Functions, or database fields without explicit approval.

## Phase 1 Scope

- Align documentation with the current single-app architecture.
- List unused or empty folders and likely unused widget files.
- Document design token consolidation direction.
- Document Supabase schema compatibility checks.
- Note that Supabase URL and anon key should later move to `.env`, without changing runtime config now.

## Design Token Direction

Preferred design tokens:

- `AppColors`
- `AppTextStyles`
- `AppSpacing`
- `AppRadius`

Source file:

- `lib/core/constants/app_theme.dart`

Current compatibility tokens that must not be deleted yet:

- `NavColors` in `lib/core/constants/colors.dart`
- `OrderColors`, `OrderSpacing`, `OrderShadow` in `lib/features/customer/screens/order/widgets/order_theme.dart`

Phase 1 does not migrate UI. Phase 2 should migrate screen by screen and verify visuals after each group.

## Empty Folders To Review Later

Do not delete these in Phase 1. They are only marked for review:

- `lib/features/admin/screens/home/widgets/`
- `lib/features/auth/screens/login/widgets/`
- `lib/features/customer/screens/account/widgets/`
- `lib/features/customer/screens/dashboard/widgets/`
- `lib/features/customer/screens/home/widgets/`
- `lib/features/customer/screens/tracking/widgets/`
- `lib/features/driver/screens/home/widgets/`
- `lib/features/onboarding/screens/onboarding/widgets/`

## Likely Unused Widget Files To Review Later

Do not delete these in Phase 1. They appear not to be referenced by the current `OrderScreen`, based on source search:

- `lib/features/customer/screens/order/widgets/order_card.dart`
- `lib/features/customer/screens/order/widgets/order_filter_row.dart`
- `lib/features/customer/screens/order/widgets/order_summary_card.dart`
- `lib/features/customer/screens/order/widgets/order_vm.dart`
- `lib/features/customer/screens/order/widgets/section_title.dart`
- `lib/features/customer/screens/order/widgets/order_theme.dart`

Review before removal because these may be intended for the next order-screen refactor.

## Supabase Schema Compatibility Checklist

Base tables documented in project rules:

- `users`
- `drivers`
- `orders`
- `order_items`
- `routes`
- `locations`

Tables currently referenced by code and requiring verification before feature work:

- `saved_addresses`
- `notifications`
- `reviews`
- `order_status_logs`

Fields currently referenced by models/services and requiring verification before writes:

- `orders.tracking_code`
- `orders.estimated_pickup_at`
- `orders.estimated_delivery_at`
- `orders.actual_picked_up_at`
- `orders.actual_delivered_at`
- `orders.cancelled_at`
- `orders.recipient_name`
- `orders.recipient_phone`
- `orders.delivery_fee`
- `orders.service_type`
- `orders.payment_method`
- `orders.status_note`
- `orders.updated_at`
- `users.preferred_payment_method`
- `users.notification_order_updates`
- `users.notification_promotions`
- `drivers.rating`
- `drivers.total_deliveries`

Rule for later phases:

- Do not invent or write new fields until the live Supabase schema is confirmed.
- Do not change Supabase schema from code cleanup work.
- If a field is absent, decide whether to remove usage, guard it, or request a schema change separately.

## Runtime Config Note

Current runtime config reads Supabase URL and anon key from:

- `lib/core/constants/supabase_constants.dart`

Future cleanup should move these values to `.env` or another approved environment configuration approach. Phase 1 intentionally does not change this file or runtime initialization.

## Phase 2 Candidate

Start with a low-risk UI consistency pass:

- Pick one customer screen.
- Replace local hardcoded styles with `AppColors`, `AppTextStyles`, `AppSpacing`, and `AppRadius`.
- Extract only one or two repeated widgets.
- Do not connect new database behavior during the same pass.
