# Permissions Matrix
Describes system roles and their capabilities across domains (admin panel + mobile). Last Updated: 2025-08-19

## Legend
| Symbol | Meaning |
|--------|---------|
| ✅ | Full access |
| 🟡 | Limited / own items / requires approval |
| 🔒 | No access |
| A→ | Action requires approval by higher role |
| Auto | Auto-approved (no workflow) |

## Core Roles
| Role | Context |
|------|---------|
| super_admin | Global platform controller (all countries) |
| country_admin | Admin limited to assigned country |
| business_owner | Business creation & management (post verification) |
| driver | Ride services (post verification) |
| delivery_partner | Delivery services (post verification) |
| user | General end user |

## High-Level Capability Table
| Capability Domain | super_admin | country_admin | business_owner | driver | delivery_partner | user |
|-------------------|------------|---------------|----------------|--------|------------------|------|
| Country Data Visibility | ✅ (all) | ✅ (own country) | 🟡 (public + own business) | 🟡 (public + own rides) | 🟡 (public + own deliveries) | 🟡 (public) |
| Admin User Management | ✅ | 🔒 | 🔒 | 🔒 | 🔒 | 🔒 |
| Role / Permission Assignment | ✅ | 🔒 | 🔒 | 🔒 | 🔒 | 🔒 |
| Content/Page Management (Centralized) | ✅ | A→ (needs super approval) | 🔒 | 🔒 | 🔒 | 🔒 |
| Content/Page Management (Country) | ✅ | ✅ (own country) | 🔒 | 🔒 | 🔒 | 🔒 |
| Vehicle Type Global Management | ✅ | 🔒 | 🔒 | 🔒 | 🔒 | 🔒 |
| Country Vehicle Enable/Disable | ✅ | ✅ (own country) | 🔒 | 🔒 | 🔒 | 🔒 |
| Auto Vehicle Activation (System) | Auto | Auto | Auto | Auto | Auto | Auto |
| SMS Provider Configuration | ✅ | ✅ (own country if permission) | 🔒 | 🔒 | 🔒 | 🔒 |
| Send OTP (Auth) | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Request Creation | ✅ | ✅ | 🟡 (business related) | ✅ (ride) | ✅ (delivery) | ✅ |
| Request Editing | ✅ | ✅ (own country moderation) | 🟡 (own listings) | 🟡 (own ride requests) | 🟡 (own delivery requests) | 🟡 (own requests) |
| Approve Requests (Admin Workflow) | ✅ | ✅ (own country) | 🔒 | 🔒 | 🔒 | 🔒 |
| Respond to Requests | ✅ | ✅ | ✅ (business offers) | ✅ (ride offers) | ✅ (delivery offers) | ✅ (general) |
| Accept/Reject Responses | ✅ | ✅ (moderation) | 🟡 (on own requests) | 🟡 (own requests) | 🟡 (own requests) | 🟡 (own requests) |
| Ride Notifications Subscription Mgmt | ✅ | ✅ | 🔒 | ✅ (self) | 🔒 | 🔒 |
| Notification Sending (System Trigger) | System | System | System (business interest) | System (ride events) | System (delivery events) | System |
| Business Registration | ✅ | ✅ | ✅ (self) | 🔒 | 🔒 | 🔒 |
| Business Verification Approval | ✅ | ✅ (own country) | 🔒 | 🔒 | 🔒 | 🔒 |
| Business Profile Editing | ✅ | 🟡 (enforce country) | ✅ (own) | 🔒 | 🔒 | 🔒 |
| Subscription Plan Management | ✅ | 🔒 | 🔒 | 🔒 | 🔒 | 🔒 |
| Promo Code Management | ✅ | 🟡 (if scoped permission) | 🔒 | 🔒 | 🔒 | 🔒 |
| Apply Promo Codes | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Pricing / Click Tracking View | ✅ | ✅ (own country subset) | ✅ (own metrics) | 🔒 | 🔒 | 🔒 |
| Contact Verification (Business) | ✅ override | ✅ override | ✅ (self) | 🔒 | 🔒 | 🔒 |
| Driver Verification Approval | ✅ | ✅ (own country) | 🔒 | 🔒 | 🔒 | 🔒 |
| Delivery Partner Verification Approval | ✅ | ✅ (own country) | 🔒 | 🔒 | 🔒 | 🔒 |
| File / Document Review | ✅ | ✅ (own country) | 🔒 | 🔒 | 🔒 | 🔒 |
| System Configuration (Global) | ✅ | 🔒 | 🔒 | 🔒 | 🔒 | 🔒 |
| Country-Level Configuration | ✅ | ✅ (own country) | 🔒 | 🔒 | 🔒 | 🔒 |
| View Analytics (Global) | ✅ | 🔒 | 🔒 | 🔒 | 🔒 | 🔒 |
| View Analytics (Country) | ✅ | ✅ (own country) | 🔒 | 🔒 | 🔒 | 🔒 |
| View Personal Analytics | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

