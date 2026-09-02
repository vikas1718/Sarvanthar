# ServeFlow

flutter run -d web-server --web-port 8080

## Developer-managed organization setup

All users use the regular sign-up and login screens. An organization can only be created with a one-time developer code. After applying the latest Supabase migration, promote the initial developer once in the Supabase SQL editor:

```sql
update public.profiles set is_developer = true where id = '<auth-user-id>';
```

That user can select **Admin login** above the normal login form and create developer codes for restaurant owners. Owners enter one code when creating an organization, including from the dashboard sidebar. Email invitees see an accept/reject notification after signing in; their role is only activated after acceptance.

Multi-tenant restaurant and food-court management dashboard. Flutter front end, Supabase (Postgres + RLS) back end.

One deployment serves many businesses. A business is either a **restaurant** (single kitchen, staff attached directly to the business) or a **food court** (multiple stalls, staff attached to a stall). Access, menus, tables, and QR codes are all scoped by that distinction.

## Status

| Area                                                 | State                                              |
| ---------------------------------------------------- | -------------------------------------------------- |
| Auth, business creation, business/stall selection    | Implemented                                        |
| Business profile (logo, contact, currency, tax)      | Implemented                                        |
| Stall management (food courts)                       | Implemented                                        |
| Staff management + invitations                       | Implemented                                        |
| Menu management (categories, items, options, images) | Implemented                                        |
| Table management (dine-in)                           | Implemented                                        |
| QR codes (generate, print, regenerate)               | Implemented                                        |
| Kitchen orders (Realtime read + status workflow)     | Implemented                                        |
| Payments, Reports, Settings                          | **Not started** — nav entries render a placeholder |
| Customer-facing scan destination                     | **Not started** — separate Next.js project         |

## Getting started

```bash
flutter pub get
```

The app loads its client configuration from the bundled `.env` asset on every
Flutter target (Windows, Android, iOS, Chrome, and Edge). Set
`SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` there, then run normally:

```bash
flutter pub get
flutter run
```

The Supabase anon/publishable key is a public client credential and is safe to
bundle. Do not put a service-role key, Razorpay key secret, or any server
credential in `.env`; Razorpay secrets remain Supabase Edge Function secrets.

### Razorpay subscriptions

The `create-razorpay-subscription` Edge Function must be deployed and configured in the same Supabase project as the app. Keep Razorpay credentials out of the Flutter `.env` file: they are server secrets.

```bash
supabase functions deploy create-razorpay-subscription
supabase secrets set RAZORPAY_KEY_ID=rzp_test_... RAZORPAY_KEY_SECRET=... RAZORPAY_PLAN_ID=plan_...
```

Use a plan ID from the same Razorpay account and mode as the key pair (test keys with a test plan, or live keys with a live plan). Apply migration `20260901000300_razorpay_subscription_metadata.sql` before enabling the button:

```bash
supabase db push
```

| `.env` variable              | Required     | Default                                     |
| ---------------------------- | ------------ | ------------------------------------------- |
| `SUPABASE_URL`               | yes          | —                                           |
| `SUPABASE_PUBLISHABLE_KEY`   | yes          | —                                           |
| `QR_SCAN_BASE_URL`           | no           | `https://scan.serveflow.app`                |
| `RAZORPAY_CHECKOUT_PAGE_URL` | Windows only | Hosted URL for `web/razorpay_checkout.html` |

`QR_SCAN_BASE_URL` is the origin printed into QR codes. It points at a placeholder until the customer-facing app exists. Only the origin changes when that ships, so codes printed today keep working.

For Windows builds, deploy the Flutter web output with `web/razorpay_checkout.html` at the configured URL, then set `RAZORPAY_CHECKOUT_PAGE_URL=https://app.example.com/razorpay_checkout.html` in `.env`. The host must be enabled for the Razorpay key in the Razorpay Dashboard.

Requires Dart SDK `^3.13.0`.

## Architecture

**The whole UI is one Dart library.** `lib/main.dart` declares every page as a `part`, and each page file opens with `part of '../../main.dart'`. Services and models are ordinary imports; pages are not.

Consequences worth knowing before you add a file:

- Every `_private` name shares a single namespace across all page files. A new `_Panel` in one feature collides with `_Panel` in another. Prefix new private widgets by feature (`_QrTargetCard`, `_MenuRow`).
- Shared chrome and design tokens live in `lib/core/widgets/shared_widgets.dart` (`_navy`, `_amber`, `_cream`, `_line`, `_muted`, `_PageShell`, `_Panel`, `_primaryStyle`, `_notice`).
- A new page needs both an `import` for its service/model files and a `part` directive in `main.dart`.

```
lib/
  core/
    config/app_config.dart        bundled .env configuration
    router/app_router.dart        page enum + auth-driven navigation
    widgets/shared_widgets.dart   design tokens, shared chrome
  features/
    access/      business + stall selection, role resolution
    auth/        sign in / sign up
    business/    business creation, profile
    stalls/      dashboard shell, stall management
    staff/       staff list, invitations
    menu/        categories, items, options
    tables/      dine-in tables
    qr/          QR token generation and printing
    kitchen/     live order queue and status updates
```

