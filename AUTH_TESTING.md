# Authentication test checklist

Run the app with a Supabase URL and publishable key, then test with real email addresses configured in the Supabase Auth dashboard. Enable the Email provider. For local testing without confirmation emails, disable Confirm email in the provider settings; re-enable it before production.

1. New user: create an account with an email and password, then confirm a `profiles` row is created by the database trigger. With no membership, the onboarding screen is shown.
2. Existing user: sign in with their email and password; confirm their existing session routes to the correct workspace.
3. Logout: use the dashboard logout action and confirm the welcome screen appears and protected data is no longer shown.
4. Session restoration: authenticate, restart the app, and confirm the same access route is restored.
5. Owner routing: authenticate as an active `business_memberships` owner and confirm the owner dashboard opens.
6. Restaurant staff: authenticate as an active restaurant business member and confirm the staff dashboard opens.
7. Food-court staff: authenticate as an active `stall_memberships` user and confirm the dashboard displays the assigned stall context.
8. Multiple stalls: authenticate as a user assigned to two food-court stalls; confirm the stall picker lists only those two stalls and switches context correctly.
9. No access: authenticate as a profile with no active membership; confirm the onboarding screen is shown without creating a business automatically.
10. Unauthorized stall: verify a stall without an active membership never appears in the picker and cannot be selected from the client UI.

Also verify invalid passwords, duplicate-account attempts, missing network connectivity, and signing out from a restored session show a safe, user-facing message rather than a raw Supabase error.
