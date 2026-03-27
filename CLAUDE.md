# Garmin Recap — Claude Code Project Rules

## Project Overview
Garmin Recap is a daily health automation running on the Alienware machine. It fetches health metrics from Garmin Connect each morning, slims the raw JSON, generates a plain-English recap via Claude CLI, and emails it via Resend. Changes are tracked in both `CHANGELOG.md` and `chart.html`, which must always stay in sync.

## Auth — Important
Garmin Connect auth uses garth OAuth tokens saved at `.garth_tokens/`. Do NOT change the login flow to use raw credentials daily — this triggers SSO rate-limits. If tokens are missing or expired, re-seed from Mac using `garmin_seed_tokens.py` (uses browser User-Agent to bypass IP blocks). Exit code 2 from `garmin_fetch.py` means 429 rate-limited — never retry immediately.

## Version Control Rules
- Every session that ships a change must end with a commit and push
- `CHANGELOG.md` and `chart.html` must always be updated together in the same commit as the code change
- Commit messages follow the format: `type: short description` (types: feat, fix, chore, docs, refactor)
- Version numbers follow semver: patch (x.x.1) for fixes, minor (x.1.0) for new features

## Session Wrap-Up
At the end of every session where changes were made, always:
1. Summarize what changed in 2–4 bullets
2. Append a new entry to `CHANGELOG.md` with version, date, and bullet summary
3. Update `chart.html` with a matching note-card entry (same version and date)
4. Stage all modified files, commit, and push to origin
5. Show `git log --oneline` to confirm the commit landed

## Rollback Reference
To revert to any prior state: `git log --oneline` to find the commit hash, then `git checkout <hash>` to inspect or `git revert <hash>` to undo cleanly.
