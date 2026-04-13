# Profile API Contract

## Scope

This document defines the Phase19 profile HTTP contract.

Base path:

```text
/api/v1/profile
```

Compatibility note:

- Current service temporarily keeps legacy `/v1/profile/*` routes for local migration.
- New callers should use `/api/v1/profile/*`.

Authentication:

- All endpoints require `Authorization: Bearer <access_token>`.

Profile semantics:

- Profile data is server authoritative.
- Client `PlayerProfileState` is only a cache copy.
- `profile_version` increments on profile data change.
- `owned_asset_revision` increments only when ownership changes.

Common error response:

```json
{
  "ok": false,
  "error_code": "PROFILE_NOT_FOUND",
  "message": "Profile does not exist"
}
```

## GET /api/v1/profile/me

Fetch current authoritative profile and owned assets.

Success response:

```json
{
  "ok": true,
  "profile_id": "profile_54f43da2",
  "account_id": "account_9b4d4fd1",
  "nickname": "PlayerA",
  "default_character_id": "character_default",
  "default_character_skin_id": "skin_default",
  "default_bubble_style_id": "bubble_style_default",
  "default_bubble_skin_id": "bubble_skin_default",
  "preferred_mode_id": "team_score",
  "preferred_map_id": "map_01",
  "preferred_rule_set_id": "rule_team_score",
  "owned_character_ids": ["character_default", "character_knight"],
  "owned_character_skin_ids": ["skin_default"],
  "owned_bubble_style_ids": ["bubble_style_default"],
  "owned_bubble_skin_ids": ["bubble_skin_default"],
  "profile_version": 5,
  "owned_asset_revision": 12
}
```

Possible error codes:

- `AUTH_ACCESS_TOKEN_INVALID`
- `AUTH_ACCESS_TOKEN_EXPIRED`
- `PROFILE_NOT_FOUND`
- `INTERNAL_ERROR`

## PATCH /api/v1/profile/me

Update mutable profile fields.

Request JSON:

```json
{
  "nickname": "PlayerA",
  "preferred_mode_id": "team_score",
  "preferred_map_id": "map_01",
  "preferred_rule_set_id": "rule_team_score"
}
```

Rules:

- `nickname` must be non-empty after trim.
- Omitted fields keep previous values.
- On success, `profile_version` increments.
- Ownership revision does not change unless ownership changes elsewhere.

Success response:

```json
{
  "ok": true,
  "profile_id": "profile_54f43da2",
  "profile_version": 6,
  "owned_asset_revision": 12
}
```

Possible error codes:

- `AUTH_ACCESS_TOKEN_INVALID`
- `PROFILE_NOT_FOUND`
- `PROFILE_NICKNAME_INVALID`
- `INTERNAL_ERROR`

## PATCH /api/v1/profile/me/loadout

Update default loadout.

Request JSON:

```json
{
  "default_character_id": "character_default",
  "default_character_skin_id": "skin_default",
  "default_bubble_style_id": "bubble_style_default",
  "default_bubble_skin_id": "bubble_skin_default"
}
```

Rules:

- Each selected asset must be owned by current profile.
- On success, `profile_version` increments.
- `owned_asset_revision` remains unchanged.

Success response:

```json
{
  "ok": true,
  "profile_id": "profile_54f43da2",
  "default_character_id": "character_default",
  "default_character_skin_id": "skin_default",
  "default_bubble_style_id": "bubble_style_default",
  "default_bubble_skin_id": "bubble_skin_default",
  "profile_version": 7,
  "owned_asset_revision": 12
}
```

Possible error codes:

- `AUTH_ACCESS_TOKEN_INVALID`
- `PROFILE_NOT_FOUND`
- `PROFILE_LOADOUT_NOT_OWNED`
- `CONTENT_ASSET_INVALID`
- `INTERNAL_ERROR`
