# QR dashboard implementation brief

## Objective
Build the production Flutter dashboard page for authenticated ServeFlow owners/managers to generate, display, download/print, and regenerate opaque QR tokens for dining tables and applicable takeaway/counter targets.

## Target audience
Restaurant and food-court owners/managers using the existing Flutter admin dashboard.

## Aesthetic direction
Operational and calm, matching the existing ServeFlow cream/navy/amber Material 3 dashboard. Reuse existing shared widgets/colors/panel conventions. The QR image is the visual anchor; do not introduce external imagery or a new visual language.

## Content structure
- Page header and concise explanation that links use a future placeholder scan domain.
- Restaurant: business/counter QR plus business dining-table QR targets.
- Food court: selected stall QR plus shared business dining-table QR targets when applicable to current access.
- Target cards/rows showing name, target type, token state/timestamp, and action to generate/view.
- QR detail dialog/panel showing a scannable QR for `https://future-domain/scan/<opaque-token>`, copyable/readable URL, download and print actions, and regenerate.
- Regenerate requires explicit confirmation that the old QR immediately stops working.
- Loading, empty, and safe error states.

## Permissions
Page is owner/manager only. Backend remains authoritative. Stall managers operate only on their selected stall; owners can operate across their accessible business context. Follow current Table/Menu permission conventions.

## Technical constraints
- Existing app uses `part of '../../main.dart'` feature pages and imports packages centrally in `lib/main.dart`.
- Add isolated files under `lib/features/qr/`: model, service, dashboard page as appropriate.
- Use `qr_flutter` for QR rendering and `printing` for print/share/download-compatible output.
- Do not modify Menu, Table, Staff, or Business Profile files.
- Do not modify dashboard routing in this delegated task; root agent will integrate it minimally.
- Assume RPC names/contracts provided by proposal: `list_qr_tokens`, `generate_qr_token`, `resolve_qr_token` (inspect proposal or coordinate if not yet present).
- Output path: `lib/features/qr/`.

## Existing design references
- `lib/features/tables/table_management_page.dart`
- `lib/features/stalls/stall_management_page.dart`
- `lib/features/stalls/dashboard_page.dart`
- `lib/core/widgets/shared_widgets.dart`

## Memorable quality
The preview should feel print-ready and trustworthy: strong whitespace around the QR, clear location identity, and an unmistakable warning around rotation.

## Image needs
None.
