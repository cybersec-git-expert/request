#!/bin/bash

# AWS RDS Setup Script for Request Marketplace Migration
# This script creates and configures an AWS RDS PostgreSQL instance

set -e

# Configuration variables
DB_INSTANCE_IDENTIFIER="request-db"
DB_NAME="request_db"
DB_USERNAME="request_admin"
DB_PASSWORD="AWS2025RDS!"
DB_INSTANCE_CLASS="db.t3.micro"  # Change to db.t3.medium for production
DB_ENGINE="postgres"
DB_ENGINE_VERSION="15.14"
DB_ALLOCATED_STORAGE=20
DB_STORAGE_TYPE="gp2"
VPC_SECURITY_GROUP_ID=""  # Will be created
DB_SUBNET_GROUP_NAME="request-marketplace-subnet-group"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}🚀 Starting AWS RDS Setup for Request Marketplace${NC}"
echo "=================================================================="

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    echo -e "${RED}❌ AWS CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if user is logged in to AWS
echo -e "${YELLOW}📋 Checking AWS credentials...${NC}"
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}❌ AWS credentials not configured. Please run 'aws configure' first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ AWS credentials verified${NC}"

# Get default VPC ID
echo -e "${YELLOW}🔍 Finding default VPC...${NC}"
VPC_ID=$(aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" --query "Vpcs[0].VpcId" --output text)

if [ "$VPC_ID" = "None" ] || [ -z "$VPC_ID" ]; then
    echo -e "${RED}❌ No default VPC found. Please create a VPC first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Found default VPC: $VPC_ID${NC}"

# Get subnet IDs
echo -e "${YELLOW}🔍 Finding subnets in VPC...${NC}"
SUBNET_IDS=$(aws ec2 describe-subnets --filters "Name=vpc-id,Values=$VPC_ID" --query "Subnets[].SubnetId" --output text)

if [ -z "$SUBNET_IDS" ]; then
    echo -e "${RED}❌ No subnets found in VPC. Please create subnets first.${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Found subnets: $SUBNET_IDS${NC}"

# Create DB subnet group
echo -e "${YELLOW}🔧 Creating DB subnet group...${NC}"
aws rds create-db-subnet-group \
    --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
    --db-subnet-group-description "Subnet group for Request Marketplace database" \
    --subnet-ids $SUBNET_IDS \
    --tags Key=Project,Value=RequestMarketplace Key=Environment,Value=Production \
    2>/dev/null || echo -e "${YELLOW}⚠️  DB subnet group may already exist${NC}"

echo -e "${GREEN}✅ DB subnet group created/verified${NC}"

# Create security group for RDS
echo -e "${YELLOW}🔒 Creating security group for RDS...${NC}"

# Check if security group already exists
EXISTING_SG=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=request-marketplace-rds-sg" "Name=vpc-id,Values=$VPC_ID" \
    --query "SecurityGroups[0].GroupId" \
    --output text 2>/dev/null)

if [ "$EXISTING_SG" != "None" ] && [ ! -z "$EXISTING_SG" ]; then
    SECURITY_GROUP_ID="$EXISTING_SG"
    echo -e "${YELLOW}⚠️  Using existing security group: $SECURITY_GROUP_ID${NC}"
else
    # Create new security group
    SECURITY_GROUP_ID=$(aws ec2 create-security-group \
        --group-name "request-marketplace-rds-sg" \
        --description "Security group for Request Marketplace RDS" \
        --vpc-id "$VPC_ID" \
        --query "GroupId" \
        --output text)
    
    if [ -z "$SECURITY_GROUP_ID" ] || [ "$SECURITY_GROUP_ID" = "None" ]; then
        echo -e "${RED}❌ Failed to create security group${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Created new security group: $SECURITY_GROUP_ID${NC}"
fi

echo -e "${GREEN}✅ Security group ID: $SECURITY_GROUP_ID${NC}"

# Add inbound rule for PostgreSQL (port 5432)
echo -e "${YELLOW}🔧 Configuring security group rules...${NC}"
aws ec2 authorize-security-group-ingress \
    --group-id "$SECURITY_GROUP_ID" \
    --protocol tcp \
    --port 5432 \
    --cidr 0.0.0.0/0 \
    2>/dev/null || echo -e "${YELLOW}⚠️  Security group rule may already exist${NC}"

echo -e "${GREEN}✅ Security group rules configured${NC}"

# Check if RDS instance already exists
echo -e "${YELLOW}🔍 Checking if RDS instance exists...${NC}"
if aws rds describe-db-instances --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" &>/dev/null; then
    echo -e "${YELLOW}⚠️  RDS instance '$DB_INSTANCE_IDENTIFIER' already exists!${NC}"
    
    # Get the endpoint
    DB_ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
        --query "DBInstances[0].Endpoint.Address" \
        --output text)
    
    echo -e "${GREEN}✅ Existing RDS instance endpoint: $DB_ENDPOINT${NC}"
