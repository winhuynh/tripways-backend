# User Authentication Design

## Goal

Add a production-minded email and password account lifecycle to Tripways. A user can register,
verify their email, sign in, sign out, recover or change their password, change their email, update
their display name, and delete their account. Anonymous and guest authentication are excluded.

## Scope

### Included

- Email and password registration with a required display name.
- Email confirmation through Supabase Auth.
- Sign-in and sign-out through Supabase Auth.
- Password recovery and authenticated password change.
- Authenticated email change with confirmation.
- Self-service profile read and display-name update.
- Hard account deletion while no retained domain data references users.
- Revocation of other sessions after password or email security changes while preserving the
  current session.
- Rate limiting, stable error codes, structured logs, RLS, and least-privilege grants.

### Excluded

- Anonymous or guest accounts.
- Google, Apple, or other OAuth providers.
- MFA, avatars, roles, admin account management, and per-device session controls.
- Soft deletion or retention workflows before a domain requirement justifies them.

## Architecture

Supabase Auth owns identity, credentials, verification emails, recovery sessions, and access
tokens. `public.users` owns the minimal application profile. Edge Functions are thin authenticated
transports for profile and privileged account-security operations. PostgreSQL functions own profile
validation and mutation invariants.

```text
Supabase Auth
├── email/password signup and verification
├── sign-in and sign-out
├── recovery email and session
└── credential and session management

public.users
├── user_id -> auth.users.id
├── display_name
├── account_status
├── created_at
└── updated_at

supabase/functions/v1/user
├── profile
├── account-security
└── delete-account
```

Email remains authoritative in `auth.users` and is not duplicated in `public.users`. The signup
request passes `display_name` as user metadata only as bootstrap input. Authorization must never use
user metadata. An Auth trigger validates the bootstrap value and creates the application profile.

The client never supplies an internal user UUID for self-service operations. Edge derives identity
from the verified JWT and database functions use `auth.uid()` or an Edge-injected UUID obtained
from that JWT.

## Data Model

`public.users` contains:

- `user_id uuid primary key references auth.users(id) on delete cascade`
- `display_name text not null`
- `account_status text not null default 'active'`
- `created_at timestamptz not null default now()`
- `updated_at timestamptz not null default now()`

`account_status` initially accepts only `active` and exists to make disabled-state enforcement
explicit without adding role or entitlement concepts. No public user ID, avatar, locale, timezone,
or settings columns are added until an active consumer requires them.

RLS is enabled before grants. Authenticated users may read only their own row. Direct client writes
are not granted; display-name mutation goes through the authenticated Edge and RPC boundary.

## Operations

### Registration

The client calls Supabase Auth signup with a normalized email, an opaque password, and
`display_name` metadata. The Auth bootstrap trigger validates and normalizes the display name and
inserts `public.users`. Email confirmation is required. Anonymous signup is disabled in Supabase
configuration.

Profile creation is idempotent for Auth retry/update behavior. Invalid bootstrap metadata rejects
profile creation with a stable internal error and does not create a partial application profile.

### Sign-in and Sign-out

The client uses Supabase Auth for email/password sign-in and sign-out. The backend does not wrap
these native operations because no additional invariant currently requires it. A signed-in account
must have an active profile before domain APIs accept it.

### Profile Read and Update

`GET /user/profile` authenticates the JWT and returns the minimal profile envelope. `PATCH
/user/profile` accepts only `display_name`. PostgreSQL performs final validation and updates
`updated_at` transactionally.

Display names are trimmed at the boundary and must contain 2 to 80 Unicode characters. Empty or
overlong values are rejected. The response does not expose the internal user UUID.

### Authenticated Password Change

The account-security command accepts `current_password` and `new_password`. It reauthenticates the
current user, updates the password through Supabase Auth, revokes all other sessions, and preserves
the current session. Password strings are opaque and are never trimmed, logged, or returned.

### Password Recovery

Supabase Auth sends the recovery email and establishes the recovery session. The new password is
submitted through the authenticated account-security boundary. After a successful update, all
other sessions are revoked while the current recovery session remains valid.

