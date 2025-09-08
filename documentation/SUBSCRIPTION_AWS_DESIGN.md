# Subscription and Usage Limits (AWS + Postgres)

This design implements your rules using AWS and the existing Node/Express + PostgreSQL backend.

## Business rules (as requested)
- Anyone can post requests (unlimited).
- Normal users: up to 3 responses per month; after 3, hide message icon and contact details in request views.
- Applies to: riders registered as driver, and delivery services registered as driver service business type.
- Price Comparison businesses can choose: pay-per-click (PPC) or monthly subscription.
- If subscribed:
  - Normal users: contact details revealed, no 3-per-month limit.
  - Businesses: contact details revealed and receive notifications for new requests in their categories.

## AWS components
- RDS PostgreSQL: authoritative state (users, subscriptions, usage, clicks, categories).
- SNS (or SES/Pinpoint): notifications to businesses (push/email/SMS). Keep your current push provider if you already use FCM/APNs.
- SQS (optional): buffer notification fan-out on request creation.
- CloudWatch Events (or cron in PM2): to run periodic cleanups (optional; month key design avoids hard resets).

## Data model (PostgreSQL)
- subscription_plans
  - id (uuid), name, audience ('normal'|'business'), model ('monthly'|'ppc'), price_cents, currency, is_active, created_at.
- subscriptions
  - id (uuid), user_id, plan_id, status ('active','canceled','expired','trialing'), start_at, current_period_end, cancel_at_period_end, provider ('internal'|'stripe'|...)
- usage_monthly
  - user_id, year_month (char(6) like '202508'), response_count int default 0, updated_at
  - PK (user_id, year_month)
- price_comparison_business
  - business_id, mode ('ppc'|'monthly'), monthly_plan_id nullable, ppc_price_cents, currency, is_active, updated_at
- ppc_clicks
  - id (uuid), business_id, request_id, click_type ('view_contact'|'message'|'call'), cost_cents, currency, created_at
- categories (if not already)
  - id, slug, name
- business_categories
  - business_id, category_id

Notes:
- Month scoping uses a composite key (user_id + year_month). No explicit monthly reset needed.

## Backend behavior
- Entitlements API: GET /me/subscription
  - Returns: isSubscribed, audience ('normal' or 'business'), plan info, currentPeriodEnd, responseCountThisMonth, canViewContact, canMessage.
- Usage limiting middleware (for responses):
  - If user role is normal (or rider-as-driver) and not subscribed: enforce response_count < 3 for current year_month.
  - Increment usage on successful response creation.
- Request view payload:
  - Include flags canViewContact and canMessage, computed as:
    - true if subscribed OR (business with active monthly or PPC) OR (normal user with response_count < 3)
- Price comparison businesses:
  - If monthly subscription active: contact reveal allowed; no per-click charge.
  - If PPC: allow reveal; record click in ppc_clicks with cost_cents.
- Notifications (business only):
  - On request creation, fan-out to businesses that are subscribed (monthly) and match any category of the request. PPC businesses can be notified if you choose; commonly restricted to monthly.

## Edge cases
- Grace period: optional 48–72h grace after period end for better UX.
- Double responses: use transactions or upsert to avoid over-count on retries.
- Upgrades/downgrades mid-cycle: switch entitlement immediately; bill via provider.

## Rollout steps
1) Apply DB tables below.
2) Implement entitlement checks and usage updates in response creation and request view endpoints.
3) Add simple admin UI to select business mode (PPC vs monthly) and set PPC price.
4) Add notification fan-out based on categories and subscription status.

## SQL draft (see migration file)
See `backend/migration/20250827_subscriptions.sql` for a safe starting schema.

## Minimal entitlement contract
Input: user_id, role, now
Output:
- isSubscribed: boolean
- audience: 'normal' | 'business'
- responseCountThisMonth: number
- canViewContact: boolean
- canMessage: boolean
- businessMode: 'monthly' | 'ppc' | null

Error modes: missing user, db errors (500), unknown role (403 for restricted actions).
