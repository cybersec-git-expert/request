# Changelog
All notable user-impacting changes to this project will be documented here.

Format: YYYY-MM-DD – Type(scope): Description
Types: Added, Changed, Fixed, Removed, Security, Deprecated, Docs

## Unreleased
- Placeholder for upcoming entries. Move to a dated section when released.

## 2025-08-19
### Added
- Added `DOCS_INDEX.md` to organize and prioritize documentation work.
- Comprehensive notification system (multi-domain notifications: requests, responses, rides, messaging, business interest) with driver subscription management.
- Vehicle auto-activation Cloud Functions: auto-enable new vehicles for countries & setup for new countries.
- Admin permission enhancements: `smsConfiguration`, `countryVehicleTypeManagement`.
- SMS Configuration System: multi-provider (Twilio, AWS SNS, Vonage, Local) country-specific OTP delivery with cost optimization (50–80% savings).

### Changed
- Vehicle admin UI grouping: Vehicle Types now aligned with Vehicle Management section.
- Refactored country vehicles collection to use `enabledVehicles` field for Flutter compatibility.

### Fixed
- Vehicle system structural issues: field name inconsistencies + missing Firestore index for `vehicle_types`.
- Data mismatch (IDs) investigation groundwork for vehicle toggle persistence (partially resolved; remaining persistence edge cases under review).

### Docs
- Created `VEHICLE_SYSTEM_STATUS.md` summarizing vehicle module health & expected app behavior.
- Created/Updated notification system deep-dive (`COMPREHENSIVE_NOTIFICATION_SYSTEM.md`).
- Added detailed SMS system & authentication documentation (`SMS_API_CONFIGURATION_DOCUMENTATION.md`).
- Added fixes summary (`FIXES_SUMMARY.md`) feeding initial changelog entries.

### Internal (Non-User Facing)
- Introduced audit logging for vehicle activation events.
- Added backlog for documentation consolidation (see `DOCS_INDEX.md`).

## (Historical – Pre-Changelog)
- Earlier migration phases, subscription system, centralized country filtering, contact verification, and promo code systems existed prior to formal changelog; details in respective implementation docs. These can be retroactively imported if needed.

---
Guidelines for future entries:
1. Append under "Unreleased" during development.
2. On release (deployment/tag), move entries to a new dated heading.
3. Keep scope concise (feature or module name)
4. Prefer active voice; note breaking changes clearly.