else
    # Create RDS instance
    echo -e "${YELLOW}🚀 Creating RDS PostgreSQL instance...${NC}"
    echo "This may take 10-15 minutes..."
    
    aws rds create-db-instance \
        --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
        --db-instance-class "$DB_INSTANCE_CLASS" \
        --engine "$DB_ENGINE" \
        --engine-version "$DB_ENGINE_VERSION" \
        --master-username "$DB_USERNAME" \
        --master-user-password "$DB_PASSWORD" \
        --allocated-storage "$DB_ALLOCATED_STORAGE" \
        --storage-type "$DB_STORAGE_TYPE" \
        --db-name "$DB_NAME" \
        --vpc-security-group-ids "$SECURITY_GROUP_ID" \
        --db-subnet-group-name "$DB_SUBNET_GROUP_NAME" \
        --backup-retention-period 7 \
        --storage-encrypted \
        --deletion-protection \
        --enable-performance-insights \
        --tags Key=Project,Value=RequestMarketplace Key=Environment,Value=Production
    
    echo -e "${GREEN}✅ RDS instance creation initiated${NC}"
    
    # Wait for the instance to be available
    echo -e "${YELLOW}⏳ Waiting for RDS instance to be available...${NC}"
    aws rds wait db-instance-available --db-instance-identifier "$DB_INSTANCE_IDENTIFIER"
    
    # Get the endpoint
    DB_ENDPOINT=$(aws rds describe-db-instances \
        --db-instance-identifier "$DB_INSTANCE_IDENTIFIER" \
        --query "DBInstances[0].Endpoint.Address" \
        --output text)
    
    echo -e "${GREEN}✅ RDS instance is now available!${NC}"
fi

# Create environment file
echo -e "${YELLOW}📝 Creating environment configuration...${NC}"
cat > .env.rds << EOF
# AWS RDS Configuration for Request Marketplace
DB_HOST=$DB_ENDPOINT
DB_PORT=5432
DB_NAME=$DB_NAME
DB_USERNAME=$DB_USERNAME
DB_PASSWORD=$DB_PASSWORD
DB_SSL=true

# Connection pool settings
DB_POOL_MIN=2
DB_POOL_MAX=10
DB_POOL_IDLE_TIMEOUT=30000

# Application settings
NODE_ENV=production
JWT_SECRET=$(openssl rand -base64 32)
API_BASE_URL=https://api.requestmarketplace.com
EOF

echo -e "${GREEN}✅ Environment file created: .env.rds${NC}"

# Create connection test script
cat > test-db-connection.js << 'EOF'
const { Pool } = require('pg');
require('dotenv').config({ path: '.env.rds' });

const pool = new Pool({
    host: process.env.DB_HOST,
    port: process.env.DB_PORT,
    database: process.env.DB_NAME,
    user: process.env.DB_USERNAME,
    password: process.env.DB_PASSWORD,
    ssl: process.env.DB_SSL === 'true' ? { rejectUnauthorized: false } : false,
});

async function testConnection() {
    try {
        console.log('🔗 Testing database connection...');
        const client = await pool.connect();
        
        const result = await client.query('SELECT version(), current_database(), current_user');
        console.log('✅ Database connection successful!');
        console.log('📋 Database Info:');
        console.log(`   Version: ${result.rows[0].version.split(' ').slice(0, 2).join(' ')}`);
        console.log(`   Database: ${result.rows[0].current_database}`);
        console.log(`   User: ${result.rows[0].current_user}`);
        
        client.release();
        process.exit(0);
    } catch (error) {
        console.error('❌ Database connection failed:', error.message);
        process.exit(1);
    }
}

testConnection();
EOF

echo -e "${GREEN}✅ Database connection test script created${NC}"

# Display summary
echo ""
echo "=================================================================="
echo -e "${GREEN}🎉 AWS RDS Setup Complete!${NC}"
echo "=================================================================="
echo ""
echo -e "${YELLOW}📋 Connection Details:${NC}"
echo "   Endpoint: $DB_ENDPOINT"
echo "   Port: 5432"
echo "   Database: $DB_NAME"
echo "   Username: $DB_USERNAME"
echo "   Password: $DB_PASSWORD"
echo ""
echo -e "${YELLOW}📁 Files Created:${NC}"
echo "   - .env.rds (environment configuration)"
echo "   - test-db-connection.js (connection test)"
echo ""
echo -e "${YELLOW}🔜 Next Steps:${NC}"
echo "   1. Install PostgreSQL client: npm install pg"
echo "   2. Test connection: node test-db-connection.js"
echo "   3. Run schema creation: psql -h $DB_ENDPOINT -U $DB_USERNAME -d $DB_NAME -f migration/01-database-schema.sql"
echo "   4. Start data migration process"
echo ""
echo -e "${GREEN}✅ Ready for Phase 2: Data Migration${NC}"
