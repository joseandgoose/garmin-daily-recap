#!/bin/zsh
# Garmin Daily Health Recap Runner
# Runs at 7am via launchd. Fetches Garmin data then calls Claude to generate recap.

BASE="$HOME/.garmin-recap"
TODAY=$(date +%Y-%m-%d)
LOG_DIR="$BASE/logs"
RECAP_DIR="$BASE/recaps"
mkdir -p "$LOG_DIR" "$RECAP_DIR"
LOG="$LOG_DIR/recap-$TODAY.log"

echo "[$(date)] ===== Garmin Recap Started =====" >> "$LOG"

# Step 1: Fetch raw data from Garmin Connect
echo "[$(date)] Fetching data from Garmin..." >> "$LOG"
python3 "$BASE/garmin_fetch.py" >> "$LOG" 2>&1

if [ $? -ne 0 ]; then
  echo "[$(date)] ERROR: Garmin fetch failed. Aborting." >> "$LOG"
  exit 1
fi

# Step 2: Slim the raw JSON down to only the fields needed for the recap
echo "[$(date)] Slimming data..." >> "$LOG"
python3 "$BASE/garmin_slim.py" >> "$LOG" 2>&1

if [ $? -ne 0 ]; then
  echo "[$(date)] ERROR: Slim step failed. Aborting." >> "$LOG"
  exit 1
fi

echo "[$(date)] Generating recap with Claude..." >> "$LOG"

# Step 3: Read slimmed JSON and inject into prompt
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
# 🏃 Daily Health Recap — $TODAY

## 💡 Today's Focus: **[FOCUS MODE]**
[2-3 sentences. Name the focus. State the highest-value action with specific numbers.
If recovery and fitness signals conflict, briefly explain the tradeoff.]

## 🔋 Body Battery
**[SCORE] / 100** — [one sentence on what this means for the day]

## 😴 Sleep
**[DURATION] · Score [SCORE]/100 ([QUALITY])** · [BEDTIME] → [WAKE]
[Only areas needing improvement + a specific fix. Skip if all stages are rated Good or Excellent.]

## ❤️ Resting Heart Rate
**[VALUE] BPM** · 7-day avg: [VALUE] BPM — [one-sentence interpretation]

## 🧠 Stress
**[SCORE] / 100 — [LEVEL].**
Scale: 0–25 Resting · 26–50 Low · 51–75 Medium · 76–100 High

## 🫁 VO₂ Max · Training Status · Fitness Age
[Lead with what to do. Then: VO2 value + rating, Training Status + Load Focus,
Fitness Age vs actual vs target.]

## 📊 Yesterday's Activity
**Steps:** [VALUE] / [GOAL] · **Intensity Minutes:** [VALUE] / [GOAL] · **Calories:** [VALUE] ([active] active · [resting] resting)

---
*Data from Garmin Connect · $TODAY*

Write the completed recap to: $RECAP_FILE
PROMPT

# Step 3: Run Claude with the prompt (data is embedded — no browser or file access needed)
# --allowedTools pre-approves the Write tool so launchd runs unattended at 7am
claude -p "$(cat "$PROMPT_FILE")" --allowedTools "Write" >> "$LOG" 2>&1
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

  # Step 5: Show macOS popup — clicking "Open in Terminal" launches Terminal with the recap
  osascript << APPLESCRIPT >> "$LOG" 2>&1
try
  set cmd to "cat $RECAP_FILE"
  set dialogResult to display dialog "Your Garmin health recap for $TODAY is ready." & return & return & "To read it, run:" & return & cmd with title "🏃 Garmin Daily Recap" buttons {"Dismiss", "Open in Terminal"} default button "Open in Terminal"
  if button returned of dialogResult is "Open in Terminal" then
    tell application "Terminal"
      activate
      do script cmd
    end tell
  end if
end try
APPLESCRIPT

else
  echo "[$(date)] ERROR: Claude step failed. Check log." >> "$LOG"
  exit 1
fi