### Email Change

The account-security command accepts `current_password` and normalized `new_email`. It
reauthenticates the caller before requesting the Supabase Auth email change. Supabase confirmation
controls when the new address becomes authoritative. Once the security change is completed, other
sessions are revoked and the current session is retained.

### Account Deletion

The delete-account command requires the current password and reauthentication. It deletes the Auth
user through a server-only client. `ON DELETE CASCADE` removes `public.users`. The response is
normalized so internal Auth and database details are not exposed. Hard deletion is adequate until
Tripways stores domain records that require legal retention or attribution.

## Validation and Errors

- Email is trimmed, structurally validated, and limited to 254 Unicode characters.
- New passwords contain 8 to 72 Unicode characters, including at least one lowercase letter, one
  uppercase letter, and one digit.
- Passwords are never trimmed or normalized.
- Display names are trimmed and contain 2 to 80 Unicode characters.
- Trust-boundary errors use stable `ERR_*` codes.
- Raw PostgreSQL, Supabase Auth, tokens, passwords, and full email addresses never appear in logs or
  client error details.

Supabase Auth remains authoritative for credential validity and provider-specific constraints.
Edge maps structured Auth failures to stable application errors.

## Security

- Anonymous sign-in is disabled.
- Email confirmation and secure password change are enabled.
- Service-role credentials remain server-side.
- Edge verifies the JWT using Supabase Auth rather than trusting decoded claims alone.
- User metadata is bootstrap input only and is never used for authorization.
- Profile RLS is self-read with explicit least-privilege grants.
- Sensitive commands are rate-limited by authenticated user and request IP.
- Logs contain request ID, action, status, processed timestamp, internal user ID, and error code,
  but no secret, token, password, or full PII.

## Source Layout

```text
supabase/sql_src/schema/public/users.sql
supabase/sql_src/functions/user/handle_new_auth_user.sql
supabase/sql_src/functions/user/rpc_get_user_profile.sql
supabase/sql_src/functions/user/update_user_profile.sql
supabase/sql_src/triggers/user/trg_handle_new_auth_user.sql
supabase/functions/_shared/auth.ts
supabase/functions/v1/user/profile/
supabase/functions/v1/user/account-security/
supabase/functions/v1/user/delete-account/
```

Migration files are created through the Supabase CLI and kept consistent with maintainable
`sql_src` sources. Each table and PostgreSQL function remains in its own source file. Profile reads
use an exposed invoker RPC. Profile mutation uses the unexposed
`private.update_user_profile(p_user_id, p_input)` security-definer function; only Edge calls it with
the user ID obtained from a verified JWT.

## Testing and Verification

Development follows test-first behavior changes. Each production behavior is added only after its
focused test has failed for the intended reason.

- SQL contract tests cover the table, constraints, trigger, RLS, grants, and disabled anonymous
  authentication.
- Database integration tests create an Auth user, verify profile bootstrap, enforce self-only reads,
  update a display name, and confirm cascade deletion.
- Parser tests cover email, password, display-name validation, and exact password preservation.
- Account-security service tests cover failed reauthentication, password/recovery session
  revocation, verified email change, and deletion ordering.
- Edge tests cover methods, authentication, stable envelopes, rate limiting, and error mapping.
- Local verification rebuilds the database from migrations and seed before running SQL and security
  queries.
- Formatting, Deno format/check/lint/tests, SQL/security checks, and `pnpm verify` run before the
  feature is considered complete.

## Completion Criteria

- A confirmed email/password user receives exactly one valid `public.users` profile.
- Guest and anonymous signup are unavailable.
- Users can sign in/out, recover or change their password, change their email, update their display
  name, and delete their account.
- Password and email security changes preserve the current session and revoke all others.
- Client requests cannot operate on another user by supplying an identifier.
- Every exposed table has RLS and explicit least-privilege grants.
- No sensitive value appears in responses or logs.
- All relevant local verification commands pass from a migration-rebuilt database.
