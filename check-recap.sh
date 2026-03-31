#!/bin/bash
# Runs at 8am daily. If no recap was generated for today, sends an alert email.

BASE="$HOME/.garmin-recap"
TODAY=$(date +%Y-%m-%d)
RECAP_FILE="$BASE/recaps/garmin-recap-$TODAY.md"

if [ -f "$RECAP_FILE" ]; then
  exit 0  # All good
fi

# Load Resend key
RESEND_API_KEY=""
ENV_FILE="$BASE/.env.local"
if [ -f "$ENV_FILE" ]; then
  RESEND_API_KEY=$(grep RESEND_API_KEY "$ENV_FILE" | cut -d= -f2 | tr -d ' ')
fi

if [ -z "$RESEND_API_KEY" ]; then
  echo "[$(date)] ERROR: RESEND_API_KEY not found, cannot send alert" >&2
  exit 1
fi

LOG_SNIPPET=""
LOG_FILE="$BASE/logs/recap-$TODAY.log"
if [ -f "$LOG_FILE" ]; then
  LOG_SNIPPET=$(tail -20 "$LOG_FILE" | sed 's/"/\\"/g' | tr '\n' '|' | sed 's/|/\\n/g')
fi

curl -s -X POST https://api.resend.com/emails \
  -H "Authorization: Bearer $RESEND_API_KEY" \
  -H "Content-Type: application/json" \
  -d "{
    \"from\": \"Alienware Monitor <market@joseandgoose.com>\",
    \"to\": \"odagledesoj@gmail.com\",
    \"subject\": \"\u26a0\ufe0f Garmin Recap Failed \u2014 $TODAY\",
    \"html\": \"<p>No recap file was found for <strong>$TODAY</strong> by 8am.</p><p>The 7am cron job may have failed.</p><pre style='background:#f8f8f8;padding:12px;font-size:12px'>$LOG_SNIPPET</pre><p>SSH in to investigate: <code>ssh alienware</code><br>Log: <code>cat $LOG_FILE</code></p>\"
  }" > /dev/null

echo "[$(date)] Alert sent: Garmin recap missing for $TODAY"
