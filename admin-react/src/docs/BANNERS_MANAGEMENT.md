# Banners Management (Admin)

This module lets super admins manage global banners and country admins manage country-specific banners shown in the mobile app Home screen.

- Country Admin: Sidebar ➜ Banners ➜ CRUD banners for their country only
- Super Admin: Sidebar ➜ Global Banners ➜ CRUD banners globally (no country restriction)

API endpoints expected:
- GET /api/banners?country=LK (or without country for global)
- POST /api/banners { title, subtitle, imageUrl, linkUrl, active, priority, country? }
- PUT /api/banners/:id
- DELETE /api/banners/:id

If your backend uses different paths (e.g., /api/countries/:code/banners), update `BannersModule.jsx` and the mobile app `BannerService` accordingly.
