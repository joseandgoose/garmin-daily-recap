# Changelog — Garmin Recap

## v1.2.0 — 2026-03-31

### Changed
- Replaced `send-email.js` (Node.js / Resend SDK) with `send_email.py` (Python stdlib). Node runtime fully removed.
- Extracted Claude prompt from `run_recap.sh` into standalone `prompt.md` for easier iteration.
- Consolidated Garmin credentials from `.garmin_config.json` into `.env.local` (single secrets file).
- Emails now sent from `market@joseandgoose.com` instead of Resend sandbox address.

### Fixed
- `fitness_age` metric: updated API call from `get_fitnessage()` to `get_fitnessage_data(TODAY)` — all 10 metrics now fetching.

## v1.1.0 — 2026-03-27

### Fixed
- Garmin SSO rate-limiting: added OAuth token persistence via garth (`.garth_tokens/`). Daily runs now reuse saved tokens instead of logging in with credentials, eliminating SSO calls entirely after first seed.
- Added exit code 2 to `garmin_fetch.py` on 429 responses — clearly signals rate-limit vs. other failures.
- Patched `run_recap.sh` to abort immediately on exit code 2 (no retries on rate-limit, which previously deepened the block).
- Seeded initial tokens from Mac using a browser User-Agent to bypass the account-level SSO block.

## v1.0.0 — 2026-03-22

### Added
- Initial release: daily Garmin health recap automation.
- `garmin_fetch.py` — fetches metrics from Garmin Connect (steps, sleep, HRV, stress, body battery, VO2 max, training status).
- `garmin_slim.py` — slims raw JSON for Claude prompt.
- `run_recap.sh` — orchestrates fetch → slim → Claude recap → email.
- `send-email.js` — sends recap via Resend to personal Gmail.
- `check-recap.sh` — 8am failure alert if recap file is missing.
- Cron jobs: 7am daily fetch/recap, 8am failure check.
