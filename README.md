# Garmin Daily Recap

A local automation that fetches Garmin Connect health metrics each morning and generates a plain-English daily recap using Claude AI.

Built with Python, launchd (Mac scheduler), and the Claude CLI.

## What it does

1. **Fetches** sleep, heart rate, stress, body battery, steps, and training data from Garmin Connect
2. **Slims** the raw JSON (~250KB) down to only the fields needed (~3KB)
3. **Generates** a readable daily recap via Claude CLI and emails it via Resend

Runs automatically every morning via a launchd agent.

## Setup

### 1. Install dependencies

```bash
pip install garminconnect
npm install
```

### 2. Configure credentials

```bash
cp garmin_config.example.json .garmin_config.json
```

Edit `.garmin_config.json` with your Garmin Connect username and password.

### 3. Run manually

```bash
python3 garmin_fetch.py   # fetch raw data from Garmin Connect
python3 garmin_slim.py    # slim to summary JSON
```

Then pipe `garmin_summary.json` into Claude CLI for the recap.

## Tools used

- [garminconnect](https://github.com/cyberjunky/python-garminconnect) — unofficial Garmin Connect Python API
- [Claude CLI](https://claude.ai/code) — AI recap generation
- [Resend](https://resend.com) — email delivery
- launchd — Mac-native scheduler (runs daily at 7am)

## Built by

[Jose Delgado](https://joseandgoose.com) · Read the [build case study](https://joseandgoose.com/writing/how-i-automated-garmin-recaps)
