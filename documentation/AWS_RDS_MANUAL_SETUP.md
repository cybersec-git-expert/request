# Amazon RDS Creation Guide - Manual Setup via AWS Console

## Step-by-Step RDS Creation Process

### 1. Login to AWS Console
1. Go to https://aws.amazon.com/console/
2. Sign in with your AWS account (not the limited SES user)
3. Navigate to **RDS** service

### 2. Create Database Instance

#### Basic Configuration:
- **Database creation method**: Standard create
- **Engine type**: PostgreSQL
- **Engine version**: 15.14 (or latest 15.x)
- **Templates**: Free tier (for testing) or Production (for live)

#### Database Instance Settings:
- **DB instance identifier**: `request-marketplace-db`
- **Master username**: `admin`
- **Master password**: `RequestMarketplace2025!`
- **Confirm password**: `RequestMarketplace2025!`

#### Instance Configuration:
- **DB instance class**: 
  - For testing: `db.t3.micro` (free tier eligible)
  - For production: `db.t3.small` or `db.t3.medium`
- **Storage type**: General Purpose SSD (gp2)
- **Allocated storage**: 20 GB
- **Enable storage autoscaling**: Yes
- **Maximum storage threshold**: 100 GB

#### Connectivity:
- **Virtual private cloud (VPC)**: Default VPC
- **Subnet group**: Default
- **Public access**: Yes (for easier initial setup)
- **VPC security group**: Create new
- **Security group name**: `request-marketplace-rds-sg`
- **Availability Zone**: No preference
- **Database port**: 5432

#### Database Authentication:
- **Database authentication**: Password authentication

#### Additional Configuration:
- **Initial database name**: `request_marketplace`
- **DB parameter group**: default.postgres15
- **Option group**: default:postgres-15
- **Backup retention period**: 7 days
- **Backup window**: No preference
- **Copy tags to snapshots**: Yes
- **Enable encryption**: Yes
- **Enable Performance Insights**: Yes (recommended)
- **Monitoring**: Enhanced monitoring - No (to save costs)
- **Log exports**: None (for now)
- **Enable auto minor version upgrade**: Yes
- **Maintenance window**: No preference
- **Enable deletion protection**: Yes (recommended for production)

### 3. Configure Security Group

After RDS creation:
1. Go to **EC2 > Security Groups**
2. Find the security group created for RDS
3. Add inbound rule:
   - **Type**: PostgreSQL
   - **Port**: 5432
   - **Source**: 0.0.0.0/0 (for testing) or your specific IP
   - **Description**: PostgreSQL access for Request Marketplace

### 4. Get Connection Details

Once created, note down:
- **Endpoint**: (will be something like request-marketplace-db.xxxxx.region.rds.amazonaws.com)
- **Port**: 5432
- **Database name**: request_marketplace
- **Username**: admin
- **Password**: RequestMarketplace2025!

### 5. Test Connection

Use the connection details to test from your local machine:
```bash
psql -h <ENDPOINT> -U admin -d request_marketplace
```

## Estimated Creation Time: 10-15 minutes

## Next Steps After RDS Creation:
1. Test database connection
2. Run schema creation script
3. Start Firebase data export
4. Begin data migration process

## Security Notes:
- Change the password after initial setup
- Restrict security group access to specific IPs in production
- Enable SSL connections for production use
- Set up proper IAM roles for application access
