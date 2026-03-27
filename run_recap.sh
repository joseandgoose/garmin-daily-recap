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

Generate a daily health recap for Jose following these rules exactly, then save it to the output file above.

RULES:
1. OMIT any section where the data is null or missing entirely. Do not show empty sections.
2. If a missing section would improve the health picture, add one line to the Recommendation
   noting what to do (e.g. "Wear your watch to sleep for sleep data tomorrow.").
3. Open with a named Focus Mode: Recovery / Improving Fitness / Losing Weight / Maintenance.
   Drive the choice from the full picture. Prioritize recovery signals (Body Battery,
   elevated RHR, high stress) over fitness signals when both are present.
4. Sleep: only mention areas needing improvement with a specific fix. Skip stages rated Good or Excellent.
5. VO2 Max: lead with what to do to improve it, then state the number.
6. Recommendation: lead with the single highest-value action, with specific numbers.

FORMAT (only include sections with available data):

---
# Daily Health Recap - $TODAY

## Today's Focus: [FOCUS MODE]
[2-3 sentences. Name the focus. State the highest-value action with specific numbers.]

## Body Battery
[SCORE] / 100 - [one sentence on what this means for the day]

## Sleep
[DURATION] - Score [SCORE]/100 ([QUALITY]) - [BEDTIME] to [WAKE]
[Only areas needing improvement + a specific fix.]

## Resting Heart Rate
[VALUE] BPM - 7-day avg: [VALUE] BPM - [one-sentence interpretation]

## Stress
[SCORE] / 100 - [LEVEL].
Scale: 0-25 Resting - 26-50 Low - 51-75 Medium - 76-100 High

## VO2 Max / Training Status / Fitness Age
[Lead with what to do. Then: VO2 value + rating, Training Status, Fitness Age vs actual vs target.]

## Yesterday's Activity
Steps: [VALUE] / [GOAL] - Intensity Minutes: [VALUE] / [GOAL] - Calories: [VALUE]

---
Data from Garmin Connect - $TODAY

Write the completed recap to: $RECAP_FILE
PROMPT

env -u CLAUDECODE claude -p "$(cat "$PROMPT_FILE")" --allowedTools "Write" >> "$LOG" 2>&1
STATUS=$?
rm -f "$PROMPT_FILE"

if [ $STATUS -eq 0 ]; then
  echo "[$(date)] Recap saved to $RECAP_DIR/garmin-recap-$TODAY.md" >> "$LOG"

  # Step 4: Send email via Resend
  echo "[$(date)] Sending email..." >> "$LOG"
  node "$BASE/send-email.js" "$RECAP_FILE" >> "$LOG" 2>&1
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
