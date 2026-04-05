#!/usr/bin/env python3
"""Send Garmin recap email via Resend REST API. Zero external dependencies."""

import json
import os
import re
import sys
import urllib.request
import urllib.error

BASE_DIR = os.path.dirname(os.path.abspath(__file__))

# Load .env.local
env_file = os.path.join(BASE_DIR, ".env.local")
env = {}
with open(env_file) as f:
    for line in f:
        line = line.strip()
        if "=" in line and not line.startswith("#"):
            key, _, val = line.partition("=")
            env[key.strip()] = val.strip()

RESEND_API_KEY = env.get("RESEND_API_KEY")
NOTIFICATION_EMAIL = env.get("NOTIFICATION_EMAIL")
if not NOTIFICATION_EMAIL:
    print("ERROR: NOTIFICATION_EMAIL not found in .env.local")
    sys.exit(1)

if not RESEND_API_KEY:
    print("ERROR: RESEND_API_KEY not found in .env.local")
    sys.exit(1)

# Get recap file from args
if len(sys.argv) < 2 or not os.path.exists(sys.argv[1]):
    print(f"ERROR: Recap file not found: {sys.argv[1] if len(sys.argv) > 1 else '(none)'}")
    sys.exit(1)

recap_file = sys.argv[1]
with open(recap_file) as f:
    md = f.read()

# Extract date from filename
date_match = re.search(r"(\d{4}-\d{2}-\d{2})", recap_file)
date_str = date_match.group(1) if date_match else ""

# Markdown to HTML
html = md
html = re.sub(r"^# (.+)$", r"<h1>\1</h1>", html, flags=re.MULTILINE)
html = re.sub(r"^## (.+)$", r"<h2>\1</h2>", html, flags=re.MULTILINE)
html = re.sub(r"^### (.+)$", r"<h3>\1</h3>", html, flags=re.MULTILINE)
html = re.sub(r"\*\*(.+?)\*\*", r"<strong>\1</strong>", html)
html = re.sub(r"^- (.+)$", r"<li>\1</li>", html, flags=re.MULTILINE)
html = re.sub(r"((?:<li>.+</li>\n?)+)", r"<ul>\1</ul>", html)
html = re.sub(r"^---$", "<hr>", html, flags=re.MULTILINE)
lines = []
for line in html.split("\n"):
    stripped = line.strip()
    if stripped and not re.match(r"<(h[1-3]|li|ul|/ul|hr)", stripped):
        lines.append(f"<p>{line}</p>")
    else:
        lines.append(line)
html = "\n".join(lines)

body_html = (
    '<div style="font-family: -apple-system, BlinkMacSystemFont, \'Segoe UI\', sans-serif; '
    f'max-width: 600px; margin: 0 auto; padding: 20px; color: #1c1c1c;">{html}</div>'
)

# Send via Resend
payload = json.dumps({
    "from": "Garmin Daily Recap <market@joseandgoose.com>",
    "to": NOTIFICATION_EMAIL,
    "subject": f"\U0001f3c3 Your Garmin Health Recap \u2014 {date_str}",
    "html": body_html,
}).encode()

req = urllib.request.Request(
    "https://api.resend.com/emails",
    data=payload,
    headers={
        "Authorization": f"Bearer {RESEND_API_KEY}",
        "Content-Type": "application/json",
        "User-Agent": "garmin-recap/1.0",
    },
)

try:
    with urllib.request.urlopen(req) as resp:
        result = json.loads(resp.read())
        print(f"\u2705 Email sent to {NOTIFICATION_EMAIL}")
        print(f"   Message ID: {result.get('id')}")
except urllib.error.HTTPError as e:
    print(f"Resend API error: {e.code} {e.read().decode()}")
    sys.exit(1)
