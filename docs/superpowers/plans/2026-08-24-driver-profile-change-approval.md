# Driver Profile Change Approval Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Redesign the driver account as a rating-free, read-only profile and add an Admin-only, auditable approval workflow for every driver profile change.

**Architecture:** A dedicated Supabase request aggregate stores a server-created snapshot and an atomic proposed change set. Driver and Admin clients use narrow repositories over RPC/Storage; direct profile writes are blocked while operational GPS updates remain available. Shared domain types keep Delivery App and Operations Web consistent, and an authenticated Edge Function handles the only cross-system side effects: Auth email and avatar publication.

**Tech Stack:** Dart 3.9.0, Flutter 3.35.1, Riverpod in Delivery App, Supabase PostgreSQL/RLS/RPC/Realtime/Storage/Edge Functions, Deno TypeScript tests.

**Spec:** `docs/superpowers/specs/2026-08-24-driver-profile-change-approval-design.md`

## Global Constraints

- Read `AGENTS.md`, `DESIGN.md`, `docs/design/visual_first_ui.md`, and the spec before implementation.
- Do not apply a migration, deploy an Edge Function, or mutate the connected Supabase project until the user gives separate explicit Supabase approval.
- Role `admin` is the only decision maker; role `support` has no UI, table access, Storage access, or command access for this workflow.
- Every submitted profile change requires Admin approval; approval is whole-request only.
- Keep one `draft`/`pending`/`applying` request per driver.
- Do not expose aggregate driver rating or customer-to-driver review scores to the driver.
- Preserve GPS/location ingestion, availability RPC, driver registration, customer tracking, and initial KYC submission.
- Use `AppColors`, `AppTextStyles`, `AppSpacing`, `AppRadius`, and `AppShadow`; do not use raw `Colors.*` where a token exists.
- Keep one primary CTA, 48dp minimum touch targets, 375dp mobile layout, and text scale 1.6 support.
- Keep production files under 400 lines. Split a file before extending it if the change would push it beyond 400 lines.
- Follow TDD: add one failing behavior test, run it red, write minimum production code, run it green, then refactor.
- Run only focused tests/analyze for touched packages and features. Do not run the full suite or a release build.
- Preserve unrelated dirty-worktree changes and stage only files named by the current task.

## Planned File Structure

### Shared domain

- `packages/giaohang_domain/lib/src/driver_profile_change_request.dart` — statuses, request fields, request model, diff builder.
- `packages/giaohang_domain/lib/giaohang_domain.dart` — exports the profile-change domain API.
- `packages/giaohang_domain/test/driver_profile_change_request_test.dart` — JSON, lifecycle, and diff tests.

### Supabase

- CLI-created migration ending `_driver_profile_change_requests.sql` — request table, lifecycle RPCs, RLS, grants, Realtime publication.
- CLI-created migration ending `_driver_profile_privacy_hardening.sql` — rating column privileges, safe read RPCs, review policy, profile-write protection.
- CLI-created migration ending `_driver_profile_request_storage.sql` — private draft bucket, public approved-avatar bucket, Storage policies.
- `supabase/functions/approve-driver-profile-change-request/approval_flow.ts` — idempotent approval orchestration behind dependency ports.
- `supabase/functions/approve-driver-profile-change-request/approval_flow_test.ts` — happy path and compensation tests.
- `supabase/functions/approve-driver-profile-change-request/index.ts` — JWT/Admin validation and Supabase port adapters.
- `supabase/config.toml` — enables gateway JWT verification for the function.

### Delivery App

- `apps/delivery_app/lib/features/driver/screens/account/data/driver_profile_change_repository.dart` — driver RPC/Realtime/Storage boundary.
- `apps/delivery_app/lib/features/driver/screens/account/providers/driver_profile_change_providers.dart` — Riverpod wiring and invalidation.
- `apps/delivery_app/lib/features/driver/screens/account/models/driver_profile_change_form_state.dart` — draft form state and normalized payload.
- `apps/delivery_app/lib/features/driver/screens/account/dialogs/driver_profile_change_request_sheet.dart` — request stepper/sheet shell.
- `apps/delivery_app/lib/features/driver/screens/account/widgets/driver_profile_change_field_selector.dart` — selectable field rows.
- `apps/delivery_app/lib/features/driver/screens/account/widgets/driver_profile_change_editor.dart` — scalar/file editors.
- `apps/delivery_app/lib/features/driver/screens/account/widgets/driver_profile_change_review.dart` — current-to-requested review.
- `apps/delivery_app/lib/features/driver/screens/account/widgets/driver_profile_change_status_card.dart` — pending/rejected/conflicted state.
- `apps/delivery_app/lib/features/driver/screens/account/widgets/driver_profile_change_action.dart` — one primary request/view CTA.
- Existing account view/model/widgets and `DriverService` — safe self-profile data, no rating, screen wiring.
- Focused tests under `apps/delivery_app/test/driver_profile_change_*_test.dart` and `driver_account_ui_test.dart`.

### Operations Web

- `apps/operations_web/lib/features/admin/screens/drivers/profile_changes/data/admin_driver_profile_change_repository.dart` — Admin queue/decision boundary.
- `apps/operations_web/lib/features/admin/screens/drivers/profile_changes/data/admin_driver_media_resolver.dart` — legacy HTTP URL/private object-path resolution.
- `apps/operations_web/lib/features/admin/screens/drivers/profile_changes/widgets/admin_driver_profile_change_queue.dart` — pending list.
- `apps/operations_web/lib/features/admin/screens/drivers/profile_changes/widgets/admin_driver_profile_change_card.dart` — list item.
- `apps/operations_web/lib/features/admin/screens/drivers/profile_changes/dialogs/admin_driver_profile_change_detail_sheet.dart` — diff, signed media, approve/reject.
- `apps/operations_web/lib/features/admin/screens/drivers/widgets/admin_driver_registry_panel.dart` — extracted existing KYC registry UI.
- `apps/operations_web/lib/features/admin/screens/drivers/admin_drivers_screen.dart` — thin tab/provider wiring.
- `apps/operations_web/test/helpers/driver_profile_change_test_fixtures.dart` — shared Admin widget fixtures and fake repository.
- Focused tests under `apps/operations_web/test/admin_driver_profile_change_*_test.dart`.

---

### Task 1: Shared Profile-Change Domain Model

**Files:**
- Create: `packages/giaohang_domain/lib/src/driver_profile_change_request.dart`
- Modify: `packages/giaohang_domain/lib/giaohang_domain.dart`
- Test: `packages/giaohang_domain/test/driver_profile_change_request_test.dart`

**Interfaces:**
- Consumes: raw JSON rows returned by Supabase.
- Produces: `DriverProfileChangeStatus`, `DriverProfileChangeField`, `DriverProfileChangeRequest`, `DriverProfileFieldDiff`, and `buildDriverProfileDiff(DriverProfileChangeRequest)`.

- [ ] **Step 1: Write the failing domain test**

```dart
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:test/test.dart';

void main() {
  test('parses a pending request and builds only changed field diffs', () {
    final request = DriverProfileChangeRequest.fromJson({
      'id': 'request-1',
      'driver_id': 'driver-1',
      'requested_by': 'user-1',
      'current_snapshot': {
        'phone': '0900000000',
        'vehicle_color': 'Đen',
      },
      'requested_changes': {
        'phone': '0911111111',
        'vehicle_color': 'Đen',
      },
      'reason': 'Đổi số liên hệ',
      'status': 'pending',
      'decision_reason': null,
      'created_at': '2026-08-24T03:00:00Z',
      'updated_at': '2026-08-24T03:00:00Z',
      'decided_at': null,
    });

    expect(request.status, DriverProfileChangeStatus.pending);
    expect(request.isActive, isTrue);
    expect(request.canDriverCancel, isTrue);
    expect(buildDriverProfileDiff(request), [
      const DriverProfileFieldDiff(
        field: DriverProfileChangeField.phone,
        currentValue: '0900000000',
        requestedValue: '0911111111',
      ),
    ]);
  });

  test('maps every database lifecycle value', () {
    expect(
      DriverProfileChangeStatus.values.map((value) => value.databaseValue),
      [
        'draft',
        'pending',
        'applying',
        'approved',
        'rejected',
        'cancelled',
        'conflicted',
      ],
    );
  });
}

```

