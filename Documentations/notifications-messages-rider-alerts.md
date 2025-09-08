# Notifications, Messages, and Rider Alerts — Implementation Summary

Last updated: 2025-08-22

## Overview
This document summarizes the work implemented to deliver the optional requirements:
- Notifications service (server + Flutter client)
- Messages (conversations list + chat send)
- Ride Alerts visibility gated to approved drivers
- Unread badges for Notifications and Messages in the menu

## Backend (Node.js + PostgreSQL)

### New/Updated Modules
- routes
  - `backend/routes/notifications.js`
    - `GET /api/notifications` — list current user notifications
    - `POST /api/notifications/mark-all-read` — mark all unread as read
    - `POST /api/notifications/:id/read` — mark a specific notification as read
    - `DELETE /api/notifications/:id` — delete a notification
    - `GET /api/notifications/counts` — unread counts `{ total, messages }`
  - `backend/routes/chat.js`
    - After sending a message, creates a `newMessage` notification for the other participant
- services
  - `backend/services/notification-helper.js`
    - `ensureSchema()` creates `notifications` table (with indices)
    - `createNotification()` inserts a new notification
    - `listForUser(userId, {limit, offset})`
    - `markAsRead(id)`, `markAllAsRead(userId)`, `remove(id)`
    - `countUnread(userId, {type})` for badges

### Notification Emission Hooks
- New response to a request → notify request owner as `newResponse`
- Request owner accepts a response → notify responder as `responseAccepted`
- New chat message → notify the other participant as `newMessage`

### Data Model (notifications)
```
notifications (
  id uuid pk default gen_random_uuid(),
  recipient_id uuid not null,
  sender_id uuid null,
  type text not null,                -- e.g., 'newResponse', 'responseAccepted', 'newMessage'
  title text not null,
  message text not null,
  data jsonb default '{}',           -- contextual payload (requestId, conversationId, etc.)
  status text default 'unread',
  created_at timestamptz default now(),
  read_at timestamptz null
)
```

## Flutter Client (request app)

### Services
- `request/lib/src/services/rest_notification_service.dart`
  - `fetchMyNotifications()`
  - `markAllRead()` / `markRead(id)` / `delete(id)`
  - `unreadCounts()` → `{ total, messages }` for badges
- `request/lib/src/services/chat_service.dart`
  - `listConversations({ userId })`: lists user conversations
  - `openConversation({ requestId, currentUserId, otherUserId })`
  - `getMessages({ conversationId })`
  - `sendMessage({ conversationId, senderId, content })`

### Screens and UX
- `request/lib/src/screens/notification_screen.dart`
  - Loads notifications via REST
  - Mark all read, mark single read, delete
  - Pull-to-refresh and auto-refresh after actions
- `request/lib/src/screens/modern_menu_screen.dart`
  - Ride Alerts tile visible only if `UserRegistrationService` indicates an approved driver
  - Badges displayed for Messages and Notifications using unread counts
  - Counts refresh automatically after returning from related screens
- Messages conversation list screen exists and integrates with `ChatService`

## API Reference (Quick)
- Notifications
  - `GET /api/notifications` → `{ success, data: Notification[] }`
  - `POST /api/notifications/mark-all-read` → `{ success }`
  - `POST /api/notifications/:id/read` → `{ success, data }`
  - `DELETE /api/notifications/:id` → `{ success, data }`
  - `GET /api/notifications/counts` → `{ success, data: { total, messages } }`
- Chat
  - `POST /api/chat/open` → `{ success, conversation, messages }`
  - `GET /api/chat/conversations?userId=...` → `{ success, conversations }`
  - `GET /api/chat/messages/:conversationId` → `{ success, messages }`
  - `POST /api/chat/messages` → `{ success, message }`

Auth: Notifications endpoints require the standard JWT Bearer token used across the app.

## How to run (local)
- Backend
  - Ensure Postgres is reachable and environment is set
  - Start server (port 3001)
- Flutter
  - `flutter run` from `request/`

Note: On Android emulator, the client targets `http://10.0.2.2:3001`.

## Edge cases handled
- Legacy chat conversations with `participant_ids` array are migrated on access
- Safe CREATE EXTENSION and ALTER COLUMN calls to avoid crashes on existing DBs
- Notification parsing falls back to sensible defaults for unknown values

## Verification summary
- Build/Lint: No analyzer errors in modified Dart files
- Backend: Server starts, new counts route is mounted and requires auth
- UI: Notification actions reflect immediately and badges refresh on return

## Next steps (optional)
- Real-time updates (WebSocket/SSE) for live badges and lists
- Push notifications (FCM/APNs)
- Per-conversation unread counts like read receipts

## Requirements mapping
- Implement notifications: Done (server + client + triggers)
- Implement messages: Done (list + send + notify)
- Rider alerts only for registered drivers: Done (gated tile)
- Optional enhancements (badges, refresh): Done
