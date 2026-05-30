# Project Guardrails

Permanent source of truth for future Codex sessions. This file contains only non-negotiable project rules and decision order.

## Project Vision

- Build one Flutter app for all roles; do not split into separate customer, driver, admin, or shared repos.
- Support three role experiences in the same app:
  - Customer: place orders and track deliveries.
  - Driver: receive assignments, update availability, and deliver orders.
  - Admin: manage orders, drivers, and operational visibility.
- Use Supabase as the backend for auth, database, realtime, and storage.
- Prefer Riverpod for state management direction. Do not introduce Bloc or another state framework without approval.

## Approved Development Order

### Track A - Cleanup

1. Documentation alignment
2. AccountScreen cleanup
3. TrackingScreen cleanup
4. DashboardScreen cleanup
5. OrderScreen cleanup

### Track B - Stabilization

1. CreateOrderScreen review
2. Schema compatibility verification
3. Provider review
4. Service review

### Track C - Driver Features

1. Driver online/offline
2. Driver location storage
3. Driver assignment

### Track D - Tracking Features

1. Real order tracking
2. Order status timeline
3. Realtime updates

### Track E - Maps

1. flutter_map
2. OpenStreetMap
3. Route visualization

### Track F - Dispatch Algorithms

1. Haversine distance
2. Nearest driver selection
3. Assignment service

### Track G - Advanced Research

1. Route optimization
2. Multi-order assignment
3. Research algorithms

## Safety Rules

- Do not change Supabase schema without explicit approval.
- Do not change RLS policies without explicit approval.
- Do not change Edge Functions without explicit approval.
- Do not rewrite project architecture without explicit approval.
- Do not split the app or repository without explicit approval.
- Do not change runtime configuration or secret-loading strategy without explicit approval.

## Session Rules

Before any task, identify:

- Roadmap track.
- Risk level: low, medium, or high.
- Affected files.

If the task does not fit an approved track, state that clearly before proceeding.
