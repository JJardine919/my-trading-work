from reportlab.lib.pagesizes import letter
from reportlab.platypus import SimpleDocTemplate, Paragraph, Spacer
from reportlab.lib.styles import getSampleStyleSheet

# Create detailed PDF
pdf_file = "/mnt/data/sustai_marketing_stack_full.pdf"
doc = SimpleDocTemplate(pdf_file, pagesize=letter)
styles = getSampleStyleSheet()
story = []

# Title
story.append(Paragraph("<b>Sustai.io Marketing Agent Stack - Full Playbook</b>", styles['Title']))
story.append(Spacer(1, 12))

# Agent sections with expanded deliverables
# Lead Capture Agent
story.append(Paragraph("<b>Lead Capture Agent</b>", styles['Heading2']))
story.append(Paragraph("Role: Convert site visitors into contacts.", styles['Normal']))
story.append(Paragraph("KPIs: New signups/day, email open rate.", styles['Normal']))
story.append(Paragraph("Deliverables:", styles['Normal']))
story.append(Paragraph("- Signup Form (HTML):", styles['Normal']))
story.append(Paragraph("""
<form action="https://formspree.io/f/yourID" method="POST">
  <input type="text" name="first_name" placeholder="First Name" required>
  <input type="email" name="email" placeholder="Email Address" required>
  <button type="submit">Get Free 7-Day Trial</button>
</form>
""", styles['Code']))
story.append(Paragraph("- Email 1 (Welcome):", styles['Normal']))
story.append(Paragraph("Subject: Welcome to StrikeBot AI - Here's Your Free Trial", styles['Normal']))
story.append(Paragraph("Body: Hi [First Name], Welcome aboard! Here's your 7-day free trial of StrikeBot AI: [Download Link]. Setup takes less than 5 minutes. If you need help, our quick guide is here: [Setup Guide Link]. - Team Sustai.io", styles['Normal']))
story.append(Paragraph("- Email 2 (Follow-Up):", styles['Normal']))
story.append(Paragraph("Subject: Quick Wins with StrikeBot AI", styles['Normal']))
story.append(Paragraph("Body: Hi [First Name], By now, your trial should be running. Pro tip: run StrikeBot on BTCUSD or ETHUSD for the best results. Here's a short video walkthrough: [Video Link]. Stay profitable, - Team Sustai.io", styles['Normal']))
story.append(Spacer(1, 12))

# Content & SEO Agent
story.append(Paragraph("<b>Content &amp; SEO Agent</b>", styles['Heading2']))
story.append(Paragraph("Role: Build organic traffic.", styles['Normal']))
story.append(Paragraph("KPIs: Search rankings, organic visits.", styles['Normal']))
story.append(Paragraph("Deliverables:", styles['Normal']))
story.append(Paragraph("Blog Post Draft Title: How AI Trading Bots Can Help Pass Prop Firm Challenges", styles['Normal']))
story.append(Paragraph("Sections: Why Prop Firms Are Hard to Pass, How StrikeBot AI Works, Case Study: Simulated Payouts, CTA to download at sustai.io", styles['Normal']))
story.append(Paragraph("SEO Checklist: Keywords in H1/H2/meta, image alt tags, internal/external links.", styles['Normal']))
story.append(Spacer(1, 12))

# Social Media Agent
story.append(Paragraph("<b>Social Media Agent</b>", styles['Heading2']))
story.append(Paragraph("Role: Create visibility &amp; engagement.", styles['Normal']))
story.append(Paragraph("KPIs: Video views, CTR.", styles['Normal']))
story.append(Paragraph("Deliverables:", styles['Normal']))
story.append(Paragraph("Captions:", styles['Normal']))
story.append(Paragraph("1. AI trading bots that pass prop firm challenges. Try StrikeBot free. #TradingAI #PropFirm", styles['Normal']))
story.append(Paragraph("2. $0 to Funded trader? StrikeBot runs the challenge for you. #AITrading #FTMO", styles['Normal']))
story.append(Paragraph("3. Why trade manually? Automate with StrikeBot. Get your 7-day free trial! #CryptoTrading #MT5", styles['Normal']))
story.append(Paragraph("Overlay Text: 'Download Free Trial Now at sustai.io'", styles['Normal']))
story.append(Paragraph("Posting Calendar (7 Days): Day 1 dashboard clip, Day 3 text reel, Day 5 testimonial/chart screenshot.", styles['Normal']))
story.append(Spacer(1, 12))

# Outreach Agent
story.append(Paragraph("<b>Outreach Agent</b>", styles['Heading2']))
story.append(Paragraph("Role: Target partners.", styles['Normal']))
story.append(Paragraph("KPIs: Response rate, deals initiated.", styles['Normal']))
story.append(Paragraph("Deliverables:", styles['Normal']))
story.append(Paragraph("Email Template for Prop Firms:", styles['Normal']))
story.append(Paragraph("Subject: Partnership Opportunity: StrikeBot AI", styles['Normal']))
story.append(Paragraph("Body: Hi [Name], We help traders pass challenges with AI trading bots. StrikeBot is designed for compliance with prop firm rules. We'd like to offer you a free trial for your firm to test internally. If results look good, let's explore a partnership. - James, Sustai.io", styles['Normal']))
story.append(Paragraph("DM Script for Influencers: Hey [Name], we're giving away a free trial of StrikeBot AI, designed to pass prop firm challenges. Would you like early access for your audience? Affiliate options available.", styles['Normal']))
story.append(Paragraph("5 Lead Platforms: LinkedIn, Trading Discords, ForexFactory, Telegram trading groups, Reddit r/Forex", styles['Normal']))
story.append(Spacer(1, 12))

# Analytics Agent
story.append(Paragraph("<b>Analytics Agent</b>", styles['Heading2']))
story.append(Paragraph("Role: Track &amp; optimize funnel.", styles['Normal']))
story.append(Paragraph("KPIs: Conversion %, CAC vs LTV.", styles['Normal']))
story.append(Paragraph("Deliverables:", styles['Normal']))
story.append(Paragraph("Setup Guide: GA4 + Hotjar tracking, conversion goals.", styles['Normal']))
story.append(Paragraph("Dashboard Layout: Visitors/day, source breakdown, conversion %, paid conversions.", styles['Normal']))
story.append(Paragraph("Weekly Reporting Tools: Google Data Studio, Hotjar free, GA4.", styles['Normal']))
story.append(Spacer(1, 12))

# Funnel Summary
story.append(Paragraph("<b>Funnel Summary</b>", styles['Heading2']))
story.append(Paragraph("1. Social + Content Agents bring traffic.", styles['Normal']))
story.append(Paragraph("2. Lead Capture Agent converts to signups.", styles['Normal']))
story.append(Paragraph("3. Outreach Agent adds B2B/affiliates.", styles['Normal']))
story.append(Paragraph("4. Analytics Agent monitors performance and optimizes loop.", styles['Normal']))

doc.build(story)
print(f"PDF successfully created: {pdf_file}")
