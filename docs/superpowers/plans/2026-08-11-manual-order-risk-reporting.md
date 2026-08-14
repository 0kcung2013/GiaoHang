# Manual Order Risk Reporting Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Let an order customer or assigned driver submit a structured incident report with optional photo, GPS, and message evidence, then let Support triage the order within ten minutes without blocking the driver for the full investigation.

**Architecture:** Shared risk types live in `giaohang_domain`; Delivery App owns a reusable three-step report sheet and a narrow Supabase repository; Operations Web extends its existing risk queue. Additive participant, enum, and intervention migrations provide secure evidence and atomic operations, including the pre-pickup `risk_hold` state.

**Tech Stack:** Dart 3.9.0, Flutter 3.35.1, Riverpod, Supabase PostgreSQL/RLS/RPC/Storage/Cron, `image_picker`, `geolocator`, `flutter_test`.

## Global Constraints

- Work in the existing monorepo and current `main`; preserve unrelated uncommitted route-map changes.
- Do not duplicate shared risk enums/models between the two Flutter apps.
- Use `AppColors`, `AppTextStyles`, `AppSpacing`, and `AppRadius`; no raw component colors or Material-default dialogs.
- Use `flutter_map`, not `google_maps_flutter`.
- Customer/Driver never choose or spoof severity; participant-created reports use internal `medium`.
- A report is not a violation decision; accepting it must not automatically pause the order.
- File names are `snake_case.dart`, classes are `PascalCase`, and touched files should stay below 400 lines.
- Apply every database change through additive migrations with RLS enabled and explicit grants/revokes.
- Run each task red-green-refactor and commit only that task's files.

---

### Task 1: Shared risk-report domain types

**Files:**
- Create: `packages/giaohang_domain/lib/src/risk_report.dart`
- Modify: `packages/giaohang_domain/lib/giaohang_domain.dart`
- Create: `apps/delivery_app/test/risk_report_domain_test.dart`
- Modify: `apps/operations_web/lib/features/risk_reports/models/risk_report.dart`
- Modify: `apps/operations_web/lib/features/risk_reports/models/risk_report_policy.dart`

**Interfaces:**
- Produces: `RiskCategory`, `RiskStatus`, `RiskSeverity`, `RiskReporterRole`, `RiskInterventionState`, `RiskReport`, `RiskReportEvent`, `RiskReportAttachment`, `RiskReportSubmission`, and `RiskReportSubmissionResult` from `package:giaohang_domain/giaohang_domain.dart`.
- Consumes: existing Operations Web JSON shapes and database values.

- [ ] **Step 1: Write the failing shared-domain test**

```dart
test('participant submission never exposes a severity input', () {
  const submission = RiskReportSubmission(
    reportId: 'report-1',
    orderId: 'order-1',
    category: RiskCategory.cargoIssue,
    description: 'Kiện hàng bị rách trước khi giao.',
    photoPaths: [],
    messageIds: [],
  );
  expect(submission.toRpcJson(), isNot(contains('severity')));
  expect(RiskReporterRole.fromDatabase('driver'), RiskReporterRole.driver);
  expect(
    RiskInterventionState.fromDatabase('awaiting_triage'),
    RiskInterventionState.awaitingTriage,
  );
});
```

- [ ] **Step 2: Run the test and verify RED**

Run: `cd apps/delivery_app && flutter test test/risk_report_domain_test.dart`

Expected: compilation failure because the shared risk types do not exist.

- [ ] **Step 3: Implement immutable shared types and JSON parsing**

Define stable database mappings, including:

```dart
enum RiskCategory {
  deliveryDelay('delivery_delay'),
  suspiciousAddress('suspicious_address'),
  contactIssue('contact_issue'),
  cargoIssue('cargo_issue'),
  payment('payment'),
  safety('safety'),
  repeatedCancellation('repeated_cancellation'),
  system('system'),
  other('other');

  const RiskCategory(this.databaseValue);
  final String databaseValue;
}

enum RiskInterventionState {
  awaitingTriage('awaiting_triage'),
  heldBeforePickup('held_before_pickup'),
  continueDelivery('continue_delivery'),
  returnRequired('return_required'),
  handoffRequired('handoff_required'),
  released('released');
}
```

Move existing Operations Web enums/report DTOs to the package and update its
policy imports instead of retaining duplicate declarations.

- [ ] **Step 4: Run focused tests and both analyzers**

Run:

```powershell
cd apps/delivery_app
flutter test test/risk_report_domain_test.dart
flutter analyze
cd ../operations_web
flutter test test/risk_report_policy_test.dart
flutter analyze
```

Expected: all pass, with no duplicate enum declaration.

- [ ] **Step 5: Commit**

```powershell
git add packages/giaohang_domain apps/delivery_app/test/risk_report_domain_test.dart apps/operations_web/lib/features/risk_reports/models
git commit -m "refactor: share risk report domain types"
```

### Task 2: Participant report creation and immutable evidence migration

**Files:**
- Create: `supabase/migrations/202608110001_manual_order_risk_reporting.sql`
- Create: `apps/delivery_app/test/manual_risk_reporting_migration_test.dart`

**Interfaces:**
- Produces RPC `public.create_participant_risk_report(p_report_id uuid, p_order_id uuid, p_category text, p_description text, p_photo_paths text[], p_latitude double precision, p_longitude double precision, p_location_captured_at timestamptz, p_message_ids uuid[]) RETURNS TABLE(report_id uuid, status text)`.
- Produces private Storage bucket `risk-report-evidence` and immutable `public.risk_report_attachments`.
- Consumes existing `risk_reports`, `risk_report_events`, `order_messages`, and `risk_report_message_evidence`.

- [ ] **Step 1: Write migration contract tests**

Assert the SQL contains the new categories, reporter-role snapshot, attachment
table with RLS, private bucket, strict path checks, participation checks for
customer/assigned driver, evidence/order matching, `SECURITY DEFINER`, empty
`search_path`, and `REVOKE ... FROM PUBLIC, anon`.

```dart
expect(sql, contains('FUNCTION public.create_participant_risk_report'));
expect(sql, contains("actor.role IN ('customer', 'driver')"));
expect(sql, contains('CREATE TABLE public.risk_report_attachments'));
expect(sql, contains("bucket_id = 'risk-report-evidence'"));
expect(sql, isNot(contains('GRANT INSERT ON public.risk_reports')));
```

- [ ] **Step 2: Run the migration test and verify RED**

Run: `cd apps/delivery_app && flutter test test/manual_risk_reporting_migration_test.dart`

Expected: failure because the migration file is absent.

- [ ] **Step 3: Write the additive migration**

Implement the RPC so it derives `auth.uid()` and role, locks the order, verifies
ownership/assignment, inserts `medium` severity and `open` status, snapshots only
same-order messages, registers only paths prefixed by
`<uid>/<report_id>/`, and returns the created row. Update
`private.validate_risk_report_write()` to permit this trusted participant insert
without granting participant table-management capabilities.

Create immutable attachment policies: reporter can select attachments for their
own report; Support/Admin can select all; no authenticated update/delete grants.
Add participant `SELECT` policies for their own `risk_reports` and corresponding
audit/evidence rows so status updates can be observed without exposing internal
reports from other orders.

- [ ] **Step 4: Run migration contract and existing evidence tests**

Run:

```powershell
cd apps/delivery_app
flutter test test/manual_risk_reporting_migration_test.dart
cd ../operations_web
flutter test test/risk_message_evidence_model_test.dart test/risk_report_detail_evidence_test.dart
```

Expected: all pass.

- [ ] **Step 5: Commit**

```powershell
git add supabase/migrations/202608110001_manual_order_risk_reporting.sql apps/delivery_app/test/manual_risk_reporting_migration_test.dart
git commit -m "feat: secure participant risk report creation"
```

### Task 3: Atomic operational triage and driver release migration

**Files:**
- Create: `supabase/migrations/202608110002_add_risk_hold_status.sql`
- Create: `supabase/migrations/202608110003_risk_report_interventions.sql`
- Create: `apps/delivery_app/test/risk_intervention_migration_test.dart`
- Modify: migration definitions of assignment functions only by replacing them in the new migration; do not edit historical migrations.

**Interfaces:**
- Produces `risk_hold` order enum value in its own committed migration, then `public.risk_report_interventions` in the following migration.
- Produces RPCs `accept_risk_report`, `hold_risk_order_before_pickup`, `decide_risk_delivery_operation`, `confirm_risk_custody_resolved`, and `resume_risk_held_order`.
- Produces immutable staff-only `risk_report_notes` and `add_risk_report_note`.
- Produces private idempotent `escalate_overdue_risk_triage()` scheduled once per minute.

- [ ] **Step 1: Write failing lifecycle contract tests**

Cover these exact invariants:

```dart
expect(sql, contains("ADD VALUE IF NOT EXISTS 'risk_hold'"));
expect(sql, contains('FUNCTION public.hold_risk_order_before_pickup'));
expect(sql, contains("v_order.status = 'assigned'"));
expect(sql, contains('driver_id = NULL'));
expect(sql, contains("state = 'return_required'"));
expect(sql, contains('FUNCTION private.escalate_overdue_risk_triage'));
```

Also assert assignment discovery excludes the explicit `risk_hold` state,
participants can select only their order's intervention, and internal Support
notes remain staff-only. An `awaiting_triage` intervention alone must not block
assignment because accepting a report is separate from holding an order.

- [ ] **Step 2: Run the test and verify RED**

Run: `cd apps/delivery_app && flutter test test/risk_intervention_migration_test.dart`

Expected: failure because the intervention migration is absent.

- [ ] **Step 3: Implement state-locked RPCs**

Add `risk_hold` in `202608110002_add_risk_hold_status.sql` without using the new
enum value in that same migration transaction. In the next migration, each
command must lock the report, intervention, and order with `FOR UPDATE`,
authorize Support/Admin, validate current state, update order/intervention/event
in one transaction, and reject stale transitions. Pre-pickup hold accepts only
`assigned`; cargo states accept `continue_delivery`, `return_required`, or
`handoff_required`; release accepts only resolved custody.

Keep current driver assignment/accept functions unchanged: they already select
only `pending`/`confirmed`, so the new `risk_hold` value is excluded. Do not
filter on every unreleased intervention because that would pause an order merely
for being reported. Do not mutate `drivers.is_available`; availability remains
intent while active-order state determines busy.

- [ ] **Step 4: Run migration and assignment regression tests**

Run:

```powershell
cd apps/delivery_app
flutter test test/risk_intervention_migration_test.dart test/driver_assignment_hardening_migration_test.dart test/order_cancellation_lifecycle_migration_test.dart
```

Expected: all pass.

Also run `supabase db reset`, `supabase db lint`, and `supabase db advisors`
against the linked local project. Review and fix every security or performance
finding caused by these migrations before committing.

- [ ] **Step 5: Commit**

```powershell
git add supabase/migrations/202608110002_add_risk_hold_status.sql supabase/migrations/202608110003_risk_report_interventions.sql apps/delivery_app/test/risk_intervention_migration_test.dart
git commit -m "feat: add atomic risk intervention workflow"
```

### Task 4: Delivery App repository and wizard controller

**Files:**
- Create: `apps/delivery_app/lib/features/risk_reports/data/risk_report_repository.dart`
- Create: `apps/delivery_app/lib/features/risk_reports/controllers/risk_report_form_controller.dart`
- Create: `apps/delivery_app/lib/features/risk_reports/utils/risk_report_options.dart`
- Modify: `apps/delivery_app/pubspec.yaml`
- Create: `apps/delivery_app/test/risk_report_form_controller_test.dart`
- Create: `apps/delivery_app/test/risk_report_repository_test.dart`

**Interfaces:**
- Produces app-local `ParticipantRiskReportDraft`/`RiskPhotoInput` and `abstract interface class ParticipantRiskReportRepository` with `Future<RiskReportSubmissionResult> submit(ParticipantRiskReportDraft draft)`.
- Produces `RiskReportFormController`, `RiskReportFormState`, and role-aware `riskOptionsFor(RiskReporterRole role)`.
- Consumes shared domain types, Supabase Storage/RPC, `image_picker`, and optional geolocation supplied by the UI.

- [ ] **Step 1: Write failing controller tests**

Test role-aware options, required category, 10-character description, maximum
five photos, back/next state preservation, duplicate-submit suppression, and
retry after upload failure.

```dart
final controller = RiskReportFormController(repository: fakeRepository);
controller.selectCategory(RiskCategory.safety);
controller.setDescription('Khu vực giao hàng không an toàn.');
await Future.wait([controller.submit(), controller.submit()]);
expect(fakeRepository.submitCalls, 1);
```

- [ ] **Step 2: Run tests and verify RED**

Run: `cd apps/delivery_app && flutter test test/risk_report_form_controller_test.dart test/risk_report_repository_test.dart`

Expected: compilation failure for missing classes.

- [ ] **Step 3: Implement controller and repository**

Generate report/file UUIDs client-side. Upload compressed photos to
`risk-report-evidence/<uid>/<reportId>/...`, then call
`create_participant_risk_report`. On RPC failure, best-effort remove only paths
uploaded by this attempt. Map duplicate `23505`, authorization `42501`, network,
and validation errors to Vietnamese repository exceptions without discarding
form state. Declare the `image` package directly and convert camera/gallery input
to bounded JPEG bytes before upload; do not depend on a transitive package.