- [ ] **Step 2: Run the test to verify RED**

Run from `packages/giaohang_domain`:

```powershell
dart test test/driver_profile_change_request_test.dart
```

Expected: compilation fails because the profile-change types are not exported.

- [ ] **Step 3: Implement the minimal domain API**

```dart
enum DriverProfileChangeStatus {
  draft,
  pending,
  applying,
  approved,
  rejected,
  cancelled,
  conflicted;

  String get databaseValue => name;

  static DriverProfileChangeStatus fromDatabase(String value) =>
      DriverProfileChangeStatus.values.firstWhere(
        (status) => status.databaseValue == value,
      );
}

enum DriverProfileChangeField {
  fullName('full_name'),
  email('email'),
  phone('phone'),
  avatar('avatar_path'),
  vehicleType('vehicle_type'),
  vehicleBrandModel('vehicle_brand_model'),
  vehicleColor('vehicle_color'),
  licensePlate('license_plate'),
  idCardNumber('id_card_number'),
  idCardFront('id_card_front_path'),
  idCardBack('id_card_back_path'),
  driverLicenseNumber('driver_license_number'),
  driverLicense('driver_license_path'),
  vehiclePhoto('vehicle_photo_path');

  const DriverProfileChangeField(this.requestKey);
  final String requestKey;

  static DriverProfileChangeField fromRequestKey(String value) =>
      DriverProfileChangeField.values.firstWhere(
        (field) => field.requestKey == value,
      );
}

class DriverProfileFieldDiff {
  const DriverProfileFieldDiff({
    required this.field,
    required this.currentValue,
    required this.requestedValue,
  });

  final DriverProfileChangeField field;
  final Object? currentValue;
  final Object? requestedValue;

  @override
  bool operator ==(Object other) =>
      other is DriverProfileFieldDiff &&
      other.field == field &&
      other.currentValue == currentValue &&
      other.requestedValue == requestedValue;

  @override
  int get hashCode => Object.hash(field, currentValue, requestedValue);
}
```

Implement `DriverProfileChangeRequest.fromJson/toJson`, nullable snapshot/change/reason for drafts, UTC `DateTime` parsing, `isActive`, `canDriverCancel`, and a diff builder that maps file request keys to current snapshot URL keys and removes unchanged scalar values.

- [ ] **Step 4: Export the API and run GREEN**

Add to `giaohang_domain.dart`:

```dart
export 'src/driver_profile_change_request.dart';
```

Run:

```powershell
dart format lib/src/driver_profile_change_request.dart test/driver_profile_change_request_test.dart
dart test test/driver_profile_change_request_test.dart
```

Expected: both tests pass.

- [ ] **Step 5: Commit Task 1**

```powershell
git add packages/giaohang_domain/lib/giaohang_domain.dart packages/giaohang_domain/lib/src/driver_profile_change_request.dart packages/giaohang_domain/test/driver_profile_change_request_test.dart
git commit -m "feat: add driver profile change domain model"
```

### Task 2: Request Aggregate, Lifecycle Commands, and RLS

**Files:**
- Create via `supabase migration new driver_profile_change_requests`: migration ending `_driver_profile_change_requests.sql`
- Test: `apps/delivery_app/test/driver_profile_change_migration_test.dart`

**Interfaces:**
- Consumes: authenticated `auth.uid()`, `public.users.role`, and existing `users`/`drivers` rows.
- Produces: `driver_profile_change_requests`, `create_driver_profile_change_draft()`, `submit_driver_profile_change_request(uuid,jsonb,text)`, `cancel_driver_profile_change_request(uuid)`, `approve_driver_profile_change_request(uuid)`, and `reject_driver_profile_change_request(uuid,text)`.

- [ ] **Step 1: Write the failing migration contract test**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

File profileChangeMigration() {
  final matches = Directory('../../supabase/migrations')
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('_driver_profile_change_requests.sql'))
      .toList();
  expect(matches, hasLength(1));
  return matches.single;
}

void main() {
  test('creates an Admin-only atomic driver profile request lifecycle', () {
    final sql = profileChangeMigration().readAsStringSync();

    expect(sql, contains('CREATE TABLE public.driver_profile_change_requests'));
    expect(sql, contains("DEFAULT 'draft'"));
    expect(sql, contains("status IN ('draft', 'pending', 'applying', 'approved', 'rejected', 'cancelled', 'conflicted')"));
    expect(sql, contains("WHERE status IN ('draft', 'pending', 'applying')"));
    expect(sql, contains('CREATE UNIQUE INDEX driver_profile_change_requests_one_active_idx'));
    expect(sql, contains('ALTER TABLE public.driver_profile_change_requests ENABLE ROW LEVEL SECURITY'));
    expect(sql, contains("actor.role = 'admin'::public.user_role"));
    expect(sql, isNot(contains("'support'::public.user_role")));

    for (final command in [
      'create_driver_profile_change_draft',
      'submit_driver_profile_change_request',
      'cancel_driver_profile_change_request',
      'approve_driver_profile_change_request',
      'reject_driver_profile_change_request',
    ]) {
      expect(sql, contains('FUNCTION public.$command'));
    }

    expect(sql, contains("SECURITY DEFINER\nSET search_path = ''"));
    expect(sql, contains('FOR UPDATE'));
    expect(sql, contains('jsonb_object_keys(p_changes)'));
    expect(sql, contains('REVOKE ALL ON public.driver_profile_change_requests FROM anon, authenticated'));
    expect(sql, contains('GRANT SELECT ON public.driver_profile_change_requests TO authenticated'));
  });
}

```

- [ ] **Step 2: Run the contract test to verify RED**

Run from `apps/delivery_app`:

```powershell
flutter test test/driver_profile_change_migration_test.dart
```

Expected: FAIL because no migration with the required suffix exists.

- [ ] **Step 3: Create the migration through the CLI**

First discover the installed CLI syntax, then create the migration:

```powershell
supabase migration new --help
supabase migration new driver_profile_change_requests
```

Expected: Supabase CLI prints the exact new migration path. Use only that generated file for the remaining steps.

- [ ] **Step 4: Add the table, checks, indexes, grants, and RLS**

The migration must include these concrete invariants:

```sql
CREATE TABLE public.driver_profile_change_requests (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  driver_id uuid NOT NULL REFERENCES public.drivers(id) ON DELETE CASCADE,
  requested_by uuid NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
  current_snapshot jsonb,
  requested_changes jsonb,
  reason text,
  status text NOT NULL DEFAULT 'draft',
  decided_by uuid REFERENCES public.users(id) ON DELETE SET NULL,
  decided_at timestamptz,
  decision_reason text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  CONSTRAINT driver_profile_change_requests_status_check CHECK (
    status IN (
      'draft', 'pending', 'applying', 'approved',
      'rejected', 'cancelled', 'conflicted'
    )
  ),
  CONSTRAINT driver_profile_change_requests_submitted_payload_check CHECK (
    status = 'draft'
    OR (
      jsonb_typeof(current_snapshot) = 'object'
      AND jsonb_typeof(requested_changes) = 'object'
      AND jsonb_object_length(requested_changes) > 0
      AND char_length(trim(reason)) BETWEEN 3 AND 1000
    )
  ),
  CONSTRAINT driver_profile_change_requests_decision_check CHECK (
    (status IN ('approved', 'rejected', 'conflicted') AND decided_at IS NOT NULL)
    OR status IN ('draft', 'pending', 'applying', 'cancelled')
  )
);

CREATE UNIQUE INDEX driver_profile_change_requests_one_active_idx
  ON public.driver_profile_change_requests(driver_id)
  WHERE status IN ('draft', 'pending', 'applying');

CREATE INDEX driver_profile_change_requests_admin_queue_idx
  ON public.driver_profile_change_requests(status, created_at)
  WHERE status IN ('pending', 'applying');

CREATE INDEX driver_profile_change_requests_driver_history_idx
  ON public.driver_profile_change_requests(requested_by, created_at DESC);

