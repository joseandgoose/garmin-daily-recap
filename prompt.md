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
# Daily Health Recap - [DATE]

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
Data from Garmin Connect - [DATE]

Write the completed recap to the output file specified above.
