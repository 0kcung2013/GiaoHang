# Manual Order Risk Reporting Design

## Status

Approved in conversation on 2026-08-11. The user separately authorized the
Supabase schema, migration, storage, and RLS changes required by this feature.

## Objective

Allow an order customer or its assigned driver to submit a structured incident
report with optional evidence. Support receives the report in the existing risk
queue, performs a fast operational triage, and may continue investigating after
the driver has been released from the delivery task.

The customer-facing term is **Báo cáo sự cố**. **Báo cáo rủi ro** remains an
internal Support/Admin term.

## Scope

The first implementation includes:

- Manual reporting by the order customer or assigned driver.
- Role-aware preset reasons plus `Vấn đề khác`.
- Required description and optional photo, current GPS location, and selected
  order-message evidence.
- A three-step mobile bottom-sheet flow: reason, evidence, review and submit.
- Secure database commands that validate order participation.
- Delivery to the existing Support risk queue with reporter identity and role.
- Support assignment, investigation, notes, escalation, and closure using the
  existing risk workflow.
- A separate operational intervention with a ten-minute triage target.
- Immediate release of a driver when a pre-pickup order is put on hold.
- Continue, return, or handoff instructions when the driver already has cargo.

The first implementation excludes:

- Automatic risk detection or AI classification.
- User-selected risk severity.
- Risk metrics, charts, and aggregate reporting.
- Automatic punishment, account locking, or a violation conclusion.
- Replacing the existing Support risk queue.

## Product Principles

- A report is an allegation requiring review, not proof of a violation.
- Accepting a report and pausing an order are separate Support actions.
- A long investigation must not keep a driver idle after cargo custody has been
  resolved.
- The system never releases a driver who still holds cargo without an explicit
  continue, return, or handoff instruction.
- Every privileged transition is atomic and auditable.

## Entry Points and Visual Hierarchy

### Customer

- Order detail shows a secondary outlined `Báo cáo sự cố` action near the final
  support section, below required order information.
- Active tracking exposes the same action inside the support/action area, not as
  an overlay that competes with the map, ETA, or contact-driver action.
- The action uses `Icons.report_problem_rounded`, a 48 dp minimum touch target,
  `AppColors` tokens, a visible label, and semantics.

### Driver

- Active navigation places `Báo cáo sự cố` in the secondary action menu or
  support sheet, separated from `Đã lấy hàng` and `Đã giao hàng`.
- Assigned-order detail exposes the same action so a driver can report before
  navigation starts.
- The incident action is never a red primary CTA; red is reserved for confirmed
  destructive or blocking states.

The implementation follows the existing Clean Utility Premium system, uses
`AppColors`, `AppTextStyles`, `AppSpacing`, and `AppRadius`, and supports 375 dp
width and text scale 1.6.

## Report Wizard

The wizard is a custom modal bottom sheet with a drag handle, step indicator,
safe-area padding, back/cancel routes, and one primary action per step.

### Step 1: Choose a problem

Customer choices:

- Giao chậm hoặc không liên lạc được.
- Tài xế hoặc hành trình bất thường.
- Hàng sai, thiếu, hoặc hư hỏng.
- Vấn đề thanh toán.
- Vấn đề an toàn.
- Vấn đề khác.

Driver choices:

- Không liên lạc được người gửi/người nhận.
- Địa chỉ hoặc điểm giao bất thường.
- Hàng sai, hư hỏng, hoặc nghi thuộc danh mục cấm.
- Vấn đề thanh toán.
- Vấn đề an toàn.
- Vấn đề khác.

The role-aware choices map to stable database categories. The migration adds
`contact_issue` and `cargo_issue`; existing categories remain valid.

### Step 2: Add information

- Description is required, trimmed, and 10 through 4,000 characters.
- Up to five compressed photos may be selected from camera or gallery.
- Current GPS location is opt-in and shows a clear included/not-included state.
- The reporter may select retained messages from this order only.
- No severity selector is rendered. Client-created reports retain the internal
  default `medium` only for compatibility with the existing Support workflow.

### Step 3: Review and submit

The review displays order code, selected reason, description, photo count,
location state, and message count. Submission is disabled while uploading or
calling the database command. Success returns the report reference and
`Chờ tiếp nhận`; failure preserves all form input and offers retry.

