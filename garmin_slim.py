#!/usr/bin/env python3
"""
Slim the raw Garmin JSON down to only the fields needed for the daily recap.
Drops all time-series arrays (sleepMovement, heartRateValues, etc.)
and metadata fields, reducing ~250KB to ~3KB.
"""

import json
import os
from datetime import datetime

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
RAW_FILE = os.path.join(BASE_DIR, "garmin_raw_data.json")
SLIM_FILE = os.path.join(BASE_DIR, "garmin_summary.json")


def epoch_ms_to_local_str(ms):
    """
    Garmin 'local' timestamps are epoch-ms where the raw seconds value,
    when read as UTC, gives the local wall-clock time. So utcfromtimestamp
    yields the correct local HH:MM directly.
    """
    if ms is None:
        return None
    try:
        return datetime.utcfromtimestamp(ms / 1000).strftime("%-I:%M %p")
    except Exception:
        return None


def seconds_to_hm(s):
    if s is None:
        return None
    return f"{s // 3600}h {(s % 3600) // 60:02d}m"


with open(RAW_FILE) as f:
    raw = json.load(f)

m = raw.get("metrics", {})
us = m.get("user_summary") or {}
sleep = m.get("sleep") or {}
dto = sleep.get("dailySleepDTO") or {}
scores = dto.get("sleepScores") or {}


def first_device(nested):
    """Extract the first device-keyed value from training_status sub-dicts."""
    if not nested:
        return {}
    return next(iter(nested.values()), {})


ts = m.get("training_status") or {}
ts_status = first_device((ts.get("mostRecentTrainingStatus") or {}).get("latestTrainingStatusData"))
ts_load   = first_device((ts.get("mostRecentTrainingLoadBalance") or {}).get("metricsTrainingLoadBalanceDTOMap"))
ts_vo2    = (ts.get("mostRecentVO2Max") or {}).get("generic") or {}

slim = {
    "date": raw.get("date"),
    "yesterday": raw.get("yesterday"),

    "body_battery": {
        "at_wake": us.get("bodyBatteryAtWakeTime"),
        "current": us.get("bodyBatteryMostRecentValue"),
        "high": us.get("bodyBatteryHighestValue"),
        "low": us.get("bodyBatteryLowestValue"),
        "charged": us.get("bodyBatteryChargedValue"),
        "drained": us.get("bodyBatteryDrainedValue"),
        "charged_during_sleep": us.get("bodyBatteryDuringSleep"),
    },

    "sleep": {
        "duration": seconds_to_hm(dto.get("sleepTimeSeconds")),
        "bedtime": epoch_ms_to_local_str(dto.get("sleepStartTimestampLocal")),
        "wake_time": epoch_ms_to_local_str(dto.get("sleepEndTimestampLocal")),
        "score": (scores.get("overall") or {}).get("value"),
        "score_quality": (scores.get("overall") or {}).get("qualifierKey"),
        "feedback": dto.get("sleepScoreFeedback"),
        "insight": dto.get("sleepScoreInsight"),
        "deep_seconds": dto.get("deepSleepSeconds"),
        "light_seconds": dto.get("lightSleepSeconds"),
        "rem_seconds": dto.get("remSleepSeconds"),
        "awake_seconds": dto.get("awakeSleepSeconds"),
        "awake_count": dto.get("awakeCount"),
        "avg_stress": dto.get("avgSleepStress"),
        "avg_spo2": dto.get("averageSpO2Value"),
        "lowest_spo2": dto.get("lowestSpO2Value"),
        "restless_moments": sleep.get("restlessMomentsCount"),
        "stage_ratings": {
            "total_duration": (scores.get("totalDuration") or {}).get("qualifierKey"),
            "rem":            (scores.get("remPercentage") or {}).get("qualifierKey"),
            "light":          (scores.get("lightPercentage") or {}).get("qualifierKey"),
            "deep":           (scores.get("deepPercentage") or {}).get("qualifierKey"),
            "stress":         (scores.get("stress") or {}).get("qualifierKey"),
            "awake_count":    (scores.get("awakeCount") or {}).get("qualifierKey"),
            "restlessness":   (scores.get("restlessness") or {}).get("qualifierKey"),
        },
    },

    "heart_rate": {
        "resting": us.get("restingHeartRate"),
        "seven_day_avg": us.get("lastSevenDaysAvgRestingHeartRate"),
        "daily_min": us.get("minHeartRate"),
        "daily_max": us.get("maxHeartRate"),
    },

    "stress": {
        "average": us.get("averageStressLevel"),
        "max": us.get("maxStressLevel"),
        "qualifier": us.get("stressQualifier"),
        "low_pct": us.get("lowStressPercentage"),
        "medium_pct": us.get("mediumStressPercentage"),
        "high_pct": us.get("highStressPercentage"),
        "rest_pct": us.get("restStressPercentage"),
    },

    "training": {
        "vo2max": ts_vo2.get("vo2MaxValue"),
        "vo2max_precise": ts_vo2.get("vo2MaxPreciseValue"),
        "status_phrase": ts_status.get("trainingStatusFeedbackPhrase"),
        "weekly_load": ts_status.get("weeklyTrainingLoad"),
        "load_min": ts_status.get("loadTunnelMin"),
        "load_max": ts_status.get("loadTunnelMax"),
        "sport": ts_status.get("sport"),
        "load_balance_phrase": ts_load.get("trainingBalanceFeedbackPhrase"),
        "aerobic_low_load": ts_load.get("monthlyLoadAerobicLow"),
        "aerobic_high_load": ts_load.get("monthlyLoadAerobicHigh"),
        "anaerobic_load": ts_load.get("monthlyLoadAnaerobic"),
    },

    "activity": {
        "steps": us.get("totalSteps"),
        "steps_goal": us.get("dailyStepGoal"),
        "intensity_moderate_min": us.get("moderateIntensityMinutes"),
        "intensity_vigorous_min": us.get("vigorousIntensityMinutes"),
        "intensity_goal_min": us.get("intensityMinutesGoal"),
        "calories_total": us.get("totalKilocalories"),
        "calories_active": us.get("activeKilocalories"),
        "calories_bmr": us.get("bmrKilocalories"),
        "spo2_avg": us.get("averageSpo2"),
        "spo2_lowest": us.get("lowestSpo2"),
        "respiration_avg": us.get("avgWakingRespirationValue"),
    },
}

with open(SLIM_FILE, "w") as f:
    json.dump(slim, f, indent=2, default=str)

raw_size = os.path.getsize(RAW_FILE)
slim_size = os.path.getsize(SLIM_FILE)
print(f"  raw:  {raw_size:,} bytes")
print(f"  slim: {slim_size:,} bytes ({100*slim_size//raw_size}% of original)")
