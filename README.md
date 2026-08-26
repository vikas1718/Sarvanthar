# ServeFlow

ServeFlow is a cross-platform Flutter application for managing restaurants and food courts. It provides a single workspace for owners and staff to manage business details, stalls, team access, menus, dining tables, and customer-facing QR codes.

## Features

- Email and password authentication with session restoration
- Restaurant and food-court workspace creation
- Role-based access for owners, managers, kitchen staff, cashiers, and general staff
- Staff invitations and stall-specific assignments
- Business profile and stall management
- Menu categories, items, options, availability, and image uploads
- Dining-table management
- QR token generation, preview, PDF export, and printing
- Multi-business and multi-stall workspace selection
- Supabase Row Level Security (RLS) and protected database functions

## Tech stack

- Flutter and Dart
- Supabase Auth, PostgreSQL, Storage, and RLS
- `image_picker` for menu images
- `qr_flutter` for QR code rendering
- `pdf` and `printing` for printable QR materials

## Project structure

```text
lib/
|-- core/                 # App configuration, routing, and shared widgets
|-- features/
|   |-- access/           # Workspace and role selection
|   |-- auth/             # Authentication and invitations
|   |-- business/         # Business profile management
|   |-- menu/             # Menu categories, items, and options
|   |-- qr/               # QR token management and printing
|   |-- staff/            # Staff roles and invitations
|   |-- stalls/           # Food-court stalls and dashboard
|   `-- tables/           # Dining-table management
`-- main.dart             # Application entry point

supabase/
|-- migrations/           # Database schema, RLS policies, and RPC functions
`-- config.toml            # Local Supabase configuration
```

## Getting started

### Prerequisites

- Flutter SDK compatible with Dart `^3.13.0`
- A Supabase project, or the Supabase CLI and Docker for local development

### Setup

1. Clone the repository and install dependencies:

   ```bash
   flutter pub get
   ```

2. Apply the migrations in `supabase/migrations` to your Supabase project. With a linked Supabase CLI project, run:

   ```bash
   supabase db push
   ```

3. Enable the Email provider in Supabase Authentication. For local testing, email confirmation may be disabled; enable it for production.

4. Run the application with your Supabase credentials:

   ```bash
   flutter run \
     --dart-define=SUPABASE_URL=https://your-project.supabase.co \
     --dart-define=SUPABASE_PUBLISHABLE_KEY=your-publishable-key \
     --dart-define=QR_SCAN_BASE_URL=https://your-scan-app.example.com
   ```

   `QR_SCAN_BASE_URL` is optional and defaults to `https://scan.serveflow.app`. It should point to the separate customer-facing application that resolves scanned QR tokens.

## Security and access model

Owners have business-wide access. Restaurant staff belong directly to a business, while food-court staff are assigned to individual stalls. Database access is enforced through Supabase RLS policies and security-definer RPC functions, rather than relying only on client-side checks.

## Testing

Run Flutter's static analysis and tests with:

```bash
flutter analyze
flutter test
```

See [AUTH_TESTING.md](AUTH_TESTING.md) for the manual authentication and authorization test checklist.

## Pre-launch checklist

- Keep migration `20260824000100_customer_public_menu_and_orders.sql` byte-for-byte identical in the Flutter and Customer repositories. The Customer repository remains the source of truth; never edit only one copy.

## Supported platforms

The repository contains Flutter targets for Android, iOS, web, Windows, macOS, and Linux.
