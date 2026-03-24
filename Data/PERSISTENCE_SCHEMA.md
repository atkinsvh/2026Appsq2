# VowPlanner Persistence Schema (v2)

This app uses a local JSON + CloudKit hybrid model.

## Local schema versioning

- Schema metadata file: `schema_metadata.json`
- Current schema version: `2`
- Migration entrypoint: `DataStore.migrateToLatestSchema()`

## Migration policy

- Additive and normalization-first migrations.
- No destructive field removals in local JSON migrations.
- Preserve record identity/timestamps when normalizing data.

## v2 normalization rules

Applied to existing local files when upgrading from v1:

- `guests.json`
  - Normalize `invitationCode` to uppercase 6-char alphanumeric code.
  - Clamp `partySize` to a minimum of `1`.
- `invitation_codes.json`
  - Normalize `code` format.
  - Clamp `partySize` to a minimum of `1`.
  - Preserve existing `id`, `createdAt`, RSVP-related fields.
- `all_guest_rsvps.json`
  - Normalize `invitationCode` format.
  - Clamp `partySize` to a minimum of `1`.
  - Preserve `submittedAt` timestamp.

## Source of truth

- Domain models: `Shared/Models.swift`
- Local storage orchestration: `Services/DataStore.swift`
- App boot migration trigger: `App/AppState.swift`
- Cloud sync contract mapping: `Services/CloudKitSyncService.swift`
