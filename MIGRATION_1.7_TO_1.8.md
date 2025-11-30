# Phoenix 1.7 to 1.8 Migration Guide

This document describes all changes made when migrating `phoenix-playground` (Phoenix 1.7) to `live_playground` (Phoenix 1.8).

## Table of Contents

1. [Authentication System](#authentication-system)
2. [Database Schema Changes](#database-schema-changes)
3. [Router Configuration](#router-configuration)
4. [Auth UI Styling](#auth-ui-styling)
5. [Dependency Issues](#dependency-issues)
6. [Key Differences Summary](#key-differences-summary)

---

## Authentication System

### Regenerating Auth

Phoenix 1.8 introduces a new authentication system with significant changes. We regenerated auth using:

```bash
mix phx.gen.auth Accounts User users
```

### New Phoenix 1.8 Auth Patterns Adopted

#### 1. Scope Pattern (replaces current_user)

**Phoenix 1.7:**
```elixir
# Assigns @current_user directly
socket.assigns.current_user
```

**Phoenix 1.8:**
```elixir
# Uses @current_scope which wraps the user
socket.assigns.current_scope.user

# The scope pattern supports multi-tenancy
defstruct [:user]
```

#### 2. Magic Link Authentication (New in 1.8)

Phoenix 1.8 generates passwordless login by default. The login page now has two forms:
- Magic link form (email only, sends login link)
- Password form (traditional email + password)

**New files:**
- `lib/live_playground_web/live/user_live/login.ex` - Handles both magic link and password login
- `lib/live_playground_web/live/user_live/confirmation.ex` - Magic link confirmation page

**New Accounts functions:**
```elixir
Accounts.get_user_by_magic_link_token(token)
Accounts.login_user_by_magic_link(token)
Accounts.deliver_login_instructions(user, url_fn)
```

#### 3. Sudo Mode for Sensitive Operations

**Phoenix 1.8 Settings:**
```elixir
# lib/live_playground_web/live/user_live/settings.ex
on_mount {LivePlaygroundWeb.UserAuth, :require_sudo_mode}

# Check sudo mode before sensitive operations
true = Accounts.sudo_mode?(user)
```

This requires re-authentication before changing email or password.

#### 4. Session Token with Authentication Timestamp

**Phoenix 1.8 UserToken:**
```elixir
# Tracks when user authenticated
field :authenticated_at, :utc_datetime

# Session token includes authentication time
def build_session_token(user) do
  token = :crypto.strong_rand_bytes(@rand_size)
  dt = user.authenticated_at || DateTime.utc_now(:second)
  {token, %UserToken{token: token, context: "session", user_id: user.id, authenticated_at: dt}}
end
```

---

## Database Schema Changes

### ID Type Mismatch Fix

The Phoenix 1.8 generator defaults to `binary_id` (UUID), but our existing database uses integer IDs.

**Removed from `lib/live_playground/accounts/user.ex`:**
```elixir
# These lines were removed to use integer IDs
@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id
```

**Removed from `lib/live_playground/accounts/user_token.ex`:**
```elixir
# Same removal
@primary_key {:id, :binary_id, autogenerate: true}
@foreign_key_type :binary_id
```

**Error this fixed:**
```
cannot load `1` as type :binary_id for field :id
```

---

## Router Configuration

### Adding mount_current_scope Hook

Phoenix 1.8 uses `mount_current_scope` instead of `mount_current_user`. This must be added to all `live_session` blocks that need user context.

**File:** `lib/live_playground_web/router.ex`

**Before (Phoenix 1.7 pattern):**
```elixir
live_session :recipes,
  layout: {LivePlaygroundWeb.Layouts, :recipes},
  on_mount: [LivePlaygroundWeb.InitLive] do
```

**After (Phoenix 1.8 pattern):**
```elixir
live_session :recipes,
  layout: {LivePlaygroundWeb.Layouts, :recipes},
  on_mount: [LivePlaygroundWeb.InitLive, {LivePlaygroundWeb.UserAuth, :mount_current_scope}] do
```

**Applied to all live_sessions:**
- `:recipes`
- `:steps`
- `:comps`
- `:default` (if present)

---

## Auth UI Styling

### Preserving 1.7 Visual Design

We kept the Phoenix 1.7 `auth_live/` styling (custom Tailwind design) while adopting 1.8's new auth logic.

### Files Modified

| 1.7 Source | 1.8 Target | Changes |
|------------|------------|---------|
| `auth_live/login.ex` | `user_live/login.ex` | Styling only |
| `auth_live/registration.ex` | `user_live/registration.ex` | Styling only |
| `auth_live/settings.ex` | `user_live/settings.ex` | Styling only |
| `auth_live/confirmation.ex` | `user_live/confirmation.ex` | Styling only |

### Styling Pattern Applied

**Outer wrapper (all auth pages):**
```heex
<div class="bg-zinc-100 min-h-screen flex flex-col justify-center sm:px-6 lg:px-8">
  <div class="sm:mx-auto sm:w-full sm:max-w-md">
    <h2 class="text-center text-2xl font-bold text-zinc-900">
      Page Title
    </h2>
    <p class="mt-2 text-center text-sm text-zinc-600">
      Subtitle text
    </p>
  </div>

  <div class="mt-10 mb-20 sm:mx-auto sm:w-full sm:max-w-[480px]">
    <div class="bg-white px-6 py-6 shadow-sm sm:rounded-lg sm:px-12">
      <!-- Form content -->
    </div>
  </div>
</div>
```

**Settings page (grid layout):**
```heex
<div class="bg-zinc-100 min-h-screen flex flex-col justify-center py-12 sm:px-6 lg:px-8">
  <div class="sm:mx-auto sm:w-full sm:max-w-4xl">
    <div class="md:grid md:grid-cols-3 md:gap-6">
      <!-- Sidebar (1 col) -->
      <div class="mx-6 sm:mx-0 md:col-span-1">
        <h2>Account Settings</h2>
        <p>Description</p>
      </div>

      <!-- Forms (2 cols) -->
      <div class="mt-5 md:mt-0 md:col-span-2 space-y-6">
        <div class="bg-white px-6 py-6 shadow-sm sm:rounded-lg">
          <!-- Email form -->
        </div>
        <div class="bg-white px-6 py-6 shadow-sm sm:rounded-lg">
          <!-- Password form -->
        </div>
      </div>
    </div>
  </div>
</div>
```

### Important: Keep Phoenix 1.8 Logic Intact

When applying 1.7 styling, we preserved all 1.8-specific code:

```elixir
# Keep these Phoenix 1.8 patterns:
@current_scope              # Not @current_user
Accounts.sudo_mode?(user)   # Sudo mode checks
phx-trigger-action          # Form submission pattern
```

### Slot Limitation with Conditionals

Phoenix LiveView slots cannot be inside EEx conditionals.

**Wrong (causes compilation error):**
```heex
<.simple_form for={@form}>
  <%= if @condition do %>
    <:actions>
      <.button>Option A</.button>
    </:actions>
  <% else %>
    <:actions>
      <.button>Option B</.button>
    </:actions>
  <% end %>
</.simple_form>
```

**Correct (use separate forms with :if):**
```heex
<.simple_form :if={@condition} for={@form}>
  <:actions>
    <.button>Option A</.button>
  </:actions>
</.simple_form>

<.simple_form :if={!@condition} for={@form}>
  <:actions>
    <.button>Option B</.button>
  </:actions>
</.simple_form>
```

---

## Dependency Issues

### Bcrypt Compilation Error

**Error:**
```
function Bcrypt.verify_pass/2 is undefined (module Bcrypt is not available)
```

**Fix:**
```bash
mix deps.clean bcrypt_elixir
mix deps.get
mix deps.compile bcrypt_elixir
mix compile --force
```

### Port Already in Use

**Error:**
```
[error] Failed to start Ranch listener ... eaddrinuse
```

**Fix:**
```bash
lsof -ti:4000 | xargs kill -9
```

---

## Key Differences Summary

| Aspect | Phoenix 1.7 | Phoenix 1.8 |
|--------|-------------|-------------|
| User access | `@current_user` | `@current_scope.user` |
| Router hook | `mount_current_user` | `mount_current_scope` |
| Login method | Password only | Magic link + Password |
| Sensitive ops | Direct access | Sudo mode required |
| Session token | Basic | Includes `authenticated_at` |
| Auth directory | `auth_live/` | `user_live/` |
| ID default | Integer | binary_id (UUID) |

### What We Adopted from 1.8

1. **Scope pattern** - For multi-tenancy support
2. **Magic link auth** - Passwordless login option
3. **Sudo mode** - Re-auth for sensitive operations
4. **New token structure** - With authentication timestamp
5. **Updated Accounts context** - New functions for magic links

### What We Kept from 1.7

1. **Visual styling** - Gray background, white form cards
2. **Settings grid layout** - Sidebar + form columns
3. **Button styling** - Full-width buttons with arrows
4. **Info boxes** - Local mail adapter notice, tips
5. **Integer IDs** - Existing database compatibility

---

## Files Changed

### New/Regenerated (Phoenix 1.8)
- `lib/live_playground/accounts.ex`
- `lib/live_playground/accounts/user.ex`
- `lib/live_playground/accounts/user_token.ex`
- `lib/live_playground/accounts/scope.ex`
- `lib/live_playground_web/user_auth.ex`
- `lib/live_playground_web/controllers/user_session_controller.ex`
- `lib/live_playground_web/live/user_live/login.ex`
- `lib/live_playground_web/live/user_live/registration.ex`
- `lib/live_playground_web/live/user_live/settings.ex`
- `lib/live_playground_web/live/user_live/confirmation.ex`

### Modified (Styling + Hooks)
- `lib/live_playground_web/router.ex` - Added `mount_current_scope` hooks

### Schema Fixes
- `lib/live_playground/accounts/user.ex` - Removed binary_id config
- `lib/live_playground/accounts/user_token.ex` - Removed binary_id config

---

## Testing Checklist

- [ ] Registration works (creates user, sends magic link)
- [ ] Magic link login works
- [ ] Password login works
- [ ] Settings page accessible (requires sudo mode)
- [ ] Email change sends confirmation
- [ ] Password change works
- [ ] Logout works
- [ ] Protected routes redirect to login
