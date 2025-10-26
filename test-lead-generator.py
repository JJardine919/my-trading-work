#!/usr/bin/env python3
"""
Automated Lead Generator for Testing N8N Workflow
Generates realistic test leads and sends them to your N8N webhook
"""

import requests
import random
import time
from datetime import datetime

# CONFIGURATION
WEBHOOK_URL = "http://localhost:5678/webhook/lead-capture"
LEADS_PER_DAY = 5  # How many test leads to generate per day
DELAY_BETWEEN_LEADS = 60  # Seconds between each lead (60 = 1 per minute)

# Test data pools
FIRST_NAMES = ["James", "Mary", "John", "Patricia", "Robert", "Jennifer", "Michael", "Linda",
               "David", "Barbara", "William", "Elizabeth", "Richard", "Susan", "Joseph", "Jessica"]

LAST_NAMES = ["Smith", "Johnson", "Williams", "Brown", "Jones", "Garcia", "Miller", "Davis",
              "Rodriguez", "Martinez", "Hernandez", "Lopez", "Wilson", "Anderson", "Thomas"]

EMAIL_DOMAINS = ["gmail.com", "yahoo.com", "outlook.com", "hotmail.com", "protonmail.com"]

COMPANIES = ["Acme Trading LLC", "Capital Ventures", "Global Investments", "Quantum Finance",
             "Alpha Capital", "Beta Trading Co", "Gamma Investments", "Delta Securities",
             None, None, None]  # More None = more leads without company

BUDGETS = ["500", "1500", "2500", "5000", "7500", "10000", "15000", "25000"]

SOURCES = ["organic", "paid-ad", "paid-ad", "referral", "organic"]  # Weighted toward ads

AREA_CODES = ["212", "310", "415", "312", "617", "206", "305", "404", "512", "602"]


def generate_lead():
    """Generate a realistic test lead"""
    first_name = random.choice(FIRST_NAMES)
    last_name = random.choice(LAST_NAMES)

    # Generate email
    email_prefix = f"{first_name.lower()}.{last_name.lower()}{random.randint(1, 999)}"
    email = f"{email_prefix}@{random.choice(EMAIL_DOMAINS)}"

    # Generate phone
    area_code = random.choice(AREA_CODES)
    phone = f"+1{area_code}{random.randint(100, 999)}{random.randint(1000, 9999)}"

    lead = {
        "name": f"{first_name} {last_name}",
        "email": email,
        "phone": phone,
        "company": random.choice(COMPANIES),
        "budget": random.choice(BUDGETS),
        "source": random.choice(SOURCES)
    }

    return lead


def send_lead(lead):
    """Send lead to N8N webhook"""
    try:
        response = requests.post(WEBHOOK_URL, json=lead, timeout=10)

        if response.status_code == 200:
            score = lead.get('lead_score', 'N/A')
            print(f"✓ Lead sent: {lead['name']} ({lead['email']}) - Score: {score}")
            return True
        else:
            print(f"✗ Failed to send lead: {response.status_code}")
            return False

    except requests.exceptions.RequestException as e:
        print(f"✗ Error sending lead: {e}")
        return False


def run_continuous():
    """Run continuously, generating leads at regular intervals"""
    print(f"Starting automated lead generator...")
    print(f"Webhook URL: {WEBHOOK_URL}")
    print(f"Generating {LEADS_PER_DAY} leads per day")
    print(f"Delay between leads: {DELAY_BETWEEN_LEADS} seconds")
    print("-" * 60)

    leads_sent = 0

    try:
        while True:
            lead = generate_lead()

            if send_lead(lead):
                leads_sent += 1
                print(f"Total leads sent today: {leads_sent}")

            print(f"Waiting {DELAY_BETWEEN_LEADS} seconds until next lead...")
            print("-" * 60)

            time.sleep(DELAY_BETWEEN_LEADS)

    except KeyboardInterrupt:
        print(f"\nStopped. Total leads sent: {leads_sent}")


def run_batch(count=10):
    """Generate a batch of test leads quickly"""
    print(f"Generating {count} test leads...")
    print(f"Webhook URL: {WEBHOOK_URL}")
    print("-" * 60)

    successful = 0

    for i in range(count):
        lead = generate_lead()

        if send_lead(lead):
            successful += 1

        # Small delay between batch sends
        time.sleep(2)

    print("-" * 60)
    print(f"Batch complete: {successful}/{count} leads sent successfully")


if __name__ == "__main__":
    import sys

    print("\n" + "=" * 60)
    print("N8N LEAD GENERATOR")
    print("=" * 60 + "\n")

    if len(sys.argv) > 1:
        if sys.argv[1] == "batch":
            count = int(sys.argv[2]) if len(sys.argv) > 2 else 10
            run_batch(count)
        else:
            print("Usage:")
            print("  python test-lead-generator.py          # Run continuously")
            print("  python test-lead-generator.py batch 10 # Send 10 test leads")
    else:
        run_continuous()
