#!/bin/bash
# Garmin Daily Health Recap Runner
# Runs at 7am via cron on alienware (Linux). No GUI notifications.

export PATH="/home/jd/.local/bin:/usr/local/bin:/usr/bin:/bin:$PATH"

BASE="$HOME/.garmin-recap"
TODAY=$(date +%Y-%m-%d)
LOG_DIR="$BASE/logs"
RECAP_DIR="$BASE/recaps"
mkdir -p "$LOG_DIR" "$RECAP_DIR"
LOG="$LOG_DIR/recap-$TODAY.log"

echo "[$(date)] ===== Garmin Recap Started =====" >> "$LOG"

# Step 1: Fetch raw data from Garmin Connect (with retry on network failure)
MAX_ATTEMPTS=5
RETRY_DELAY=60
ATTEMPT=1

while [ $ATTEMPT -le $MAX_ATTEMPTS ]; do
  echo "[$(date)] Fetching data from Garmin (attempt $ATTEMPT/$MAX_ATTEMPTS)..." >> "$LOG"
  python3 "$BASE/garmin_fetch.py" >> "$LOG" 2>&1
  FETCH_EXIT=$?
  if [ $FETCH_EXIT -eq 0 ]; then
    break
  fi
  if [ $FETCH_EXIT -eq 2 ]; then
    echo "[$(date)] ERROR: Garmin SSO rate-limited (429). Aborting." >> "$LOG"
    exit 2
  fi
  if [ $ATTEMPT -eq $MAX_ATTEMPTS ]; then
    echo "[$(date)] ERROR: Garmin fetch failed after $MAX_ATTEMPTS attempts. Aborting." >> "$LOG"
    exit 1
  fi
  echo "[$(date)] Fetch failed. Retrying in ${RETRY_DELAY}s..." >> "$LOG"
  sleep $RETRY_DELAY
  ATTEMPT=$((ATTEMPT + 1))
done

# Step 2: Slim the raw JSON
echo "[$(date)] Slimming data..." >> "$LOG"
python3 "$BASE/garmin_slim.py" >> "$LOG" 2>&1

if [ $? -ne 0 ]; then
  echo "[$(date)] ERROR: Slim step failed. Aborting." >> "$LOG"
  exit 1
fi

echo "[$(date)] Generating recap with Claude..." >> "$LOG"

# Step 3: Build prompt and run Claude
RAW_DATA=$(cat "$BASE/garmin_summary.json")
RULES=$(cat "$BASE/prompt.md")
PROMPT_FILE=$(mktemp /tmp/garmin-prompt-XXXXXX.txt)
RECAP_FILE="$RECAP_DIR/garmin-recap-$TODAY.md"

cat > "$PROMPT_FILE" << PROMPT
You are generating a health recap from pre-fetched Garmin data.
DO NOT use any browser tools. DO NOT navigate to any websites. DO NOT read any files.
All data you need is embedded below. Your ONLY task is to format the recap and write it to disk.

TODAY'S DATE: $TODAY
OUTPUT FILE: $RECAP_FILE

RAW GARMIN DATA (JSON):
$RAW_DATA

$RULES
PROMPT

env -u CLAUDECODE claude -p "$(cat "$PROMPT_FILE")" --allowedTools "Write" >> "$LOG" 2>&1
STATUS=$?
rm -f "$PROMPT_FILE"

if [ $STATUS -eq 0 ]; then
  echo "[$(date)] Recap saved to $RECAP_DIR/garmin-recap-$TODAY.md" >> "$LOG"

  # Step 4: Send email via Resend
  echo "[$(date)] Sending email..." >> "$LOG"
  python3 "$BASE/send_email.py" "$RECAP_FILE" >> "$LOG" 2>&1
  if [ $? -eq 0 ]; then
    echo "[$(date)] Email sent successfully" >> "$LOG"
  else
    echo "[$(date)] WARNING: Email failed to send (recap still saved)" >> "$LOG"
  fi

  echo "[$(date)] ===== Done =====" >> "$LOG"
else
  echo "[$(date)] ERROR: Claude step failed. Check log." >> "$LOG"
  exit 1
fi