- [ ] **Step 4: Run focused tests and analyze**

Run: `cd apps/delivery_app && flutter test test/risk_report_form_controller_test.dart test/risk_report_repository_test.dart && flutter analyze`

Expected: pass and no analyzer issues.

- [ ] **Step 5: Commit**

```powershell
git add apps/delivery_app/lib/features/risk_reports apps/delivery_app/test/risk_report_form_controller_test.dart apps/delivery_app/test/risk_report_repository_test.dart
git commit -m "feat: add participant risk report submission"
```

### Task 5: Premium three-step report bottom sheet

**Files:**
- Create: `apps/delivery_app/lib/features/risk_reports/widgets/risk_report_sheet.dart`
- Create: `apps/delivery_app/lib/features/risk_reports/widgets/risk_reason_step.dart`
- Create: `apps/delivery_app/lib/features/risk_reports/widgets/risk_evidence_step.dart`
- Create: `apps/delivery_app/lib/features/risk_reports/widgets/risk_review_step.dart`
- Create: `apps/delivery_app/lib/features/risk_reports/widgets/risk_report_entry_action.dart`
- Create: `apps/delivery_app/test/risk_report_sheet_test.dart`

**Interfaces:**
- Produces `Future<RiskReportSubmissionResult?> showRiskReportSheet(BuildContext context, {required OrderModel order, required RiskReporterRole role, ParticipantRiskReportRepository? repository})`.
- Produces reusable `RiskReportEntryAction` with a 48 dp touch target.
- Consumes Task 4 controller/repository and existing order-chat message reads.

- [ ] **Step 1: Write failing widget tests**

Verify three steps, role-specific reasons, inline validation, Back preserving
values, photo/location/message evidence summaries, single submit, success
reference, 375x667 layout, and text scale 1.6 without overflow.

```dart
expect(find.text('Báo cáo sự cố'), findsOneWidget);
await tester.tap(find.text('Vấn đề an toàn'));
await tester.tap(find.text('Tiếp tục'));
expect(find.text('Thêm thông tin'), findsOneWidget);
```

- [ ] **Step 2: Run the widget test and verify RED**

Run: `cd apps/delivery_app && flutter test test/risk_report_sheet_test.dart`

Expected: compilation failure because the sheet does not exist.

- [ ] **Step 3: Implement focused widgets**

Use a custom `showModalBottomSheet` with `isScrollControlled: true`, `SafeArea`,
keyboard insets, a token-based surface, rounded reason tiles, visible labels,
non-color-only selection, and one filled action per step. Use existing image and
location permission patterns; location remains optional.

- [ ] **Step 4: Run widget tests and format**

Run: `cd apps/delivery_app && dart format lib/features/risk_reports test/risk_report_sheet_test.dart && flutter test test/risk_report_sheet_test.dart`

Expected: all pass.

- [ ] **Step 5: Commit**

```powershell
git add apps/delivery_app/lib/features/risk_reports/widgets apps/delivery_app/test/risk_report_sheet_test.dart
git commit -m "feat: build order incident report wizard"
```

### Task 6: Customer and Driver report entry points

**Files:**
- Modify: `apps/delivery_app/lib/features/customer/screens/order/dialogs/order_detail_sheet.dart`
- Create: `apps/delivery_app/lib/features/customer/screens/order/dialogs/widgets/order_risk_report_section.dart`
- Modify: `apps/delivery_app/lib/features/customer/screens/tracking/tracking_widgets.dart`
- Modify: `apps/delivery_app/lib/features/driver/screens/navigation/widgets/driver_navigation_view.dart`
- Modify: `apps/delivery_app/lib/features/driver/screens/home/widgets/driver_order_card.dart`
- Create: `apps/delivery_app/lib/features/driver/screens/navigation/widgets/driver_risk_action.dart`
- Create: `apps/delivery_app/test/risk_report_entry_points_test.dart`

**Interfaces:**
- Consumes `RiskReportEntryAction` and `showRiskReportSheet` from Task 5.
- Produces customer detail/tracking and driver order/navigation entry points.

- [ ] **Step 1: Write failing placement tests**

Assert customer detail and tracking show the labeled secondary action, driver
navigation keeps it separate from delivery progression controls, and unrelated
users cannot construct an actionable entry point.

