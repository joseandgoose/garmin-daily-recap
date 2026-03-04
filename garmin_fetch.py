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

# Load credentials
with open(CONFIG_FILE) as f:
    config = json.load(f)

TODAY = date.today().isoformat()
YESTERDAY = (date.today() - timedelta(days=1)).isoformat()

print(f"Fetching Garmin data for {TODAY}...")

# Login
api = Garmin(config["username"], config["password"])
api.login()

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
safe_fetch("user_summary",    lambda: api.get_user_summary(YESTERDAY))      # yesterday's completed activity
safe_fetch("sleep",           lambda: api.get_sleep_data(YESTERDAY))
safe_fetch("heart_rate",      lambda: api.get_heart_rates(TODAY))
safe_fetch("rhr",             lambda: api.get_rhr_day(TODAY))
safe_fetch("stress",          lambda: api.get_stress_data(TODAY))
safe_fetch("body_battery",    lambda: api.get_body_battery(TODAY, TODAY))
safe_fetch("training_status", lambda: api.get_training_status(TODAY))       # fix: date arg instead of display_name
safe_fetch("training_readiness", lambda: api.get_training_readiness(TODAY)) # alt: readiness score
safe_fetch("fitness_age",     lambda: api.get_fitnessage())                 # fix: corrected method name
safe_fetch("vo2max",          lambda: api.get_max_metrics(TODAY))

# Save
with open(OUTPUT_FILE, "w") as f:
    json.dump(data, f, indent=2, default=str)

print(f"\nSaved raw data to: {OUTPUT_FILE}")