## Shared Domain and App Boundaries

Common risk enums, report status, category mapping, reporter role, and immutable
report/evidence DTOs belong in `packages/giaohang_domain`. Delivery App and
Operations Web must not define competing copies.

Delivery App adds a focused `features/risk_reports/` module:

- `data/`: Supabase command/repository and evidence upload.
- `controllers/`: wizard state, validation, submission, and retry.
- `widgets/`: role-aware entry action and three-step bottom sheet.
- `utils/`: display strings and category presentation.

Operations Web continues using `features/risk_reports/`, updated to consume the
shared domain types and to render reporter/evidence/intervention information.

## Data Model

### Existing `risk_reports`

The table remains the source of truth. A migration:

- Extends allowed categories with `contact_issue` and `cargo_issue`.
- Records `reporter_role_snapshot` (`customer`, `driver`, `support`, `admin`).
- Adds `triage_due_at`, defaulting to ten minutes after client report creation.
- Adds `escalated_at` for overdue operational triage.
- Keeps severity internal and defaults participant reports to `medium`.
- Keeps the active `(order_id, category)` uniqueness rule.

Participant creation uses a dedicated `SECURITY DEFINER` command. Direct table
insert remains unavailable to Customer and Driver.

### `risk_report_attachments`

| Column | Purpose |
| --- | --- |
| `id` | Immutable UUID identifier |
| `risk_report_id` | Parent report |
| `order_id` | Order snapshot used for authorization and queries |
| `evidence_type` | `photo` or `location` |
| `storage_path` | Private bucket path for a photo; null for location |
| `latitude`, `longitude` | Location snapshot; null for photo |
| `captured_at` | Client capture time |
| `added_by` | Reporter identity |
| `created_at` | Database insertion time |

Rows are immutable. Reporter participants may read their own report evidence;
Support/Admin may read evidence for queue processing.

### Existing `risk_report_message_evidence`

The immutable message snapshot table is reused. The participant-create command
may attach selected messages only when each message belongs to the same order
and the caller participates in that order. Normal chat retention cannot remove
the evidence snapshot.

### `risk_report_interventions`

This table separates report investigation from immediate order operations.

| Column | Purpose |
| --- | --- |
| `risk_report_id`, `order_id` | One intervention linked to a report and order |
| `state` | `awaiting_triage`, `held_before_pickup`, `continue_delivery`, `return_required`, `handoff_required`, or `released` |
| `driver_id` | Driver affected at intervention time |
| `decision_due_at` | Ten-minute operational response target |
| `decided_by`, `decided_at` | Support/Admin decision audit |
| `instruction` | Required operational instruction for return/handoff |
| `driver_released_at` | When the driver became eligible for new work |
| `created_at`, `updated_at` | Audit timestamps |

Intervention changes are made only through protected database commands and are
mirrored into `risk_report_events`.

### Order hold state

The order-status enum adds `risk_hold` for a pre-pickup operational hold. This
state is not an active driver assignment and is not eligible for automatic
matching. When Support holds an `assigned` order before pickup, one transaction:

1. records the intervention;
2. sets the order to `risk_hold`;
3. clears `orders.driver_id`;
4. records a status log and driver release time.

Resuming returns the order to `confirmed`, after which normal assignment may run.
Cancelling uses the existing terminal cancellation behavior.

An order already in `picking_up` or `delivering` does not enter `risk_hold` and
does not release its driver immediately. It remains active until Support chooses
continue, return, or handoff and cargo custody is completed.

## Secure Commands and Authorization

### Create participant report

The command accepts a client-generated report UUID, order ID, category,
description, optional uploaded photo paths, optional location, and selected
message IDs. It derives reporter identity and role from `auth.uid()` and verifies:

- Customer callers own `orders.customer_id`.
- Driver callers equal the order's assigned `driver_id`.
- Every message and storage path belongs to the same caller/order/report.
- Input length, count, coordinate, category, and duplicate-report constraints.

The command creates the report, evidence snapshots, initial audit event, and
`awaiting_triage` intervention atomically. It returns the report ID and status.

### Support operational decisions

Protected Support/Admin commands provide:

- Accept for investigation without changing the order.
- Hold and release a pre-pickup order.
- Continue delivery.
- Require return with an instruction.
- Require handoff with an instruction.
- Confirm custody resolution and release the driver.
- Resolve or dismiss the report through existing allowed transitions.

Database code validates the current order and intervention state so a stale UI
cannot release the wrong driver or overwrite a later decision.

### Storage

Photos use a private `risk-report-evidence` bucket. Upload paths are
`<auth.uid()>/<report_id>/<file_id>.<ext>`. Storage RLS permits participants to
upload only under their own prefix and permits Support/Admin to read registered
evidence. The report command rejects paths outside the reporter/report prefix.
If database submission fails, the client attempts best-effort cleanup and keeps
the local form so the user can retry.

## Support Processing and SLA

New reports enter the existing queue as `Chờ tiếp nhận`. The card and detail show
reporter name/role, order snapshot, category, description, evidence counts, and
the operational response deadline.

`Tiếp nhận báo cáo` changes the report to `Đang xử lý`; it does not pause the
order. If an operational hold is necessary, Support selects a separate action.

The ten-minute target concerns only the immediate operational decision. Once
cargo is delivered, returned, handed off, or never collected, the driver may be
released while the report remains under investigation for hours or days.

An overdue `awaiting_triage` intervention is marked escalated and sorted ahead of
normal reports for both Support and Admin. This is an operational alert, not a
risk severity or analytics dashboard. A private idempotent database function,
scheduled once per minute with the existing Supabase Cron convention, stamps
`escalated_at` after `decision_due_at`; client roles cannot execute it.

## Realtime Behavior

- The reporter sees report-status and intervention updates for their own order.
- A driver sees an explicit hold or instruction surface above normal delivery
  controls; incompatible completion actions are disabled.
- A pre-pickup released driver returns to the available workflow immediately.
- A driver holding cargo remains busy only until custody resolution, not until
  the investigation closes.
- Support queue and detail refresh through existing Supabase Realtime patterns
  or a bounded refetch after commands.

## Error Handling

- Missing category or invalid description: inline validation at the field.
- Location denied: continue without location and explain that it is optional.
- Photo upload failure: preserve the form and retry only failed uploads.
- Expired/unauthorized order access: close submission and explain that the order
  is unavailable for reporting.
- Duplicate active category: link to the existing report instead of creating a
  second queue item.
- Stale Support action: refetch the latest order/intervention and show the new
  state rather than applying a conflicting action.
- Report created but notification delivery fails: the database row remains the
  source of truth and appears on the next queue fetch.

## Testing and Acceptance Criteria

### Database

- The order customer and assigned driver can create a report through the command.
- An unrelated authenticated user and a driver from another order are rejected.
- Participant direct table writes, severity spoofing, and reporter-role spoofing
  are rejected.
- Evidence message/order/report mismatches and invalid storage paths are rejected.
- Duplicate active `(order, category)` creation returns the existing conflict.
- Support accepting a report does not alter the order.
- Pre-pickup hold atomically clears the assignment and makes the driver eligible.
- A cargo-holding driver cannot be released without custody resolution.
- Overdue triage is escalated without changing user-visible severity.
- Audit history records creation, assignment, intervention, and resolution.

### Delivery App

- Customer and driver entry points render in the intended secondary locations.
- The three-step wizard validates category and description and preserves state on
  back, retry, keyboard resize, small screens, and text scale 1.6.
- Submission shows loading once, prevents duplicate taps, and reports success.
- GPS permission denial and partial upload failure have usable recovery states.
- Hold/continue/return/handoff updates render correctly for the assigned driver.

### Operations Web

- New participant reports appear in the existing queue with reporter role.
- Evidence photo, location, and message snapshots render in report detail.
- Accepting a report does not implicitly hold an order.
- Only valid operational actions are available for the current delivery phase.
- Overdue operational cases sort ahead of normal cases for Support and Admin.

## Reporting Narrative

The graduation report may describe this as a manually initiated, order-scoped
risk workflow with structured evidence, database-enforced authorization,
auditable Support decisions, and a separation between fast operational triage
and longer incident investigation. It must not claim automatic AI detection or
automatic violation decisions.
