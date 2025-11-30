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

**Phoenix 1.8 change:** Layouts shifted from implicit nested templates to explicit function components.

**The Change:**

Phoenix 1.7:
```elixir
# router.ex - Layout auto-applied to all routes
live_session :app,
  layout: {AppWeb.Layouts, :app},
  on_mount: [...] do
  live "/posts", PostLive.Index
end

# lib/app_web/components/layouts/root.html.heex (static wrapper)
# lib/app_web/components/layouts/app.html.heex (dynamic wrapper - auto-rendered)

# post_live/index.ex
def render(assigns) do
  ~H"""
  <p>Post content</p>
  """
end
```

Phoenix 1.8:
```elixir
# layouts.ex - App layout as function component
defmodule AppWeb.Layouts do
  use AppWeb, :html

  slot :breadcrumb, required: false  # Optional slots
  attr :flash, :map, required: true

  def app(assigns) do
    ~H"""
    <main class="px-4 py-20">
      <div :if={@breadcrumb != []} class="breadcrumbs">
        <li :for={item <- @breadcrumb}>{render_slot(item)}</li>
      </div>
      {render_slot(@inner_block)}  # Your content here
    </main>
    """
  end
end

# post_live/index.ex - Explicit layout wrapper
def render(assigns) do
  ~H"""
  <Layouts.app flash={@flash}>
    <:breadcrumb><.link navigate={~p"/posts"}>Posts</.link></:breadcrumb>
    <p>Post content</p>
  </Layouts.app>
  """
end
```

**Key differences:**

1. **Explicit vs Implicit:**
```elixir
# Phoenix 1.7 - Layout auto-applied
def render(assigns), do: ~H"<p>Content</p>"

# Phoenix 1.8 - Layout explicitly wrapped
def render(assigns), do: ~H"<Layouts.app flash={@flash}><p>Content</p></Layouts.app>"
```

2. **Multiple Layouts:**
```elixir
# Phoenix 1.7 - Requires router config + conditional logic
live_session :app, layout: {Layouts, :app}
live_session :admin, layout: {Layouts, :admin}

# Phoenix 1.8 - Direct component call
def render(assigns), do: ~H"<Layouts.admin><p>Admin</p></Layouts.admin>"
def render(assigns), do: ~H"<Layouts.app><p>App</p></Layouts.app>"
```

3. **Dynamic Content via Slots:**
```elixir
# Phoenix 1.8 - Pass optional content to layout
<Layouts.app flash={@flash}>
  <:breadcrumb><.link navigate={~p"/"}>Home</.link></:breadcrumb>
  <:breadcrumb><.link navigate={~p"/posts"}>Posts</.link></:breadcrumb>
  <p>Content</p>
</Layouts.app>
```

**Our decision:** Kept Phoenix 1.7's router-based layout system.

**Rationale:**
- Works fine for single-layout-per-section apps
- Migration requires touching every LiveView file
- No immediate functional benefit
- Can adopt incrementally when needed

**When to migrate:**
- Need per-view layout switching
- Want dynamic layouts (user preferences, A/B testing)
- Adding many specialized layouts (admin, cart, checkout)

### 3. Binary ID (UUID) Primary Keys

**Phoenix 1.8 default:** Generates schemas with UUID primary keys.

**Our decision:** Kept integer primary keys.

**Rationale:**
- Existing database uses integer IDs
- Migration would require database changes
- No performance issues with current system

**Configuration:** Removed `@primary_key {:id, :binary_id, autogenerate: true}` from generated schemas.

### 4. Timex Dependency

**Phoenix 1.7:** Used Timex library for date/time formatting.

**Our decision:** Removed Timex, replaced with native Elixir functions.

**Rationale:**
- Elixir 1.14+ has excellent DateTime/Calendar support
- Reduces dependency count
- Timex was only used for relative time formatting (`from_now/1`)
- Simple to replace with `DateTime.diff/3`

**Replacement pattern:**

Phoenix 1.7:
```elixir
# mix.exs
{:timex, "~> 3.0"}

# component
Timex.from_now(user.inserted_at)  # "2 hours ago"
```

Phoenix 1.8:
```elixir
# No dependency needed

# component
defp format_user_since(user) do
  inserted_at = normalize_to_datetime(user.inserted_at)
  diff = DateTime.diff(DateTime.utc_now(), inserted_at, :second)

  cond do
    diff < 60 -> "just now"
    diff < 3600 -> "#{div(diff, 60)} minutes ago"
    diff < 86400 -> "#{div(diff, 3600)} hours ago"
    diff < 604800 -> "#{div(diff, 86400)} days ago"
    true -> Calendar.strftime(inserted_at, "%B %d, %Y")
  end
end
```

**Files affected:**
- `lib/live_playground_web/components/more_components.ex`
- All recipe/grid LiveViews using timestamp display

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

These features were deferred but can be adopted incrementally:

### 1. Adopt New Layout System
**Benefit:** Per-view layout switching without router changes.

**Effort:** Medium - update mount/3 in all LiveViews.

**Implementation:**
```elixir
def mount(_params, _session, socket) do
  {:ok, put_layout(socket, html: :app)}
end
```

Remove `layout:` from router `live_session` blocks.

**When to adopt:** If you need dynamic layout switching based on user preferences or view-specific requirements.

### 2. Adopt DaisyUI
**Benefit:** Pre-built component library, faster UI development for new features.

**Effort:** High - requires redesigning all existing components.

**Consideration:** Only worthwhile if:
- Adding many new components
- Want consistent design system
- Team prefers utility-first + component library approach

**Alternative:** Continue with custom Tailwind (current approach works well).

### 3. Migrate to UUID Primary Keys
**Benefit:** Better distributed system support, no ID enumeration attacks.

**Effort:** High - requires database migration, updating all foreign keys.

**Consideration:** Only needed if:
- Scaling to distributed/multi-region architecture
- Security requires non-sequential IDs
- Merging databases from multiple sources

**Current approach:** Integer IDs work well for single-database applications.

### 4. Re-adopt Timex
**Benefit:** More sophisticated date/time formatting and timezone handling.

**Effort:** Low - add dependency, replace custom functions.

**Consideration:** Only needed if:
- Require complex timezone conversions
- Need advanced date arithmetic
- Want internationalized date formatting

**Current approach:** Native DateTime/Calendar sufficient for relative time display.

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
