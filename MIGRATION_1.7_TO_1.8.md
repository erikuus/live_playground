# Phoenix 1.7 to 1.8 Migration Guide

This document describes the migration from `phoenix-playground` (Phoenix 1.7) to `live_playground` (Phoenix 1.8), with focus on what was adopted, what was deferred, and the rationale behind these decisions.

## Migration Philosophy

This migration prioritizes **functional compatibility** over complete adoption of all Phoenix 1.8 features. The goal is a working Phoenix 1.8 app that preserves existing UI/UX while adopting critical auth improvements.

## Table of Contents

1. [What We Adopted](#what-we-adopted)
2. [What We Deferred](#what-we-deferred)
3. [Breaking Changes & Configuration](#breaking-changes--configuration)
4. [Database Schema Fixes](#database-schema-fixes)
5. [Files Changed](#files-changed)

---

## What We Adopted

### 1. Phoenix 1.8 Authentication System

Regenerated auth using:
```bash
mix phx.gen.auth Accounts User users
```

**Key adoptions:**

#### Scope Pattern
Phoenix 1.8 replaces `@current_user` with `@current_scope.user`. The scope struct enables multi-tenancy and more flexible session management.

```elixir
# Phoenix 1.7
socket.assigns.current_user

# Phoenix 1.8
socket.assigns.current_scope.user
```

**Router configuration:** Added `{LivePlaygroundWeb.UserAuth, :mount_current_scope}` to all `live_session` blocks.

#### Magic Link Authentication
Phoenix 1.8 generates passwordless auth by default. Login page now supports:
- Magic link (email-only, sends login link)
- Password (traditional email + password)

**New Accounts functions:**
- `get_user_by_magic_link_token/1`
- `login_user_by_magic_link/1`
- `deliver_login_instructions/2`

#### Sudo Mode
Sensitive operations (email/password changes) require re-authentication:

```elixir
# In settings.ex
on_mount {LivePlaygroundWeb.UserAuth, :require_sudo_mode}

# Before sensitive ops
true = Accounts.sudo_mode?(user)
```

#### Enhanced Session Tokens
Session tokens now track authentication time:

```elixir
field :authenticated_at, :utc_datetime
```

This enables time-based security policies (force re-auth after X hours).

### 2. Router Configuration

All `live_session` blocks requiring user context updated:

```elixir
live_session :recipes,
  layout: {LivePlaygroundWeb.Layouts, :recipes},
  on_mount: [
    LivePlaygroundWeb.InitLive,
    {LivePlaygroundWeb.UserAuth, :mount_current_scope}  # Added
  ] do
```

Applied to: `:recipes`, `:grids`, `:comps`, `:default`

---

## What We Deferred

### 1. DaisyUI Removal

**Phoenix 1.8 default:** Ships with DaisyUI as the design system.

**Our decision:** Removed DaisyUI entirely, kept custom Tailwind classes from Phoenix 1.7.

**Rationale:**
- Existing app has custom-designed components
- DaisyUI would require redesigning all components
- No immediate benefit to switching design systems

**How we removed DaisyUI:**
Phoenix 1.8 `mix phx.gen.auth` generates components with DaisyUI classes. We:
1. Regenerated auth with `mix phx.gen.auth`
2. Replaced all auth LiveView templates with Phoenix 1.7 HTML/Tailwind
3. Preserved all Phoenix 1.8 logic (scope, magic links, sudo mode)

**Files affected:**
- `lib/live_playground_web/live/user_live/login.ex`
- `lib/live_playground_web/live/user_live/registration.ex`
- `lib/live_playground_web/live/user_live/settings.ex`
- `lib/live_playground_web/live/user_live/confirmation.ex`

### 2. New Layout System

**Phoenix 1.8 feature:** Introduced declarative layouts with `put_layout/2` in LiveView mount.

**What it is:**
Phoenix 1.8 enables dynamic layout switching per LiveView without router configuration:

```elixir
# Phoenix 1.8 pattern
def mount(_params, _session, socket) do
  {:ok, socket |> assign(:page_title, "Home") |> put_layout(html: :app)}
end
```

This replaces router-level layout declarations:

```elixir
# Phoenix 1.7 pattern (still using)
live_session :recipes,
  layout: {LivePlaygroundWeb.Layouts, :recipes},
  on_mount: [...] do
```

**Our decision:** Kept Phoenix 1.7's router-based layout system.

**Rationale:**
- Router layouts work fine for our use case
- Migration would touch every LiveView file
- No functional benefit for this app's architecture
- Can be adopted incrementally if needed

**Future consideration:** If we need dynamic per-view layout switching (e.g., user preferences, A/B testing), implement the `put_layout/2` pattern.

### 3. Binary ID (UUID) Primary Keys

**Phoenix 1.8 default:** Generates schemas with UUID primary keys.

**Our decision:** Kept integer primary keys.

**Rationale:**
- Existing database uses integer IDs
- Migration would require database changes
- No performance issues with current system

**Configuration:** Removed `@primary_key {:id, :binary_id, autogenerate: true}` from generated schemas.

---

## Breaking Changes & Configuration

### 1. Router Hook Change

**Phoenix 1.7:**
```elixir
on_mount: [LivePlaygroundWeb.InitLive, {LivePlaygroundWeb.UserAuth, :mount_current_user}]
```

**Phoenix 1.8:**
```elixir
on_mount: [LivePlaygroundWeb.InitLive, {LivePlaygroundWeb.UserAuth, :mount_current_scope}]
```

**Why it breaks:** LiveViews expect `@current_scope.user` but without the hook, only `@current_user` would be set (if we kept 1.7 hook).

**Fix applied:** Updated all `live_session` blocks in `router.ex`.

### 2. User Access Pattern

**Phoenix 1.7:**
```elixir
@current_user
current_user = socket.assigns.current_user
```

**Phoenix 1.8:**
```elixir
@current_scope.user
current_user = socket.assigns.current_scope.user
```

**Why it changed:** Scope pattern enables multi-tenancy (e.g., organization scopes, team access).

**Migration note:** All existing code accessing `@current_user` needs updating. This is the most pervasive breaking change.

### 3. Auth Directory Renamed

**Phoenix 1.7:** `lib/live_playground_web/live/auth_live/`

**Phoenix 1.8:** `lib/live_playground_web/live/user_live/`

**Why:** Phoenix 1.8 `mix phx.gen.auth` generates `user_live/` by default.

### 4. Database Schema Configuration

**Issue:** Phoenix 1.8 generator adds binary_id config by default.

**Error if not removed:**
```
cannot load `1` as type :binary_id for field :id
```

**Fix:**
Remove from `user.ex` and `user_token.ex`:
```elixir
@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id
```

---

## Database Schema Fixes

### Integer ID Compatibility

**Files modified:**
- `lib/live_playground/accounts/user.ex`
- `lib/live_playground/accounts/user_token.ex`

**Change:**
Removed binary_id configuration to use default integer IDs matching existing database.

**Why needed:**
Phoenix 1.8 defaults to UUIDs for new apps, but our database predates this convention.

---

## Files Changed

### Regenerated (Phoenix 1.8 auth)
- `lib/live_playground/accounts.ex` - Auth context with new functions
- `lib/live_playground/accounts/user.ex` - User schema (binary_id removed)
- `lib/live_playground/accounts/user_token.ex` - Token schema with `authenticated_at`
- `lib/live_playground/accounts/scope.ex` - New scope struct
- `lib/live_playground_web/user_auth.ex` - Auth plugs with sudo mode
- `lib/live_playground_web/controllers/user_session_controller.ex` - Session management
- `lib/live_playground_web/live/user_live/login.ex` - Magic link + password login
- `lib/live_playground_web/live/user_live/registration.ex` - User registration
- `lib/live_playground_web/live/user_live/settings.ex` - Settings with sudo mode
- `lib/live_playground_web/live/user_live/confirmation.ex` - Magic link confirmation

### Modified (Configuration)
- `lib/live_playground_web/router.ex` - Added `mount_current_scope` hooks

### Deleted (Phoenix 1.7)
- `lib/live_playground_web/live/auth_live/*` - Old auth directory

---

## Future Migration Opportunities

### Adopt New Layout System
**Benefit:** Per-view layout switching without router changes.

**Implementation:**
```elixir
def mount(_params, _session, socket) do
  {:ok, put_layout(socket, html: :app)}
end
```

Remove `layout:` from router `live_session` blocks.

### Adopt DaisyUI
**Benefit:** Pre-built component library, faster UI development.

**Effort:** High - requires redesigning all existing components.

**Consideration:** Only worthwhile if adding many new components.

### Migrate to UUID Primary Keys
**Benefit:** Better distributed system support, no ID enumeration attacks.

**Effort:** Requires database migration, updating all foreign keys.

**Consideration:** Only needed if scaling to distributed architecture.

---

## Common Migration Errors

### 1. Bcrypt Not Available

**Error:**
```
function Bcrypt.verify_pass/2 is undefined (module Bcrypt is not available)
```

**Cause:** Dependency compilation issue after regenerating auth.

**Fix:**
```bash
mix deps.clean bcrypt_elixir
mix deps.get
mix deps.compile bcrypt_elixir
mix compile --force
```

### 2. Port Already in Use

**Error:**
```
[error] Failed to start Ranch listener ... eaddrinuse
```

**Fix:**
```bash
lsof -ti:4000 | xargs kill -9
```

### 3. @current_scope Not Available

**Error:** `@current_scope` is `nil` in LiveViews.

**Cause:** Missing `mount_current_scope` hook in router.

**Fix:** Add to `live_session`:
```elixir
on_mount: [..., {LivePlaygroundWeb.UserAuth, :mount_current_scope}]
```

### 4. Binary ID Type Error

**Error:**
```
cannot load `1` as type :binary_id for field :id
```

**Cause:** Generated schemas have UUID config but database uses integers.

**Fix:** Remove from schemas:
```elixir
@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id
```

---

## Testing Checklist

After migration, verify:

- [ ] Registration creates user and sends magic link
- [ ] Magic link login works
- [ ] Password login works (if user has password)
- [ ] Settings page requires sudo mode
- [ ] Email change sends confirmation link
- [ ] Password change works
- [ ] Logout clears session
- [ ] Protected routes redirect to login
- [ ] `@current_scope.user` available in all LiveViews
- [ ] No DaisyUI classes in rendered HTML