Data access is a thin service class per feature (`QrService`, `TableService`, …) wrapping `SupabaseClient`. Writes that need authorization go through Postgres RPCs, not direct table writes.

## Roles and permissions

Roles: `owner`, `manager`, `kitchen`, `cashier`, `staff`. One owner per business, enforced by a partial unique index.

Sidebar visibility, as implemented:

| Section                       | owner | manager | kitchen | cashier | staff |
| ----------------------------- | :---: | :-----: | :-----: | :-----: | :---: |
| Overview                      |  ✅   |   ✅    |   ✅    |   ✅    |  ✅   |
| Business Profile              |  ✅   |    —    |    —    |    —    |   —   |
| Stalls _(food court only)_    |  ✅   |    —    |    —    |    —    |   —   |
| Staff                         |  ✅   |    —    |    —    |    —    |   —   |
| Menu                          |  ✅   |   ✅    |   ✅    |    —    |   —   |
| Tables                        |  ✅   |   ✅    |    —    |    —    |   —   |
| QR Codes                      |  ✅   |   ✅    |    —    |    —    |   —   |
| Orders                        |  ✅   |   ✅    |   ✅    |   ✅    |   —   |
| Payments / Reports / Settings |  ✅   |   ✅    |   ✅    |   ✅    |  ✅   |

Payments, Reports, and Settings currently render placeholders. Orders opens the
Realtime Kitchen queue for Owner, Manager, Kitchen, and Cashier roles.

**Client-side gating is cosmetic.** Every rule above is enforced again in Postgres via RLS policies and `security definer` RPCs that check `auth.uid()`. Helpers live in the `private` schema: `is_business_owner`, `has_business_access`, `has_stall_access`, `can_manage_menu`, `can_manage_tables`, `can_manage_qr_tokens`.

One subtlety if you add an RLS policy that calls a `private` helper: policy expressions evaluate with the _querying_ role's privileges, so that helper needs `grant execute ... to authenticated`. Helpers called only from inside `security definer` bodies don't.

## Database

Migrations are applied with the Supabase CLI:

```bash
supabase db push
```

```
supabase/
  migrations/   applied, in timestamp order
  proposals/    written and reviewed, NOT applied
```

`supabase/proposals/` is a deliberate convention: schema changes are drafted there with a `-- REVIEW ONLY` header, reviewed, then moved into `migrations/` unchanged and pushed. Don't apply a proposal without approval, and don't edit a migration that has already been applied — write a corrective one.

`anon` is locked out of the `public` schema wholesale (`revoke all on all tables/functions ... from anon`). Note that Supabase's default privileges grant _new_ public-schema tables to `anon`, so a new table needs its own explicit `revoke` — an earlier blanket revoke does not cover it.

## QR codes

Owners and managers generate one QR per dine-in table, and per stall (food court) or per business counter (restaurant). Codes render on screen, print, or download as a vector PDF. Regenerating mints a new code and **invalidates the old one immediately** — anything already printed stops working.

Tokens are 128 bits of `gen_random_bytes` hex, unrelated to any database id, so a scan URL discloses nothing about the table or stall. The alphabet is lowercase-only (`^[a-f0-9]{32}$`); a hand-transcribed uppercase URL will not resolve.

### `resolve_qr_token` is the only anon-executable function in this project

```sql
grant execute on function public.resolve_qr_token(text) to anon, authenticated;
```

A customer scanning a printed code is anonymous by definition and must learn which business, stall, and table they're at before anything else can happen. There is no session to authenticate, and `enable_anonymous_sign_ins = false` rules out throwaway signups.

It is read-only, `security definer` (so `anon` holds no direct privilege on `qr_tokens` — a direct table read returns `permission denied`), regex-gates its input before any query, and fails closed on archived or deactivated businesses, stalls, and tables. It returns exactly what the person holding the physical code can already see, plus the ids the customer app needs to load a menu.

Resolution failures are deliberately distinguishable, so support can tell a reissued code from a bad one:

| Message                       | Cause                                                    |
| ----------------------------- | -------------------------------------------------------- |
| `QR code is not valid`        | malformed, or no such token                              |
| `QR code has been replaced`   | token was retired by regeneration                        |
| `QR code is no longer active` | token is live, but its target is archived or deactivated |

**Before launch:** add a rate limit to this endpoint. It is the only unauthenticated entry point in the system.

## Testing

There is no test harness — no `test/` directory, no widget or integration tests.

Backend behaviour has been verified by exercising the RPCs against a real project with disposable fixtures: token generation, regeneration and revocation, anonymous resolve, malformed and nonexistent input, cross-business rejection, per-role denial, and archived-target refusal.

The Flutter UI is compile-checked only. QR image rendering and the PDF print/download paths have never been executed. Verify those manually on a real device after touching them.

```bash
flutter analyze
```

See [AUTH_TESTING.md](AUTH_TESTING.md) for the manual authentication and authorization test checklist.

## Pre-launch checklist

- Keep migration `20260824000100_customer_public_menu_and_orders.sql` byte-for-byte identical in the Flutter and Customer repositories. The Customer repository remains the source of truth; never edit only one copy.

## Supported platforms

The repository contains Flutter targets for Android, iOS, web, Windows, macOS, and Linux.