ALTER TABLE public.driver_profile_change_requests ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.driver_profile_change_requests FROM anon, authenticated;
GRANT SELECT ON public.driver_profile_change_requests TO authenticated;
```

Create separate SELECT policies: driver owns `requested_by`; Admin role from `public.users` and `status <> 'draft'`. Do not create an INSERT/UPDATE/DELETE client policy because writes go through commands.

- [ ] **Step 5: Implement server-owned draft and submit commands**

Use the exact allowlist below inside `submit_driver_profile_change_request`:

```sql
v_allowed_keys constant text[] := ARRAY[
  'full_name', 'email', 'phone', 'avatar_path',
  'vehicle_type', 'vehicle_brand_model', 'vehicle_color', 'license_plate',
  'id_card_number', 'id_card_front_path', 'id_card_back_path',
  'driver_license_number', 'driver_license_path', 'vehicle_photo_path'
];

IF jsonb_typeof(p_changes) IS DISTINCT FROM 'object'
   OR jsonb_object_length(p_changes) = 0 THEN
  RAISE EXCEPTION 'At least one profile change is required';
END IF;

IF EXISTS (
  SELECT 1
  FROM jsonb_object_keys(p_changes) AS requested(key)
  WHERE NOT (requested.key = ANY (v_allowed_keys))
) THEN
  RAISE EXCEPTION 'Unsupported profile field';
END IF;
```

`create...draft` must return the caller's existing draft or insert one, and must reject callers whose `users.role` is not driver. `submit...` must lock the draft/profile, verify draft ownership, normalize scalar values, verify every file path begins with `<auth.uid()>/<request_id>/`, build the snapshot on the server, reject no-op changes, and transition exactly `draft → pending`.

- [ ] **Step 6: Implement cancel, reject, and atomic approve commands**

Use state guards in every UPDATE:

```sql
SELECT request.* INTO v_request
FROM public.driver_profile_change_requests AS request
WHERE request.id = p_request_id
FOR UPDATE;

IF v_request.status <> 'pending' THEN
  RAISE EXCEPTION 'Request is not pending';