## Admin Panel Permission Flags (Current / Planned)
| Flag | Description | Used By | Notes |
|------|-------------|---------|-------|
| contentManagement | Access to content/pages module | super_admin, country_admin | Country admin limited to own country, centralized needs approval |
| adminUsersManagement | Create/update admin users | super_admin | Not granted to country_admin by default |
| smsConfiguration | Configure SMS providers | super_admin, country_admin (opt-in) | Per-country provider setup |
| countryVehicleTypeManagement | Enable/disable vehicles per country | super_admin, country_admin | Works with auto-activation fallback |
| vehicleTypesGlobal | Manage global vehicle type definitions | super_admin | Add/edit global list |
| promoCodeManagement | Manage promo codes | super_admin, (optional) country_admin | Scoped to country for country_admin |
| subscriptionManagement | Manage subscription plans/pricing | super_admin | Pricing strategy |
| notificationsAdmin | View system notification logs | super_admin | For audits/debug |
| systemConfig | Global environment/settings | super_admin | High risk |

## Approval Workflow Summary
| Action | Initiator | Approver | Notes |
|--------|-----------|----------|-------|
| Centralized Page Create/Edit | country_admin | super_admin | Super admin can self-approve own edits automatically |
| Country Page Create/Edit | country_admin | super_admin | Could be auto-approved in future feature |
| Business Verification | business_owner | super_admin / country_admin | Either super or that country’s admin |
| Driver Verification | driver | super_admin / country_admin | Same pattern |
| Delivery Partner Verification | delivery_partner | super_admin / country_admin | Same pattern |
| Promo Code Creation | super_admin / country_admin* | super_admin | *Country admin if permission; may need secondary approval for high-impact codes |

## Country Scoping Rules
- All queries include `country_code` or equivalent filter unless super_admin.
- Centralized (global) records stored with `country: Global` or null → visible to all.
- Audit logs capture `actorRole`, `actorCountry`, and `targetCountry`.

## Security Considerations
1. Enforce server-side role + country checks (never rely solely on UI conditions).
2. Log privileged mutations (admin user changes, vehicle global changes, SMS config edits).
3. Separate permission flags from roles to allow feature-flag style rollout.
4. Rate limit high-impact endpoints (promo codes, system config) per admin.

## Gaps / Next Steps
| Gap | Proposed Action |
|-----|-----------------|
| Missing explicit `notificationsAdmin` implementation | Add backend guard & UI toggle |
| Need centralized permission seeder script | Create `scripts/seed_permissions.js` |
| No audit viewing UI | Add admin panel page filtered by country/role |
| Lacking per-country analytics scoping doc | Extend analytics section in `ARCHITECTURE_OVERVIEW.md` |

## Change Management
- Add new permission flags in a migration script and update admin creation logic.
- Document new flags here + reference in `CHANGELOG.md`.
- Provide fallback behavior when permission absent (hide UI + 403 server-side).

---
_This matrix should be reviewed every release._
