# Driver Profile Change Approval — Handoff

Date: 2026-08-24

## Delivered behavior

- The driver account is read-only and never renders the driver's rating.
- Registration data is grouped into personal, vehicle, and verification cards; protected document numbers are masked.
- Every profile change is submitted as one persisted aggregate request. A driver can have only one active draft/pending/applying request.
- Admin reviews the complete current-to-requested diff and approves or rejects the whole request. Rejection requires a reason.
- Email and avatar changes use the compensating Edge Function flow; other fields use the conflict-aware approval RPC.
- Support/CSKH has no profile-request table policy, command grant, UI route, repository, or Admin screen import. Support remains scoped to delivery issues.
- Driver request and Admin queue views refresh through Supabase Realtime. An approved/conflicted request invalidates the driver's account profile.
- Draft KYC/profile media remains private. Admin resolves object paths to signed URLs that expire after five minutes.

## Access matrix encoded in migrations

| Actor | Own request | Another driver's request | Approve/reject | Direct profile edit | Rating/self-review |
| --- | --- | --- | --- | --- | --- |
| Driver | Create/read/submit/cancel own active request | No access | No | GPS-only direct write; profile fields blocked | Hidden |
| Admin | Read all | Read all | Whole-request decision | Through approval commands | Available to Admin RPCs |
| Support/CSKH | No access | No access | No | No profile workflow | No profile workflow |
| Anonymous | No access | No access | No | No | No |

## Focused verification completed

- Shared domain: 7 tests passed.
- Delivery App: 22 focused migration/repository/provider/widget tests passed.
- Operations Web: 8 focused repository/media/widget/realtime tests passed.
- Edge approval flow: 3 Deno tests passed.
- Focused Delivery and Operations `flutter analyze --no-pub` runs completed with no issues.
- No changed production file exceeds 400 lines. Largest new Admin file: 387 lines; largest new Driver request file: 380 lines.
- Source audit found no rating text/value/star icon in the driver account implementation and no Support imports in the Admin profile-change feature.

## Commits

- `3861b50` — shared request domain model
- `180cffc` — request lifecycle migration and RLS/RPC commands
- `04b931e` — rating privacy and direct-write hardening
- `b64cbf0` — private storage and approval Edge Function
- `cc7e743` — driver repository/providers
- `0fc5cc1` — rating-free driver account and request UI
- `f78bea2` — Admin repository and media resolver
- `765b8c0` — Admin approval queue and whole-request decision UI

## Not applied or claimed

- On 2026-08-25, local verification was attempted with Supabase CLI `2.109.1`. The CLI profile-file regression was bypassed without losing the existing profile, but Docker Desktop's Linux engine repeatedly returned HTTP 500. No local reset or migration application started.
- Migrations were not applied to a local, development, or production Supabase database.
- The Edge Function was not deployed.
- The authenticated Driver A/Driver B/Admin/Support/anonymous SQL matrix was not executed because schema application needs separate environment approval.
- Supabase security/performance advisors were not rerun after deployment because no deployment occurred.
- Full app test suites, release builds, and end-to-end browser/device tests were not run.

## Existing database advisory

A read-only advisor inspection reported that `public.spatial_ref_sys` currently has RLS disabled. This pre-existing finding was not changed because enabling RLS can affect PostGIS access and requires a separate database decision.