END IF;
```

Cancel deletes an owned draft or changes an owned pending row to `cancelled`. Reject requires Admin and a trimmed 3–1000 character reason. Approve requires Admin, compares only requested fields against the server snapshot, changes to `conflicted` on mismatch, and updates `public.users` plus `public.drivers` before marking `approved` in the same database transaction. The public approval RPC must reject any request containing `email` or `avatar_path`; those fields can be approved only through the internal prepare/finalize commands called by the Edge Function.

For every SECURITY DEFINER command, use the exact overload signatures:

```sql
REVOKE ALL ON FUNCTION public.create_driver_profile_change_draft()
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.submit_driver_profile_change_request(uuid, jsonb, text)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.cancel_driver_profile_change_request(uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.approve_driver_profile_change_request(uuid)
  FROM PUBLIC, anon;
REVOKE ALL ON FUNCTION public.reject_driver_profile_change_request(uuid, text)
  FROM PUBLIC, anon;

GRANT EXECUTE ON FUNCTION public.create_driver_profile_change_draft()
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.submit_driver_profile_change_request(uuid, jsonb, text)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.cancel_driver_profile_change_request(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.approve_driver_profile_change_request(uuid)
  TO authenticated;
GRANT EXECUTE ON FUNCTION public.reject_driver_profile_change_request(uuid, text)
  TO authenticated;
```

Do not grant internal prepare/finalize commands in this migration.

- [ ] **Step 7: Run GREEN and commit Task 2**

```powershell
flutter test test/driver_profile_change_migration_test.dart
```

Expected: PASS.

```powershell
git add apps/delivery_app/test/driver_profile_change_migration_test.dart supabase/migrations/*_driver_profile_change_requests.sql
git commit -m "feat: add driver profile change request lifecycle"
```

### Task 3: Rating Privacy and Direct-Write Hardening

**Files:**
- Create via `supabase migration new driver_profile_privacy_hardening`: migration ending `_driver_profile_privacy_hardening.sql`
- Modify: `apps/delivery_app/lib/core/services/driver_service.dart`
- Modify: `apps/delivery_app/lib/core/location/location_ingest_service.dart`
- Modify: `apps/delivery_app/lib/core/router.dart`
- Modify: `apps/delivery_app/lib/features/auth/screens/driver_approval/driver_approval_screen.dart`
- Modify: `apps/operations_web/lib/features/returns/services/return_route_quote_service.dart`
- Test: `apps/delivery_app/test/driver_profile_privacy_migration_test.dart`

**Interfaces:**
- Consumes: existing `drivers`, `reviews`, `get_public_driver_for_order`, `admin_list_drivers`, GPS and availability flows.
- Produces: `get_my_driver_account_profile()` without rating; authenticated column grants excluding `rating` and `rating_count`; explicit client SELECT lists.

- [ ] **Step 1: Write the failing privacy migration test**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('hides driver rating and protects profile columns', () {
    final files = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('_driver_profile_privacy_hardening.sql'))
        .toList();
    expect(files, hasLength(1));
    final sql = files.single.readAsStringSync();

    expect(sql, contains('REVOKE SELECT ON public.drivers FROM anon, authenticated'));
    final driverGrant = RegExp(
      r'GRANT SELECT\s*\(([\s\S]*?)\)\s*ON public\.drivers',
    ).firstMatch(sql)!.group(1)!;
    expect(driverGrant, isNot(contains('rating')));
    expect(driverGrant, isNot(contains('id_card_number')));
    expect(sql, contains('DROP POLICY IF EXISTS drivers_select_all'));
    expect(sql, contains('REVOKE UPDATE ON public.drivers FROM authenticated'));
    expect(sql, contains('GRANT UPDATE (current_lat, current_lng, location_updated_at, updated_at)'));
    expect(sql, contains('FUNCTION public.get_my_driver_account_profile'));
    expect(sql, contains('FUNCTION public.get_support_return_driver_origin'));
    expect(sql, contains("WHEN v_role = 'driver' THEN NULL"));
    expect(sql, contains("reviews.direction = 'driver_to_customer'"));
  });
}

```

- [ ] **Step 2: Run RED, create the CLI migration, and rerun RED**

```powershell
flutter test test/driver_profile_privacy_migration_test.dart
supabase migration new driver_profile_privacy_hardening
flutter test test/driver_profile_privacy_migration_test.dart
```

Expected: first run fails for missing migration; second run fails for missing SQL contracts.

- [ ] **Step 3: Implement column privileges and safe read RPCs**

Drop the existing `drivers_select_all` policy. Add a driver-own-row SELECT policy and no broad customer/Support policy. Grant authenticated SELECT on only these non-KYC operational columns:

```sql
GRANT SELECT (
  id, user_id, vehicle_type, license_plate, is_available,
  current_lat, current_lng, updated_at, total_deliveries,
  approval_status, vehicle_brand_model, vehicle_color,
  verified_at, submitted_at, location_updated_at
) ON public.drivers TO authenticated;
```

Do not grant `rating`, `rating_count`, KYC/document fields, `rejection_reason`, or avatar/contact data through the table. Revoke table UPDATE and grant only the four GPS columns listed in the test. Keep `set_driver_availability` as the availability write path.

Add `get_my_driver_account_profile()` returning the caller's joined user/driver account fields, including their KYC completion values but no rating. Add `get_support_return_driver_origin(p_risk_report_id uuid)` that requires Support/Admin and resolves current driver coordinates only by joining that authorized risk report to its order; it must not accept an arbitrary driver id. Update `get_public_driver_for_order` so `rating` is returned only when the caller is the order customer or Admin and is null for the assigned driver. Keep `admin_list_drivers` Admin-only.

Replace `reviews_select_driver_own` with a policy that lets a driver read only reviews they authored in direction `driver_to_customer`; keep any customer/admin policies as separate policies.

- [ ] **Step 4: Protect `users` profile columns and role**

Revoke table UPDATE on `users`, grant authenticated UPDATE only on `full_name`, `email`, `phone`, `avatar_url`, and add a trigger that rejects those changes when the row belongs to a caller whose role is driver. SECURITY DEFINER Admin approval bypasses the client restriction only after its own Admin check. Never grant client UPDATE on `role` or `created_at`.

- [ ] **Step 5: Make every client driver SELECT explicit**

Use shared constants in `DriverService`:

```dart
static const driverOperationalSelection =
    'id, user_id, vehicle_type, license_plate, is_available, current_lat, '
    'current_lng, updated_at, total_deliveries, approval_status, '
    'vehicle_brand_model, vehicle_color, submitted_at, location_updated_at';

```

Replace empty `.select()`/`select('*')` calls on `drivers` in all files named by this task. Use `get_my_driver_account_profile` for the account, router, approval screen, and own operational reads. Change `ReturnRouteQuoteService` to call `get_support_return_driver_origin` with `riskReportId`. Keep customer order tracking on `get_public_driver_for_order`.

- [ ] **Step 6: Run focused regression checks and commit Task 3**

```powershell
flutter test test/driver_profile_privacy_migration_test.dart test/driver_account_ui_test.dart
flutter analyze lib/core/services/driver_service.dart lib/core/location/location_ingest_service.dart lib/core/router.dart lib/features/auth/screens/driver_approval/driver_approval_screen.dart
```

Run from `apps/operations_web`:

```powershell
flutter analyze lib/features/returns/services/return_route_quote_service.dart
```

Expected: tests pass and analyze reports no issues.

```powershell
git add supabase/migrations/*_driver_profile_privacy_hardening.sql apps/delivery_app/test/driver_profile_privacy_migration_test.dart apps/delivery_app/lib/core/services/driver_service.dart apps/delivery_app/lib/core/location/location_ingest_service.dart apps/delivery_app/lib/core/router.dart apps/delivery_app/lib/features/auth/screens/driver_approval/driver_approval_screen.dart apps/operations_web/lib/features/returns/services/return_route_quote_service.dart
git commit -m "fix: hide driver rating and protect profile writes"
```

### Task 4: Private Request Storage and Approval Edge Function

**Files:**
- Create via `supabase migration new driver_profile_request_storage`: migration ending `_driver_profile_request_storage.sql`
- Create: `supabase/functions/approve-driver-profile-change-request/approval_flow.ts`
- Create: `supabase/functions/approve-driver-profile-change-request/approval_flow_test.ts`
- Create: `supabase/functions/approve-driver-profile-change-request/index.ts`
- Modify: `supabase/config.toml`
- Test: `apps/delivery_app/test/driver_profile_request_storage_migration_test.dart`

**Interfaces:**
- Consumes: request id, Admin JWT, internal prepare/finalize/rollback RPCs, Supabase Auth Admin API, Storage copy/remove.
- Produces: private request-file Storage, versioned public approved avatars, idempotent Edge approval endpoint.

- [ ] **Step 1: Write the failing Storage migration contract test**

```dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keeps draft files private and Admin-reviewed', () {
    final files = Directory('../../supabase/migrations')
        .listSync()
        .whereType<File>()
        .where((file) => file.path.endsWith('_driver_profile_request_storage.sql'))
        .toList();
    expect(files, hasLength(1));
    final sql = files.single.readAsStringSync();

    expect(sql, contains("'driver-profile-request-files'"));
    expect(sql, contains("'driver-avatars'"));
    expect(sql, contains('public, file_size_limit, allowed_mime_types'));
    expect(sql, contains("bucket_id = 'driver-profile-request-files'"));
    expect(sql, contains("request.status = 'draft'"));
    expect(sql, contains("actor.role = 'admin'::public.user_role"));
    expect(sql, isNot(contains("actor.role = 'support'::public.user_role")));
  });
}
```

- [ ] **Step 2: Run RED and create the migration via CLI**

```powershell
flutter test test/driver_profile_request_storage_migration_test.dart
supabase migration new driver_profile_request_storage
```

Expected: test fails before SQL is implemented.

- [ ] **Step 3: Implement buckets, policies, and internal commands**

Create `driver-profile-request-files` with `public = false`, and `driver-avatars` with `public = true`; both use a 5 MB limit and JPEG/PNG/WebP MIME allowlist. Private object paths must be `<user_id>/<request_id>/<file_type>.<extension>`.

Driver INSERT/UPDATE policies must join `driver_profile_change_requests` by request id parsed from the folder and require own user id plus status `draft`. Driver SELECT is limited to own paths. Driver DELETE is allowed only for own `draft`, `cancelled`, or `rejected` request, never `pending`/`applying`. Admin SELECT requires Admin role and `status <> 'draft'`; Admin DELETE is limited to `rejected`/`cancelled` cleanup. No Support policy is created. Public avatar bucket gets public SELECT only; client roles do not receive write policies.

Add internal prepare/finalize/rollback RPCs. Revoke execute from `PUBLIC`, `anon`, and `authenticated`; grant only `service_role`. Prepare independently verifies that the actor id passed from the already-authenticated Edge Function still has Admin role, locks `pending`, checks snapshot, and moves to `applying`. Finalize updates profile plus decision metadata. Rollback returns a still-valid `applying` request to `pending`, or marks it `conflicted` when Auth email compensation failed.

- [ ] **Step 4: Write the failing pure approval-flow tests**

```typescript
import { assertEquals, assertRejects } from "jsr:@std/assert";
import { executeDriverProfileApproval } from "./approval_flow.ts";

Deno.test("publishes avatar, changes email, then finalizes", async () => {
  const calls: string[] = [];
  const result = await executeDriverProfileApproval("request-1", {
    prepare: async () => ({
      requestId: "request-1",
      userId: "user-1",
      oldEmail: "old@example.com",
      newEmail: "new@example.com",
      avatarDraftPath: "user-1/request-1/avatar.jpg",
    }),
    publishAvatar: async () => {
      calls.push("avatar");
      return {
        url: "https://example.test/driver-avatars/user-1/request-1.jpg",
        objectPath: "user-1/request-1.jpg",
      };
    },
    updateAuthEmail: async () => calls.push("email"),
    restoreAuthEmail: async () => calls.push("restore"),
    finalize: async () => calls.push("finalize"),
    rollback: async () => calls.push("rollback"),
    removePublishedAvatar: async () => calls.push("remove-published"),
    removeAvatarDraft: async () => calls.push("remove-draft"),
  });

  assertEquals(calls, ["avatar", "email", "finalize", "remove-draft"]);
  assertEquals(result.status, "approved");
});

Deno.test("restores email and rolls back when finalize fails", async () => {
  const calls: string[] = [];
  await assertRejects(() =>
    executeDriverProfileApproval("request-2", {
      prepare: async () => ({
        requestId: "request-2",
        userId: "user-2",
        oldEmail: "old@example.com",
        newEmail: "new@example.com",
        avatarDraftPath: "user-2/request-2/avatar.jpg",
      }),
      publishAvatar: async () => {
        calls.push("avatar");
        return {
          url: "https://example.test/driver-avatars/user-2/request-2.jpg",
          objectPath: "user-2/request-2.jpg",
        };
      },
      updateAuthEmail: async () => calls.push("email"),
      restoreAuthEmail: async () => calls.push("restore"),
      finalize: async () => {
        calls.push("finalize");
        throw new Error("db failed");
      },
      rollback: async () => calls.push("rollback"),
      removePublishedAvatar: async () => calls.push("remove-published"),
      removeAvatarDraft: async () => calls.push("remove-draft"),
    })
  );
  assertEquals(calls, [
    "avatar", "email", "finalize", "restore", "remove-published", "rollback",
  ]);
});
```

- [ ] **Step 5: Run Edge tests to verify RED**

```powershell
deno test supabase/functions/approve-driver-profile-change-request/approval_flow_test.ts
```

Expected: FAIL because `approval_flow.ts` does not exist.

- [ ] **Step 6: Implement the orchestration ports and HTTP adapter**

`approval_flow.ts` must export:

```typescript
export type PreparedApproval = {
  requestId: string;
  userId: string;
  oldEmail: string | null;
  newEmail: string | null;
  avatarDraftPath: string | null;
};

export type PublishedAvatar = {
  url: string;
  objectPath: string;
};

export type ApprovalPorts = {
  prepare(requestId: string): Promise<PreparedApproval>;
  publishAvatar(path: string): Promise<PublishedAvatar | null>;
  updateAuthEmail(userId: string, email: string): Promise<void>;
  restoreAuthEmail(userId: string, email: string): Promise<void>;
  finalize(requestId: string, avatarUrl: string | null): Promise<void>;
  rollback(requestId: string, reason: string): Promise<void>;
  removePublishedAvatar(path: string): Promise<void>;
  removeAvatarDraft(path: string): Promise<void>;
};

export async function executeDriverProfileApproval(
  requestId: string,
  ports: ApprovalPorts,
): Promise<{ status: "approved" }>;
```

The implementation calls prepare once, publishes an avatar only when present, updates Auth email only when changed, and finalizes once. Publish to a versioned path `<user_id>/<request_id>.<extension>` so a failed attempt never overwrites the current avatar. After successful finalize, remove only the now-unused avatar draft best-effort; approved KYC/document objects stay private because their paths become the canonical profile values. On any post-prepare failure, attempt email restore, remove the newly published avatar, and call rollback even if an earlier compensation failed. Pass a compensation summary to rollback so it marks `conflicted` rather than `pending` if Auth email could not be restored.

`index.ts` must require POST, validate `Authorization`, call `auth.getUser()`, query `public.users` to require `admin`, validate a UUID request id, create a service-role client only inside the function, adapt the ports, and return JSON without secrets or raw KYC paths.

Add:

```toml
[functions.approve-driver-profile-change-request]
verify_jwt = true
```

- [ ] **Step 7: Run GREEN and commit Task 4**

```powershell
deno test supabase/functions/approve-driver-profile-change-request/approval_flow_test.ts
flutter test test/driver_profile_request_storage_migration_test.dart
```

Expected: all focused tests pass.

```powershell
git add supabase/config.toml supabase/migrations/*_driver_profile_request_storage.sql supabase/functions/approve-driver-profile-change-request apps/delivery_app/test/driver_profile_request_storage_migration_test.dart
git commit -m "feat: add secure driver profile approval storage"
```

### Task 5: Delivery App Repository, Providers, and Safe Account Data

**Files:**
- Create: `apps/delivery_app/lib/features/driver/screens/account/data/driver_profile_change_repository.dart`
- Create: `apps/delivery_app/lib/features/driver/screens/account/providers/driver_profile_change_providers.dart`
- Modify: `apps/delivery_app/lib/features/driver/screens/account/models/driver_account_view_data.dart`
- Modify: `apps/delivery_app/lib/core/services/driver_service.dart`
- Test: `apps/delivery_app/test/driver_profile_change_repository_test.dart`
- Test: `apps/delivery_app/test/driver_account_ui_test.dart`

**Interfaces:**
- Consumes: Task 1 domain model and Task 2/4 RPC/Storage names.
- Produces: `DriverProfileChangeRepository`, `SupabaseDriverProfileChangeRepository`, `currentDriverProfileChangeProvider`, `driverProfileChangeRepositoryProvider`, rating-free `DriverAccountViewData`.

- [ ] **Step 1: Write the failing repository behavior test with an in-memory gateway**

```dart
import 'package:delivery_app/features/driver/screens/account/data/driver_profile_change_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';

void main() {
  test('submit normalizes values and returns the persisted pending request', () async {
    final gateway = FakeDriverProfileChangeGateway();
    final repository = SupabaseDriverProfileChangeRepository(gateway: gateway);

    final request = await repository.submit(
      requestId: 'request-1',
      changes: const {DriverProfileChangeField.phone: ' 0911111111 '},
      reason: ' Đổi số liên hệ ',
    );

    expect(gateway.lastChanges, {'phone': '0911111111'});
    expect(gateway.lastReason, 'Đổi số liên hệ');
    expect(request.status, DriverProfileChangeStatus.pending);
  });
}
```

Add this fake below the test so every referenced test type is concrete:

```dart
class FakeDriverProfileChangeGateway implements DriverProfileChangeGateway {
  Map<String, Object?>? lastChanges;
  String? lastReason;

  @override
  Future<Object?> rpc(
    String function, {
    Map<String, Object?> params = const {},
  }) async {
    lastChanges = Map<String, Object?>.from(params['p_changes']! as Map);
    lastReason = params['p_reason']! as String;
    return {
      'id': 'request-1',
      'driver_id': 'driver-1',
      'requested_by': 'user-1',
      'current_snapshot': {'phone': '0900000000'},
      'requested_changes': lastChanges,
      'reason': lastReason,
      'status': 'pending',
      'decision_reason': null,
      'created_at': '2026-08-24T03:00:00Z',
      'updated_at': '2026-08-24T03:00:00Z',
      'decided_at': null,
    };
  }

  @override
  Future<List<Map<String, dynamic>>> fetchLatestRows() async => const [];

  @override
  Stream<List<Map<String, dynamic>>> watchLatestRows() => const Stream.empty();

  @override
  Future<String> upload({
    required String path,
    required List<int> bytes,
    required String contentType,
  }) async => path;

  @override
  Future<void> remove(List<String> paths) async {}
}
```

- [ ] **Step 2: Run RED**

```powershell
flutter test test/driver_profile_change_repository_test.dart
```

Expected: compilation fails because the repository API does not exist.

- [ ] **Step 3: Implement the repository boundary**

```dart
abstract interface class DriverProfileChangeGateway {
  Future<Object?> rpc(
    String function, {
    Map<String, Object?> params = const {},
  });
  Future<List<Map<String, dynamic>>> fetchLatestRows();
  Stream<List<Map<String, dynamic>>> watchLatestRows();
  Future<String> upload({
    required String path,
    required List<int> bytes,
    required String contentType,
  });
  Future<void> remove(List<String> paths);
}

abstract interface class DriverProfileChangeRepository {
  Future<DriverProfileChangeRequest?> fetchLatest();
  Stream<DriverProfileChangeRequest?> watchLatest();
  Future<DriverProfileChangeRequest> createDraft();
  Future<DriverProfileChangeRequest> submit({
    required String requestId,
    required Map<DriverProfileChangeField, Object?> changes,
    required String reason,
  });
  Future<void> cancel(String requestId);
  Future<String> uploadDraftFile({
    required String requestId,
    required DriverProfileChangeField field,
    required List<int> bytes,
    required String extension,
    required String contentType,
  });
}
```

Keep a small gateway abstraction for RPC, table stream, and Storage calls so normalization is unit-testable without mocking Supabase. The Supabase gateway uses explicit selections, maps PostgREST errors into Vietnamese domain messages, and never requests `drivers.rating`. After a successful draft/pending cancel, delete owned file paths best-effort; cleanup failure is logged without changing the persisted cancellation result.

- [ ] **Step 4: Add Riverpod providers and safe self-profile loading**

Provide repository, latest request, and refresh invalidation. Change account loading to `get_my_driver_account_profile`; do not reuse a broad `driverByUserIdProvider` for this screen.

Remove `rating` from `DriverAccountViewData` constructor, field, factory, and all account fixtures. Preserve `totalDeliveries` and `isAvailable`.

- [ ] **Step 5: Run GREEN and commit Task 5**

```powershell
dart format lib/features/driver/screens/account/data lib/features/driver/screens/account/providers lib/features/driver/screens/account/models test/driver_profile_change_repository_test.dart test/driver_account_ui_test.dart
flutter test test/driver_profile_change_repository_test.dart test/driver_account_ui_test.dart
flutter analyze lib/features/driver/screens/account/data lib/features/driver/screens/account/providers lib/features/driver/screens/account/models lib/core/services/driver_service.dart
```

Expected: focused tests pass and analyze is clean.

```powershell
git add apps/delivery_app/lib/features/driver/screens/account/data apps/delivery_app/lib/features/driver/screens/account/providers apps/delivery_app/lib/features/driver/screens/account/models/driver_account_view_data.dart apps/delivery_app/lib/core/services/driver_service.dart apps/delivery_app/test/driver_profile_change_repository_test.dart apps/delivery_app/test/driver_account_ui_test.dart
git commit -m "feat: add driver profile request data flow"
```

### Task 6: Rating-Free Driver Account and Request UI

**Files:**
- Create: account form/state/dialog/widgets listed in Planned File Structure.
- Modify: `apps/delivery_app/lib/features/driver/screens/account/driver_account_screen.dart`
- Modify: `apps/delivery_app/lib/features/driver/screens/account/widgets/driver_account_profile_hero.dart`
- Modify: `apps/delivery_app/lib/features/driver/screens/account/widgets/driver_account_contact_actions.dart`
- Modify: `apps/delivery_app/lib/features/driver/screens/account/utils/driver_account_strings.dart`
- Test: `apps/delivery_app/test/driver_account_ui_test.dart`
- Test: `apps/delivery_app/test/driver_profile_change_request_sheet_test.dart`

**Interfaces:**
- Consumes: Task 5 repository/providers and rating-free view data.
- Produces: `showDriverProfileChangeRequestSheet`, `DriverProfileChangeStatusCard`, `DriverProfileChangeAction`.

- [ ] **Step 1: Add failing rating/privacy and CTA widget assertions**

```dart
testWidgets('driver account never renders rating and exposes one edit request CTA', (tester) async {
  await tester.pumpWidget(_testApp(
    SingleChildScrollView(
      child: Column(
        children: [
          const DriverAccountProfileHero(data: data),
          DriverProfileChangeAction(
            request: null,
            onCreate: () {},
            onView: (_) {},
          ),
        ],
      ),
    ),
  ));

  expect(find.text('Đánh giá'), findsNothing);
  expect(find.byIcon(Icons.star_rounded), findsNothing);
  expect(find.text('4.9'), findsNothing);
  expect(find.text('Yêu cầu chỉnh sửa hồ sơ'), findsOneWidget);
});
```

Add a second test that pumps a pending request and expects `Xem yêu cầu đang chờ`, no create CTA, and no overflow at 375dp/text scale 1.6.

- [ ] **Step 2: Run RED**

```powershell
flutter test test/driver_account_ui_test.dart
```

Expected: fails because rating still renders and action/status widgets do not exist.

- [ ] **Step 3: Remove rating and implement the read-only account composition**

Delete the rating metric and collapse the hero metrics to deliveries/availability with flexible layout. Keep registration data in the existing personal, vehicle, and verification cards, add lock affordances, mask document numbers, and add the status card plus primary action below the profile cards.

Keep `driver_account_screen.dart` limited to provider wiring, refresh, sheet launch, sign-out, and top-level layout. Move all reusable UI to the new files.

- [ ] **Step 4: Write the failing request-sheet workflow test**

```dart
testWidgets('reviews old and new values before submitting', (tester) async {
  final repository = FakeDriverProfileChangeRepository();
  await tester.pumpWidget(_testApp(
    DriverProfileChangeRequestSheet(
      profile: _profile,
      repository: repository,
    ),
  ));

  await tester.tap(find.text('Số điện thoại'));
  await tester.enterText(find.byKey(const Key('phone-change-input')), '0911111111');
  await tester.enterText(find.byKey(const Key('profile-change-reason')), 'Đổi số liên hệ');
  await tester.tap(find.text('Xem lại'));
  await tester.pumpAndSettle();

  expect(find.text('0900000000'), findsOneWidget);
  expect(find.text('0911111111'), findsOneWidget);
  await tester.tap(find.text('Gửi yêu cầu'));
  await tester.pumpAndSettle();

  expect(repository.submitCount, 1);
  expect(repository.lastReason, 'Đổi số liên hệ');
});

const _profile = DriverAccountViewData(
  driverId: 'driver-1',
  name: 'Nguyễn Minh Tài',
  email: 'tai.xe@example.com',
  phone: '0900000000',
  avatarUrl: null,
  isAvailable: true,
  approvalStatus: 'approved',
  totalDeliveries: 128,
  vehicleType: 'motorbike',
  vehicleBrandModel: 'Honda Air Blade',
  vehicleColor: 'Đen nhám',
  licensePlate: '59-X1 123.45',
  hasIdentityCard: true,
  hasDriverLicense: true,
  hasVehiclePhoto: true,
);

Widget _testApp(Widget child) => MaterialApp(home: Scaffold(body: child));

class FakeDriverProfileChangeRepository
    implements DriverProfileChangeRepository {
  int submitCount = 0;
  String? lastReason;

  @override
  Future<DriverProfileChangeRequest> createDraft() async =>
      _request(status: 'draft', reason: null, changes: const {});

  @override
  Future<DriverProfileChangeRequest?> fetchLatest() async => null;

  @override
  Stream<DriverProfileChangeRequest?> watchLatest() => const Stream.empty();

  @override
  Future<DriverProfileChangeRequest> submit({
    required String requestId,
    required Map<DriverProfileChangeField, Object?> changes,
    required String reason,
  }) async {
    submitCount++;
    lastReason = reason;
    return _request(
      status: 'pending',
      reason: reason,
      changes: {for (final entry in changes.entries) entry.key.requestKey: entry.value},
    );
  }

  @override
  Future<void> cancel(String requestId) async {}

  @override
  Future<String> uploadDraftFile({
    required String requestId,
    required DriverProfileChangeField field,
    required List<int> bytes,
    required String extension,
    required String contentType,
  }) async => 'user-1/$requestId/${field.requestKey}.$extension';

  DriverProfileChangeRequest _request({
    required String status,
    required String? reason,
    required Map<String, Object?> changes,
  }) => DriverProfileChangeRequest.fromJson({
    'id': 'request-1',
    'driver_id': 'driver-1',
    'requested_by': 'user-1',
    'current_snapshot': {'phone': '0900000000'},
    'requested_changes': changes,
    'reason': reason,
    'status': status,
    'created_at': '2026-08-24T03:00:00Z',
    'updated_at': '2026-08-24T03:00:00Z',
  });
}
```

- [ ] **Step 5: Run RED, then implement the three-stage sheet**

```powershell
flutter test test/driver_profile_change_request_sheet_test.dart
```

Expected: compilation fails because the sheet/form types do not exist.

Implement field selection, scalar/file editing, required reason, current-to-requested review, upload progress/retry, no-op validation, submit lock, and error display. Use `image_picker` only from the editor/controller boundary. Do not put signed URLs or service keys in form state.

- [ ] **Step 6: Run GREEN, check sizes, and commit Task 6**

```powershell
dart format lib/features/driver/screens/account test/driver_account_ui_test.dart test/driver_profile_change_request_sheet_test.dart
flutter test test/driver_account_ui_test.dart test/driver_profile_change_request_sheet_test.dart
flutter analyze lib/features/driver/screens/account
```

Check touched production file sizes with PowerShell and split any file over 400 lines before committing.

```powershell
git add apps/delivery_app/lib/features/driver/screens/account apps/delivery_app/test/driver_account_ui_test.dart apps/delivery_app/test/driver_profile_change_request_sheet_test.dart
git commit -m "feat: redesign driver account profile requests"
```

### Task 7: Admin Repository and Decision Routing

**Files:**
- Create: `apps/operations_web/lib/features/admin/screens/drivers/profile_changes/data/admin_driver_profile_change_repository.dart`
- Create: `apps/operations_web/lib/features/admin/screens/drivers/profile_changes/data/admin_driver_media_resolver.dart`
- Test: `apps/operations_web/test/admin_driver_profile_change_repository_test.dart`
- Test: `apps/operations_web/test/admin_driver_media_resolver_test.dart`

**Interfaces:**
- Consumes: Task 1 model, decision RPC, approval Edge Function, signed Storage URLs.
- Produces: `AdminDriverProfileChangeRepository`, `AdminDriverMediaResolver`, `requiresProfileApprovalEdgeFunction`.

- [ ] **Step 1: Write the failing decision-routing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:giaohang_domain/giaohang_domain.dart';
import 'package:operations_web/features/admin/screens/drivers/profile_changes/data/admin_driver_profile_change_repository.dart';

void main() {
  test('routes email and avatar requests through the Edge Function', () {
    expect(
      requiresProfileApprovalEdgeFunction(
        requestFixture({'email': 'new@example.com'}),
      ),
      isTrue,
    );
    expect(
      requiresProfileApprovalEdgeFunction(
        requestFixture({'avatar_path': 'user/request/avatar.jpg'}),
      ),
      isTrue,
    );
    expect(
      requiresProfileApprovalEdgeFunction(
        requestFixture({'vehicle_color': 'Trắng'}),
      ),
      isFalse,
    );
  });
}

DriverProfileChangeRequest requestFixture(Map<String, Object?> changes) {
  return DriverProfileChangeRequest.fromJson({
    'id': 'request-1',
    'driver_id': 'driver-1',
    'requested_by': 'user-1',
    'current_snapshot': {
      for (final key in changes.keys) key: 'current-value',
    },
    'requested_changes': changes,
    'reason': 'Cập nhật hồ sơ',
    'status': 'pending',
    'created_at': '2026-08-24T03:00:00Z',
    'updated_at': '2026-08-24T03:00:00Z',
  });
}
```

- [ ] **Step 2: Run RED**

```powershell
flutter test test/admin_driver_profile_change_repository_test.dart
```

Expected: compilation fails because the Admin repository does not exist.

- [ ] **Step 3: Implement the Admin boundary**

```dart
abstract interface class AdminDriverProfileChangeRepository {
  Future<List<DriverProfileChangeRequest>> fetchPending();
  Stream<void> watchChanges();
  Future<void> approve(DriverProfileChangeRequest request);
  Future<void> reject(String requestId, String reason);
}
```

Use explicit selection strings. `approve` invokes the Edge Function for email/avatar requests and the direct approval RPC otherwise. `reject` trims and validates reason before RPC. `fetchPending` excludes drafts and orders oldest pending first.

Implement media resolution with one stable rule:

```dart
abstract interface class AdminDriverMediaResolver {
  Future<String?> resolve(String? storedValue);
}

abstract interface class AdminDriverMediaGateway {
  Future<String> createSignedUrl(String objectPath, {required int expiresIn});
}

bool isLegacyDriverMediaUrl(String value) {
  final uri = Uri.tryParse(value);
  return uri != null && (uri.scheme == 'http' || uri.scheme == 'https');
}
```

Return legacy HTTP(S) values unchanged. Treat every other non-empty value as an object path in `driver-profile-request-files` and create a five-minute signed URL. After a successful reject, delete request file paths best-effort through the Admin cleanup policy; rejection stays persisted if cleanup fails.

Add this focused test in `admin_driver_media_resolver_test.dart` before implementing the resolver:

```dart
test('keeps legacy URLs and signs private object paths for five minutes', () async {
  final gateway = FakeAdminDriverMediaGateway();
  final resolver = SupabaseAdminDriverMediaResolver(gateway: gateway);

  expect(
    await resolver.resolve('https://legacy.test/driver-kyc/front.jpg'),
    'https://legacy.test/driver-kyc/front.jpg',
  );
  expect(
    await resolver.resolve('user-1/request-1/id_card_front.jpg'),
    'https://signed.test/user-1/request-1/id_card_front.jpg',
  );
  expect(gateway.lastExpiresIn, 300);
});

class FakeAdminDriverMediaGateway implements AdminDriverMediaGateway {
  int? lastExpiresIn;

  @override
  Future<String> createSignedUrl(
    String objectPath, {
    required int expiresIn,
  }) async {
    lastExpiresIn = expiresIn;
    return 'https://signed.test/$objectPath';
  }
}
```

Run both Task 7 tests and verify they fail before creating the repository/resolver files.

- [ ] **Step 4: Run GREEN and commit Task 7**

```powershell
dart format lib/features/admin/screens/drivers/profile_changes/data test/admin_driver_profile_change_repository_test.dart test/admin_driver_media_resolver_test.dart
flutter test test/admin_driver_profile_change_repository_test.dart test/admin_driver_media_resolver_test.dart
flutter analyze lib/features/admin/screens/drivers/profile_changes/data
```

```powershell
git add apps/operations_web/lib/features/admin/screens/drivers/profile_changes/data apps/operations_web/test/admin_driver_profile_change_repository_test.dart apps/operations_web/test/admin_driver_media_resolver_test.dart
git commit -m "feat: add Admin driver profile request repository"
```

### Task 8: Admin Queue, Diff Detail, and Whole-Request Decision UI

**Files:**
- Create: Admin profile-change widgets/dialog listed in Planned File Structure.
- Create: `apps/operations_web/lib/features/admin/screens/drivers/widgets/admin_driver_registry_panel.dart`
- Modify: `apps/operations_web/lib/features/admin/screens/drivers/admin_drivers_screen.dart`
- Modify: `apps/operations_web/lib/features/admin/screens/drivers/widgets/admin_driver_kyc_sheet.dart`
- Create: `apps/operations_web/test/helpers/driver_profile_change_test_fixtures.dart`
- Test: `apps/operations_web/test/admin_driver_profile_change_ui_test.dart`
- Test: `apps/operations_web/test/admin_driver_registry_panel_test.dart`

**Interfaces:**
- Consumes: Task 7 Admin repository.
- Produces: queue tab with count, current-to-requested diff, signed media previews, approve-all/reject-all actions.

- [ ] **Step 1: Write the failing Admin UI test**

```dart
testWidgets('Admin sees a whole-request diff and rejection requires a reason', (tester) async {
  final repository = FakeAdminDriverProfileChangeRepository(
    requests: [pendingRequestFixture()],
  );
  await tester.pumpWidget(testApp(
    AdminDriverProfileChangeQueue(repository: repository),
  ));
  await tester.pumpAndSettle();

  expect(find.text('1 thay đổi'), findsOneWidget);
  await tester.tap(find.text('Nguyễn Minh Tài'));
  await tester.pumpAndSettle();
  expect(find.text('0900000000'), findsOneWidget);
  expect(find.text('0911111111'), findsOneWidget);

  await tester.tap(find.text('Từ chối'));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('confirm-profile-rejection')));
  expect(repository.rejectCount, 0);
  expect(find.text('Vui lòng nhập lý do từ chối'), findsOneWidget);
});
```

Create the imported test helper with concrete fixtures used by both Task 8 tests:

```dart
Widget testApp(Widget child) => MaterialApp(home: Scaffold(body: child));

DriverProfileChangeRequest pendingRequestFixture() =>
    DriverProfileChangeRequest.fromJson({
      'id': 'request-1',
      'driver_id': 'driver-1',
      'requested_by': 'user-1',
      'current_snapshot': {
        'full_name': 'Nguyễn Minh Tài',
        'phone': '0900000000',
      },
      'requested_changes': {'phone': '0911111111'},
      'reason': 'Đổi số liên hệ',
      'status': 'pending',
      'created_at': '2026-08-24T03:00:00Z',
      'updated_at': '2026-08-24T03:00:00Z',
    });

DriverModel approvedDriverFixture() => DriverModel(
  id: 'driver-1',
  userId: 'user-1',
  vehicleType: 'motorbike',
  licensePlate: '59-X1 123.45',
  vehicleBrandModel: 'Honda Air Blade',
  vehicleColor: 'Đen nhám',
  isAvailable: true,
  updatedAt: DateTime.utc(2026, 8, 24),
  totalDeliveries: 128,
  approvalStatus: 'approved',
  fullName: 'Nguyễn Minh Tài',
);

class FakeAdminDriverProfileChangeRepository
    implements AdminDriverProfileChangeRepository {
  FakeAdminDriverProfileChangeRepository({required this.requests});

  final List<DriverProfileChangeRequest> requests;
  int approveCount = 0;
  int rejectCount = 0;

  @override
  Future<List<DriverProfileChangeRequest>> fetchPending() async => requests;

  @override
  Stream<void> watchChanges() => const Stream.empty();

  @override
  Future<void> approve(DriverProfileChangeRequest request) async {
    approveCount++;
  }

  @override
  Future<void> reject(String requestId, String reason) async {
    rejectCount++;
  }
}
```

- [ ] **Step 2: Run RED**

```powershell
flutter test test/admin_driver_profile_change_ui_test.dart
```

Expected: compilation fails because queue/detail widgets do not exist.

- [ ] **Step 3: Characterize and split the existing 328-line driver screen before adding UI**

First add this failing extraction test:

```dart
testWidgets('registry panel renders existing driver approval states', (tester) async {
  await tester.pumpWidget(testApp(
    AdminDriverRegistryPanel(
      drivers: [approvedDriverFixture()],
      loading: false,
      error: null,
      onRetry: () {},
      onOpenDriver: (_) {},
    ),
  ));

  expect(find.text('Nguyễn Minh Tài'), findsOneWidget);
  expect(find.text('Đã duyệt'), findsOneWidget);
  expect(find.text('59-X1 123.45'), findsOneWidget);
});
```

Run `flutter test test/admin_driver_registry_panel_test.dart` and verify compilation fails. Then move the existing pending/approved/rejected registry presentation into `AdminDriverRegistryPanel` with exactly the constructor shown above. Keep fetching/tab state in `AdminDriversScreen`; run the test again and expect PASS.

- [ ] **Step 4: Implement the fourth Admin tab and detail sheet**

Add `Yêu cầu thay đổi` with a pending-count badge. Build cards and details from `buildDriverProfileDiff`; mask sensitive values, fetch signed URLs only when the Admin opens media, require rejection reason, show an approval confirmation summary, and disable both actions during a decision.

Inject `AdminDriverMediaResolver` into the existing KYC sheet and the new request detail. Existing HTTP(S) URLs continue rendering directly; new private object paths are resolved to short-lived signed URLs before `Image.network`. Add a loading/error tile instead of passing a raw object path to `NetworkImage`.

Do not import any file from `features/support/` and do not add profile-change routes to the Support shell.

- [ ] **Step 5: Run GREEN, check layout/file sizes, and commit Task 8**

```powershell
dart format lib/features/admin/screens/drivers test/helpers/driver_profile_change_test_fixtures.dart test/admin_driver_profile_change_ui_test.dart test/admin_driver_registry_panel_test.dart
flutter test test/admin_driver_profile_change_ui_test.dart test/admin_driver_registry_panel_test.dart
flutter analyze lib/features/admin/screens/drivers
```

Run the widget test again at browser-width fixture and verify no touched production file exceeds 400 lines.

```powershell
git add apps/operations_web/lib/features/admin/screens/drivers apps/operations_web/test/helpers/driver_profile_change_test_fixtures.dart apps/operations_web/test/admin_driver_profile_change_ui_test.dart apps/operations_web/test/admin_driver_registry_panel_test.dart
git commit -m "feat: add Admin driver profile approval queue"
```

### Task 9: Realtime Wiring and Focused End-to-End Verification

**Files:**
- Modify: Delivery and Admin repository/provider files from Tasks 5 and 7.
- Modify: migration ending `_driver_profile_change_requests.sql` only if the publication guard was omitted.
- Test: existing focused tests from Tasks 1–8.

**Interfaces:**
- Consumes: RLS-secured request table.
- Produces: driver/Admin refresh after request changes and a verified handoff report.

- [ ] **Step 1: Add failing stream invalidation tests**

In Delivery App, use the fake gateway to emit an approved request and assert the latest-request provider invalidates the account profile provider. In Operations Web, emit a table change and assert the queue fetches again once. Keep these as one behavior per test.

```dart
gateway.emitChange();
await tester.pump();
expect(gateway.fetchCount, 2);
```

- [ ] **Step 2: Run RED, implement minimal subscriptions, and run GREEN**

Use one table stream per screen, skip the initial stream emission when an explicit initial fetch already ran, cancel subscriptions in dispose/provider teardown, and keep pull-to-refresh as fallback.

```powershell
flutter test test/driver_profile_change_repository_test.dart test/driver_account_ui_test.dart test/driver_profile_change_request_sheet_test.dart
```

From `apps/operations_web`:

```powershell
flutter test test/admin_driver_profile_change_repository_test.dart test/admin_driver_profile_change_ui_test.dart
```

Expected: all focused tests pass.

- [ ] **Step 3: Verify migrations in a non-production environment**

Before running any Supabase command, confirm the user has authorized local/development schema work. Discover CLI commands with `--help`. Prefer a local Supabase stack or an explicitly approved development branch; never apply directly to production for this step.

Verify:

```powershell
supabase --version
supabase db --help
supabase migration list --local
```

Use the local-only command exposed by the installed CLI help to rebuild the local database from migrations. Do not run a reset against a remote project. Then use four local authenticated sessions (Driver A, Driver B, Admin, Support) and one anon client to execute this exact matrix:

```text
Driver A: create draft -> PASS
Driver A: select own draft -> PASS
Driver B: select Driver A draft -> 0 rows
Support: select submitted request -> 0 rows
Support: approve/reject RPC -> permission error
Admin: select pending request -> PASS
Admin: approve once -> PASS
Admin: approve same request again -> domain error, no second update
Anon: select/execute -> permission error
Driver A: select drivers.rating/rating_count -> permission error
Driver A: select customer_to_driver review -> 0 rows
Customer assigned to order: get_public_driver_for_order rating -> PASS
Admin: admin_list_drivers rating -> PASS
Support: get_support_return_driver_origin(authorized risk report) -> PASS
Support: get_support_return_driver_origin(arbitrary/nonexistent report) -> 0 rows/error
Driver A: update phone/vehicle/identity directly -> permission error
Driver A: update current_lat/current_lng -> PASS
Driver A: call set_driver_availability -> PASS
New Driver: run registration insert-own -> PASS
```

Capture the SQL/PostgREST result for every row in the matrix in the handoff report.

- [ ] **Step 4: Run fresh focused formatting, tests, and analyze**

```powershell
dart format packages/giaohang_domain/lib packages/giaohang_domain/test
```

From `packages/giaohang_domain`:

```powershell
dart test test/driver_profile_change_request_test.dart
```

From `apps/delivery_app`:

```powershell
flutter test test/driver_profile_change_migration_test.dart test/driver_profile_privacy_migration_test.dart test/driver_profile_request_storage_migration_test.dart test/driver_profile_change_repository_test.dart test/driver_account_ui_test.dart test/driver_profile_change_request_sheet_test.dart
flutter analyze lib/core/services/driver_service.dart lib/core/location/location_ingest_service.dart lib/features/driver/screens/account test/driver_profile_change_repository_test.dart test/driver_account_ui_test.dart test/driver_profile_change_request_sheet_test.dart
```

From `apps/operations_web`:

```powershell
flutter test test/admin_driver_profile_change_repository_test.dart test/admin_driver_media_resolver_test.dart test/admin_driver_profile_change_ui_test.dart test/admin_driver_registry_panel_test.dart
flutter analyze lib/features/admin/screens/drivers lib/features/returns/services/return_route_quote_service.dart test/admin_driver_profile_change_repository_test.dart test/admin_driver_media_resolver_test.dart test/admin_driver_profile_change_ui_test.dart test/admin_driver_registry_panel_test.dart
```

Edge Function:

```powershell
deno test supabase/functions/approve-driver-profile-change-request/approval_flow_test.ts
```

- [ ] **Step 5: Run advisors only after an explicitly approved deployment**

After the user separately approves applying migrations/Edge Function to the connected Supabase project, deploy using the project’s normal migration workflow, run Supabase security and performance advisors, and execute fresh smoke queries. Report advisor findings with remediation links. Do not claim production success from local tests.

- [ ] **Step 6: Audit requirements, file sizes, and working tree**

Confirm:

- no rating text/value/icon in driver account;
- driver API cannot select rating or customer-to-driver score;
- Support has no profile request access;
- one active request and whole-request decision;
- private KYC and signed Admin media;
- GPS, availability, registration, and customer tracking tests remain green;
- every touched production file is under 400 lines or explicitly reported/split;
- only intended files are staged.

- [ ] **Step 7: Commit Task 9**

```powershell
git add packages/giaohang_domain apps/delivery_app/lib/features/driver/screens/account apps/delivery_app/lib/core/services/driver_service.dart apps/delivery_app/lib/core/location/location_ingest_service.dart apps/delivery_app/test/driver_profile_change_repository_test.dart apps/operations_web/lib/features/admin/screens/drivers apps/operations_web/test/admin_driver_profile_change_repository_test.dart apps/operations_web/test/admin_driver_profile_change_ui_test.dart
git commit -m "test: verify driver profile approval workflow"
```

Do not stage unrelated files. If Task 9 produced no source/test diff after earlier commits, skip the empty commit and report that verification alone changed no files.
