# Deployment Notes

## Latest Updates

### Promo Code System Deployment (September 13, 2025)

**Important**: This deployment introduces the complete promo code system which requires the `express-validator` package.

#### New Dependencies Required:
- `express-validator@^7.2.1` (already in package.json)

#### Full Container Rebuild Required
The hot deployment strategy may not install new npm dependencies. If deployment fails with "Cannot find module 'express-validator'", a full container rebuild is required:

```bash
# Stop the current container
docker stop request-backend-container
docker rm request-backend-container

# Force full rebuild
docker build -t request-backend:latest .
docker run -d --name request-backend-container \
  --restart unless-stopped \
  --env-file /home/***/production.env \
  --label "com.cybersec-git-expert.app=request-backend" \
  -p "0.0.0.0:3001:3001" \
  request-backend:latest
```

#### New Features Added:
- Complete promo code system with user and admin APIs
- Database migration for promo codes tables (already executed)
- Authentication middleware properly configured
- Sample promo codes: WELCOME30, LAUNCH50, TESTCODE

#### API Endpoints:
- `POST /api/promo-codes/validate` - Validate promo codes
- `POST /api/promo-codes/redeem` - Redeem for Pro access
- `GET /api/promo-codes/check-active` - Check active benefits
- `GET /api/promo-codes/my-redemptions` - View history
- `GET /api/promo-codes/admin/list` - Admin: list all codes
- `POST /api/promo-codes/admin/create` - Admin: create codes
- `PUT /api/promo-codes/admin/:id` - Admin: update codes
- `DELETE /api/promo-codes/admin/:id` - Admin: delete codes

## Previous Deployments

### Authentication Fixes
- Fixed subscription cache synchronization
- Enhanced ResponseLimitService with promo code integration
- Resolved timing issues in unified request view screen