- [ ] **Step 2: Run and verify RED**

Run: `cd apps/delivery_app && flutter test test/risk_report_entry_points_test.dart`

Expected: action finders return zero.

- [ ] **Step 3: Add thin entry integrations**

Keep `order_detail_sheet.dart` below 400 lines by rendering the new section from
its own widget file. Put driver reporting in the secondary actions/support area,
never beside the primary pickup/delivery confirmation button. Pass the exact
order and reporter role into the shared sheet.

- [ ] **Step 4: Run UI regression tests**

Run:

```powershell
cd apps/delivery_app
flutter test test/risk_report_entry_points_test.dart test/customer_order_detail_sheet_test.dart test/driver_navigation_route_logic_test.dart
flutter analyze
```

Expected: all pass; no touched file exceeds 400 lines.

- [ ] **Step 5: Commit**

```powershell
git add apps/delivery_app/lib/features/customer apps/delivery_app/lib/features/driver apps/delivery_app/test/risk_report_entry_points_test.dart
git commit -m "feat: expose order incident reporting by role"
```

### Task 7: Operations Web reporter and evidence presentation

**Files:**
- Modify: `apps/operations_web/lib/features/risk_reports/data/risk_report_repository.dart`
- Modify: `apps/operations_web/lib/features/risk_reports/widgets/risk_report_card.dart`
- Modify: `apps/operations_web/lib/features/risk_reports/widgets/risk_report_detail_content.dart`
- Create: `apps/operations_web/lib/features/risk_reports/widgets/risk_attachment_section.dart`
- Modify: `apps/operations_web/lib/features/risk_reports/constants/risk_report_strings.dart`
- Modify: `apps/operations_web/pubspec.yaml`
- Modify: `apps/operations_web/test/risk_reports_view_test.dart`
- Modify: `apps/operations_web/test/risk_report_detail_evidence_test.dart`

**Interfaces:**
- Extends repository with `fetchAttachments(reportId)` and reporter join data.
- Consumes shared Task 1 models and Task 2 tables.
- Produces reporter-role badge and photo/location/message evidence sections.

- [ ] **Step 1: Extend fake repositories and write failing UI tests**

Assert a participant-created card shows `Khách hàng` or `Tài xế`, detail renders
photo evidence, a coordinate with an open-map action, immutable messages, and
the operational deadline without exposing severity as a user-submitted value.

- [ ] **Step 2: Run and verify RED**

Run: `cd apps/operations_web && flutter test test/risk_reports_view_test.dart test/risk_report_detail_evidence_test.dart`

Expected: missing reporter/evidence widgets.

- [ ] **Step 3: Implement repository selection and responsive evidence UI**

Join reporter name/role from `users`, fetch registered attachments, use signed
URLs for private photos, and render coordinate text plus external-map link using
a declared `url_launcher` dependency.
Retain existing message-evidence and report audit sections.

- [ ] **Step 4: Run tests and analyze**

Run: `cd apps/operations_web && flutter test test/risk_reports_view_test.dart test/risk_report_detail_evidence_test.dart && flutter analyze`

Expected: pass and no analyzer issues.

- [ ] **Step 5: Commit**

```powershell
git add apps/operations_web/lib/features/risk_reports apps/operations_web/test/risk_reports_view_test.dart apps/operations_web/test/risk_report_detail_evidence_test.dart
git commit -m "feat: show participant risk evidence to support"
```

### Task 8: Support intervention controls and Driver live instructions

**Files:**
- Modify: `apps/operations_web/lib/features/risk_reports/data/risk_report_repository.dart`
- Modify: `apps/operations_web/lib/features/risk_reports/widgets/risk_report_actions.dart`
- Create: `apps/operations_web/lib/features/risk_reports/widgets/risk_intervention_panel.dart`
- Modify: `apps/operations_web/lib/features/risk_reports/dialogs/risk_report_detail_dialog.dart`
- Create: `apps/operations_web/test/risk_intervention_actions_test.dart`
- Create: `apps/delivery_app/lib/features/risk_reports/data/risk_intervention_repository.dart`
- Create: `apps/delivery_app/lib/features/risk_reports/widgets/driver_risk_instruction_card.dart`
- Modify: `apps/delivery_app/lib/features/driver/screens/navigation/widgets/driver_navigation_view.dart`
- Modify: `apps/delivery_app/lib/core/models/order_model.dart`
- Modify: `apps/delivery_app/lib/features/customer/screens/tracking/utils/tracking_map_phase.dart`
- Modify: `apps/delivery_app/lib/features/driver/screens/home/utils/driver_home_formatters.dart`
- Create: `apps/delivery_app/test/driver_risk_instruction_test.dart`

