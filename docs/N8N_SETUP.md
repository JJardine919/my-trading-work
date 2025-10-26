# N8N Automation Setup Guide

This guide will help you set up N8N with Docker Desktop for your automated sales workflows.

## Table of Contents
- [Prerequisites](#prerequisites)
- [Quick Start](#quick-start)
- [Environment Configuration](#environment-configuration)
- [Importing Workflows](#importing-workflows)
- [Workflow Overview](#workflow-overview)
- [API Credentials Setup](#api-credentials-setup)
- [Troubleshooting](#troubleshooting)

---

## Prerequisites

Before starting, make sure you have:

- **Docker Desktop** installed and running
- **Git** installed
- Access to the required third-party services:
  - Airtable account (for CRM)
  - SendGrid account (for email automation)
  - Slack workspace (for notifications)
  - Stripe account (for payment processing)
  - Google account (for Sheets integration)

---

## Quick Start

### 1. Clone the Repository

```bash
cd /path/to/my-trading-work
```

### 2. Create Your Environment File

```bash
cp .env.example .env
```

### 3. Edit the .env File

Open `.env` and configure your settings:

```bash
nano .env
```

**Required settings:**
- Set `N8N_BASIC_AUTH_USER` (your username)
- Set `N8N_BASIC_AUTH_PASSWORD` (strong password)
- Generate encryption key: `openssl rand -hex 16`
- Set database password

### 4. Start N8N with Docker Compose

```bash
docker-compose up -d
```

### 5. Access N8N

Open your browser and navigate to:
```
http://localhost:5678
```

Login with your credentials from the `.env` file.

---

## Environment Configuration

### Core N8N Settings

```env
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your_secure_password_here
N8N_ENCRYPTION_KEY=generate_with_openssl_rand_hex_16
```

### Database Settings

```env
POSTGRES_USER=n8n
POSTGRES_PASSWORD=secure_database_password
POSTGRES_DB=n8n
```

### Webhook Configuration

If deploying publicly (not localhost):
```env
N8N_HOST=your-domain.com
N8N_PROTOCOL=https
WEBHOOK_URL=https://your-domain.com
```

---

## Importing Workflows

### Method 1: Import via UI

1. Open N8N at `http://localhost:5678`
2. Click **"Workflows"** in the left sidebar
3. Click **"Import from File"**
4. Navigate to `/n8n-workflows/` directory
5. Select and import each JSON file:
   - `1-lead-capture-routing.json`
   - `2-email-nurture-sequence.json`
   - `3-payment-processing-automation.json`
   - `4-analytics-daily-reporting.json`

### Method 2: Mount Workflows Directory

The docker-compose.yml already mounts `./n8n-workflows:/workflows`, so you can:

1. Copy workflow files to `/home/node/.n8n/workflows/` inside the container
2. Restart the container: `docker-compose restart n8n`

---

## Workflow Overview

### 1. Lead Capture & Routing
**File:** `1-lead-capture-routing.json`

**Purpose:** Captures leads from web forms, scores them, stores in Airtable, and sends personalized emails.

**Trigger:** Webhook (POST)
- Webhook URL: `http://localhost:5678/webhook/lead-capture`

**Flow:**
1. Receives lead data via webhook
2. Calculates lead score based on source and data quality
3. Saves to Airtable CRM
4. Routes by score (hot vs. cold)
5. Sends appropriate welcome email
6. Notifies team on Slack

**Required Credentials:**
- Airtable API
- SendGrid API
- Slack API

**Test Example:**
```bash
curl -X POST http://localhost:5678/webhook/lead-capture \
  -H "Content-Type: application/json" \
  -d '{
    "name": "John Doe",
    "email": "john@example.com",
    "phone": "+1234567890",
    "company": "Acme Corp",
    "budget": "5000",
    "source": "referral"
  }'
```

---

### 2. Automated Email Nurture Sequence
**File:** `2-email-nurture-sequence.json`

**Purpose:** Sends automated drip campaign emails to nurture leads over 10 days.

**Trigger:** Cron (Every 12 hours)

**Email Sequence:**
- **Day 2:** "The #1 Mistake People Make"
- **Day 4:** "How [Solution] Can Help You"
- **Day 6:** "Real Results: [Customer] Story"
- **Day 8:** "20% Off - Limited Time"
- **Day 10:** "Last Chance: Your 20% Discount Expires Tonight"

**Flow:**
1. Runs every 12 hours
2. Fetches leads from Airtable needing nurture
3. Determines which day in sequence each lead is on
4. Sends appropriate email template
5. Updates "Last Contact" timestamp

**Required Credentials:**
- Airtable API
- SendGrid API

**Customization:**
- Edit email templates in each "Email" node
- Adjust timing in the "Determine Email Sequence" function
- Update sender email addresses

---

### 3. Payment Processing & Sales Automation
**File:** `3-payment-processing-automation.json`

**Purpose:** Processes Stripe payments, creates orders, sends confirmations, and triggers fulfillment.

**Trigger:** Webhook (Stripe)
- Webhook URL: `http://localhost:5678/webhook/stripe-webhook`

**Flow:**
1. Receives Stripe `checkout.session.completed` webhook
2. Extracts order and customer data
3. Saves order to Airtable
4. Updates lead status to "customer"
5. Sends order confirmation email
6. Sends onboarding email
7. Notifies team on Slack
8. Triggers fulfillment API

**Required Credentials:**
- Stripe Webhook Secret
- Airtable API
- SendGrid API
- Slack API
- API Auth (for fulfillment endpoint)

**Stripe Webhook Setup:**
1. Go to Stripe Dashboard > Developers > Webhooks
2. Add endpoint: `http://localhost:5678/webhook/stripe-webhook`
3. Select event: `checkout.session.completed`
4. Copy webhook signing secret to `.env`

---

### 4. Analytics & Daily Reporting
**File:** `4-analytics-daily-reporting.json`

**Purpose:** Generates daily sales reports and logs metrics to Google Sheets.

**Trigger:** Cron (Daily at 9 AM)

**Flow:**
1. Fetches today's leads and orders from Airtable
2. Fetches all leads for conversion metrics
3. Calculates key metrics:
   - New leads today
   - Sales today
   - Revenue today
   - Average order value
   - Conversion rate
   - Lead source breakdown
4. Logs to Google Sheets
5. Posts report to Slack
6. Celebrates milestones (10+ leads)

**Required Credentials:**
- Airtable API
- Google Sheets OAuth2
- Slack API

**Metrics Tracked:**
- Total leads
- Today's leads
- Today's orders
- Today's revenue
- Average order value
- Conversion rate
- Lead status breakdown (hot/warm/cold/customer)
- Top lead sources

---

## API Credentials Setup

### Airtable

1. Go to https://airtable.com/create/tokens
2. Create personal access token
3. Grant scopes: `data.records:read`, `data.records:write`
4. Copy token to `.env` as `AIRTABLE_API_KEY`
5. Get your Base ID from the URL: `https://airtable.com/appXXXXXXX/...`
6. Update all workflow nodes with your Base ID

**In N8N:**
1. Go to **Credentials** > **New**
2. Select **Airtable API**
3. Paste your API key
4. Save as "Airtable API"

### SendGrid

1. Go to https://app.sendgrid.com/settings/api_keys
2. Create API Key with "Mail Send" permissions
3. Copy to `.env` as `SENDGRID_API_KEY`

**In N8N:**
1. Go to **Credentials** > **New**
2. Select **SendGrid**
3. Paste your API key
4. Save as "SendGrid"

### Slack

**Option 1: Webhook (Simple)**
1. Go to https://api.slack.com/apps
2. Create new app
3. Enable Incoming Webhooks
4. Add webhook to workspace
5. Copy webhook URL to `.env`

**Option 2: Bot Token (Advanced)**
1. Create Slack app
2. Add Bot Token Scopes: `chat:write`, `chat:write.public`
3. Install app to workspace
4. Copy Bot User OAuth Token

**In N8N:**
1. Go to **Credentials** > **New**
2. Select **Slack API**
3. Enter your Bot Token or Webhook URL
4. Save as "Slack API"

### Stripe

1. Go to https://dashboard.stripe.com/apikeys
2. Copy your Secret Key (starts with `sk_`)
3. Go to Webhooks section
4. Create webhook endpoint
5. Copy signing secret

**In N8N:**
Configure Stripe webhook to send to your N8N endpoint.

### Google Sheets

**In N8N:**
1. Go to **Credentials** > **New**
2. Select **Google Sheets OAuth2 API**
3. Follow OAuth flow to authenticate
4. Create a Google Sheet for your dashboard
5. Copy Sheet ID from URL
6. Update workflow node with Sheet ID

---

## Airtable Base Setup

Create an Airtable base with two tables:

### Leads Table
Columns:
- Lead ID (Single line text)
- Name (Single line text)
- Email (Email)
- Phone (Phone number)
- Company (Single line text)
- Source (Single select: paid-ad, organic, referral)
- Lead Score (Number)
- Status (Single select: hot, warm, cold, customer, unsubscribed)
- Created At (Date)
- Last Contact (Date)
- Lifetime Value (Currency)
- Last Purchase (Date)

### Orders Table
Columns:
- Order ID (Single line text)
- Stripe Session ID (Single line text)
- Customer Email (Email)
- Customer Name (Single line text)
- Amount (Currency)
- Currency (Single line text)
- Product (Single line text)
- Status (Single select: paid, refunded, failed)
- Created At (Date)

---

## Troubleshooting

### N8N won't start

```bash
# Check Docker logs
docker-compose logs n8n

# Check if port 5678 is in use
lsof -i :5678

# Restart services
docker-compose down
docker-compose up -d
```

### Database connection errors

```bash
# Check Postgres logs
docker-compose logs postgres

# Verify database is healthy
docker-compose ps
```

### Webhook not receiving data

1. Check N8N is accessible at the webhook URL
2. Verify webhook path matches in workflow
3. Check firewall/network settings
4. For Stripe: Verify webhook endpoint in Stripe Dashboard
5. Test with curl to ensure webhook responds

### Workflows not executing

1. Check workflow is **active** (toggle in top right)
2. Verify credentials are properly configured
3. Check execution logs in N8N UI
4. Test trigger manually using "Execute Workflow"

### Email not sending

1. Verify SendGrid API key is valid
2. Check sender email is verified in SendGrid
3. Review SendGrid activity logs
4. Check N8N execution logs for errors

---

## Docker Commands

```bash
# Start N8N
docker-compose up -d

# Stop N8N
docker-compose down

# View logs
docker-compose logs -f n8n

# Restart N8N
docker-compose restart n8n

# Update N8N to latest version
docker-compose pull
docker-compose up -d

# Backup data
docker-compose exec postgres pg_dump -U n8n n8n > backup.sql

# Access N8N container shell
docker-compose exec n8n /bin/sh
```

---

## Security Best Practices

1. **Change default passwords** in `.env` file
2. **Use strong encryption key** (32+ characters)
3. **Never commit `.env`** to git (already in .gitignore)
4. **Enable HTTPS** for production deployments
5. **Restrict webhook access** with authentication
6. **Rotate API keys** regularly
7. **Use environment-specific credentials** (dev vs. prod)

---

## Next Steps

1. Import all 4 workflows into N8N
2. Configure API credentials for each service
3. Update Airtable Base IDs in workflows
4. Test each workflow manually
5. Activate workflows
6. Monitor execution logs
7. Customize email templates and logic as needed

---

## Support

For issues specific to:
- **N8N:** https://docs.n8n.io/
- **Docker:** https://docs.docker.com/
- **Airtable:** https://support.airtable.com/
- **SendGrid:** https://docs.sendgrid.com/
- **Stripe:** https://stripe.com/docs

---

## Workflow Diagram

```
┌─────────────────────────────────────────────────────────────┐
│                     N8N Automation System                    │
└─────────────────────────────────────────────────────────────┘

[Web Form] ──────────┐
                      │
                      ▼
        ┌─────────────────────────┐
        │ 1. Lead Capture         │
        │    & Routing            │
        └─────────────────────────┘
                      │
                      ├─── [Airtable CRM]
                      ├─── [Email (Hot/Cold)]
                      └─── [Slack Notification]

                      │
                      ▼
        ┌─────────────────────────┐
        │ 2. Email Nurture        │ ◄─── [Cron: Every 12h]
        │    Sequence             │
        └─────────────────────────┘
                      │
                      └─── [SendGrid: Day 2,4,6,8,10]

[Stripe] ────────────┐
                      │
                      ▼
        ┌─────────────────────────┐
        │ 3. Payment              │
        │    Processing           │
        └─────────────────────────┘
                      │
                      ├─── [Airtable: Orders]
                      ├─── [Confirmation Email]
                      ├─── [Onboarding Email]
                      ├─── [Slack: Sale Alert]
                      └─── [Fulfillment API]

                      │
                      ▼
        ┌─────────────────────────┐
        │ 4. Analytics &          │ ◄─── [Cron: Daily 9am]
        │    Reporting            │
        └─────────────────────────┘
                      │
                      ├─── [Google Sheets]
                      └─── [Slack: Daily Report]
```

---

## License

This automation system is part of the my-trading-work project.
