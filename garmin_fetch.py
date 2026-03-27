#!/usr/bin/env python3
"""
Garmin Daily Data Fetcher
Fetches health metrics from Garmin Connect and saves raw JSON.
Run this before the Claude recap step.
"""

import json
import os
import subprocess
import sys
from datetime import date, timedelta

# Install garminconnect if missing
try:
    from garminconnect import Garmin
except ImportError:
    print("Installing garminconnect...")
    subprocess.check_call([sys.executable, "-m", "pip", "install", "garminconnect", "-q"])
    from garminconnect import Garmin

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
CONFIG_FILE = os.path.join(BASE_DIR, ".garmin_config.json")
OUTPUT_FILE = os.path.join(BASE_DIR, "garmin_raw_data.json")
TOKENSTORE  = os.path.join(BASE_DIR, ".garth_tokens")

# Load credentials
with open(CONFIG_FILE) as f:
    config = json.load(f)

TODAY = date.today().isoformat()
YESTERDAY = (date.today() - timedelta(days=1)).isoformat()

print(f"Fetching Garmin data for {TODAY}...")

# Login — reuse saved OAuth tokens when available to avoid SSO rate limits.
# Exit code 2 = rate-limited (caller should NOT retry; wait hours before trying again).
api = Garmin(config["username"], config["password"])
try:
    api.login(tokenstore=TOKENSTORE)
    print("  Logged in via saved tokens")
except Exception as e:
    if "429" in str(e):
        print(f"  ERROR: Garmin SSO rate-limited (429). Do NOT retry — wait several hours.")
        sys.exit(2)
    print("  No valid tokens found — logging in with credentials...")
    try:
        api.login()
    except Exception as e2:
        if "429" in str(e2):
            print(f"  ERROR: Garmin SSO rate-limited (429). Do NOT retry — wait several hours.")
            sys.exit(2)
        raise
    api.garth.dump(TOKENSTORE)
    print("  Tokens saved for future runs")

data = {"date": TODAY, "yesterday": YESTERDAY, "metrics": {}}

def safe_fetch(name, fn):
    try:
        result = fn()
        data["metrics"][name] = result
        print(f"  ✓ {name}")
    except Exception as e:
        data["metrics"][name] = None
        print(f"  ✗ {name}: {e}")

# Fetch each metric
safe_fetch("user_summary",    lambda: api.get_user_summary(YESTERDAY))
def fetch_sleep_most_recent():
    d = api.get_sleep_data(TODAY)
    if (d or {}).get("dailySleepDTO", {}).get("sleepTimeSeconds"):
        return d
    return api.get_sleep_data(YESTERDAY)
safe_fetch("sleep", fetch_sleep_most_recent)
safe_fetch("heart_rate",         lambda: api.get_heart_rates(TODAY))
safe_fetch("rhr",                lambda: api.get_rhr_day(TODAY))
safe_fetch("stress",             lambda: api.get_stress_data(TODAY))
safe_fetch("body_battery",       lambda: api.get_body_battery(TODAY, TODAY))
safe_fetch("training_status",    lambda: api.get_training_status(TODAY))
safe_fetch("training_readiness", lambda: api.get_training_readiness(TODAY))
safe_fetch("fitness_age",        lambda: api.get_fitnessage())
safe_fetch("vo2max",             lambda: api.get_max_metrics(TODAY))

# Save
with open(OUTPUT_FILE, "w") as f:
    json.dump(data, f, indent=2, default=str)

print(f"\nSaved raw data to: {OUTPUT_FILE}")
