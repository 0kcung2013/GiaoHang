---
name: giaohang-flutter-ui
description: Project-specific Flutter UI/UX workflow for GiaoHang. Use whenever auditing, designing, prototyping, reviewing, or changing presentation in apps/delivery_app or apps/operations_web, including screens, shared widgets, responsive layout, accessibility, visual assets, motion, and design tokens. Do not use for backend-only, database-only, or business-logic-only work.
---

# GiaoHang Flutter UI

Use this workflow for every UI task in either Flutter app. This skill controls the
process; it does not replace the repository's design source of truth.

## Read the local sources first

Before proposing or changing UI, inspect the relevant parts of:

1. AGENTS.md for mandatory architecture and safety constraints.
2. DESIGN.md and docs/design/visual_first_ui.md for the current design language
   and role-specific UX.
3. packages/giaohang_design/lib/src/app_theme.dart for tokens that actually
   compile today.
4. The target screen, its shared widgets, assets, route, and Riverpod providers.

Treat executable Dart tokens as the implementation truth when prose and code
have drifted. Report the drift instead of silently inventing a third version.
For an explicitly requested design experiment, keep deliberate deviations local
to the experiment until the user approves them as a project-wide direction.

## Protect application contracts

- Separate presentation from authentication, order, map, GPS, realtime, and
  role-detection behavior before editing.
- Preserve provider public contracts, GoRouter paths and redirects, repository
  calls, service behavior, permissions, Supabase schema, and persistence unless
  the user explicitly expands the task.
- Keep provider watching as narrow as practical. Do not move business logic into
  visual widgets to make a mockup easier.
- Keep screen files responsible for scaffold, top-level composition, navigation
  entry points, and provider wiring. Extract a widget only when it has a coherent
  visual responsibility; never split by line count alone.

## Work from evidence, not adjectives

When the user supplies a screenshot or video reference:

- Inspect the actual reference when accessible. Never claim to have viewed an
  inaccessible video or hidden frame.
- Translate it into hierarchy, composition, spacing rhythm, typography,
  surfaces, contrast, imagery, motion, and feedback principles.
- Do not copy branding or pixels. Adapt the principles to GiaoHang's content,
  roles, states, and interaction contracts.
- Explain which observed qualities create the perceived visual quality. Avoid
  reducing the design direction to isolated values such as a color or radius.

Use ui-ux-pro-max only for optional visual/UX research when the task genuinely
benefits from it. Its output is advisory; reconcile it with this repository and
Flutter before implementation. Do not use the web-specific ui-styling skill as
the implementation workflow for Flutter screens.

## Compose the interface

- Establish one dominant action and a clear reading order before decorating.
- Use AppColors, AppTextStyles, AppSpacing, AppRadius, AppShadow, and motion
  tokens where they fit. Avoid arbitrary one-off values without a local visual
  reason.
- Prefer a small number of deliberate surface levels. Borders, shadows, blur,
  gradients, and illustrations must communicate hierarchy rather than merely
  make the screen busy.
- Avoid raw Material-default appearance. Native Flutter widgets are allowed,
  but style them through the project language and interaction states.
- Keep icons from one coherent family per surface. Pair color with text, shape,
  or icon for semantic states; never make color the only signal.
- Preserve readable Vietnamese text, dynamic text scaling, minimum 48x48 touch
  targets for primary interactions, focus visibility, semantics, and contrast.

## Design for real viewports

- Render the app directly in the available viewport. Do not add a decorative
  phone frame, fake notch, or fixed device canvas unless the user explicitly
  requests a marketing mockup.
- Do not assume a single 390x844 layout. Use SafeArea, LayoutBuilder, and
  MediaQuery constraints intentionally for Android, iOS, and web.
- Account for status/navigation bars and viewInsets from the software keyboard.
  A no-scroll resting layout must still provide a usable keyboard state; allow a
  focused form region to adapt or scroll when the usable height contracts.
- On wide web viewports, constrain readable content width and use surrounding
  space compositionally. Do not stretch mobile forms edge to edge.
- Avoid fixed heights that clip essential content on short devices. Test the
  smallest supported viewport before optimizing the hero artwork.

## Use motion with restraint

- Animate state change or reading order, not every object.
- Prefer AnimatedContainer, AnimatedSwitcher, AnimatedOpacity, tweens, and
  tightly scoped controllers. Limit animated rebuilds to the affected subtree.
- Respect reduced-motion accessibility when practical.
- Avoid expensive full-screen blur, repeated shader work, or large animated
  raster assets without profiling evidence.
- Keep maps, markers, long lists, and provider-driven regions outside unrelated
  animation rebuilds.

## Validate the result

For an implementation task:

1. Format changed Dart files.
2. Run targeted flutter analyze and the relevant widget/auth tests.
3. Exercise loading, validation error, disabled, focus, password visibility,
   keyboard dismissal, text scale, and back navigation where applicable.
4. Check at least one short mobile viewport and one representative target
   viewport. For cross-platform screens, also check a wide browser viewport.
5. Inspect the rendered result or screenshot when the environment supports it.
   State clearly when visual verification was not possible.

Do not spread an experimental visual direction to other screens merely because
the prototype compiles. Wait for explicit user approval before updating global
tokens, shared component behavior, or unrelated role surfaces.