**Interfaces:**
- Operations repository adds `acceptReport`, `holdBeforePickup`, `decideOperation`, `confirmCustodyResolved`, `resumeHeldOrder`, and `addInternalNote` RPC wrappers.
- Delivery repository provides an order-scoped realtime/current intervention.
- Driver card emits only valid acknowledgement/custody actions for its state.

- [ ] **Step 1: Write failing Support and Driver tests**

Verify accepting changes report status only; pre-pickup hold offers release;
cargo state requires continue/return/handoff; instruction text is mandatory;
return/handoff keeps driver busy until confirmed; released hides blocking UI;
`risk_hold` parses and displays without crashing existing order views.

- [ ] **Step 2: Run and verify RED**

Run:

```powershell
cd apps/operations_web
flutter test test/risk_intervention_actions_test.dart
cd ../delivery_app
flutter test test/driver_risk_instruction_test.dart
```

Expected: missing RPC methods/widgets and unknown `risk_hold` display mapping.

- [ ] **Step 3: Implement Support actions and live Driver state**

Render `Tiếp nhận báo cáo` separately from operational controls. Require a
custom instruction dialog for return/handoff. Sort overdue awaiting-triage rows
before normal rows and expose an internal-note composer only to staff. In Driver
navigation, render a high-contrast token-based
instruction card above progression controls and disable incompatible actions.
Map `risk_hold` explicitly in customer tracking and driver status formatters so
no switch falls through to a misleading delivery state.

- [ ] **Step 4: Run risk workflow and navigation regressions**

Run:

```powershell
cd apps/operations_web
flutter test test/risk_intervention_actions_test.dart test/risk_report_policy_test.dart
flutter analyze
cd ../delivery_app
flutter test test/driver_risk_instruction_test.dart test/driver_navigation_route_logic_test.dart test/driver_delivery_workflow_test.dart
flutter analyze
```

Expected: all pass.

- [ ] **Step 5: Commit**

```powershell
git add apps/operations_web/lib/features/risk_reports apps/operations_web/test/risk_intervention_actions_test.dart apps/delivery_app/lib/features/risk_reports apps/delivery_app/lib/features/driver apps/delivery_app/lib/core/models/order_model.dart apps/delivery_app/test/driver_risk_instruction_test.dart
git commit -m "feat: coordinate support triage and driver release"
```

### Task 9: End-to-end verification and documentation alignment

**Files:**
- Modify only if behavior differs: `README.md`
- Modify only if phase tracking differs: `ROADMAP.md`

**Interfaces:**
- Consumes all previous tasks.
- Produces a verified, reviewable working tree without applying unrelated edits.

- [ ] **Step 1: Format all touched Dart files**

Run: `dart format packages/giaohang_domain/lib apps/delivery_app/lib/features/risk_reports apps/operations_web/lib/features/risk_reports`

Expected: formatter exits zero.

- [ ] **Step 2: Run complete verification**

Run:

```powershell
cd apps/delivery_app
flutter analyze
flutter test
cd ../operations_web
flutter analyze
flutter test
flutter build web
```

Expected: both analyzers clean, every test passes, and Operations Web builds.

- [ ] **Step 3: Check scope and file sizes**

Run:

```powershell
git diff --check
git status --short
$riskPaths = @(
  'packages/giaohang_domain/lib/src/risk_report.dart',
  'apps/delivery_app/lib/features/risk_reports',
  'apps/operations_web/lib/features/risk_reports'
)
Get-ChildItem -Recurse -File $riskPaths | Where-Object Extension -eq '.dart' |
  ForEach-Object { '{0} {1}' -f $_.FullName,(Get-Content $_.FullName).Count }
```

Expected: no whitespace errors, no Supabase changes outside the approved
participant/intervention migrations, no unrelated user edits staged, and every touched UI file below 400
lines.

- [ ] **Step 4: Review security invariants manually**

Confirm client RPCs derive identity from `auth.uid()`, all definer functions use
empty search paths and revoked public execution, Storage is private, evidence is
immutable, Support actions lock state, and no participant can set severity,
assignment, status, or reporter role.

- [ ] **Step 5: Commit any documentation-only alignment**

```powershell
git add README.md ROADMAP.md
git commit -m "docs: document manual risk reporting workflow"
```

Skip this commit when no documentation alignment is necessary.
