# Development progress

The existing game baseline is `923657262cd335fefee9126df61dd0fff4b93321`.
The separate rebuild remains paused. C0 changes are on the isolated
`codex/c0-save-recovery` branch and have not been merged into main or deployed.

The untouched baseline passed `tools/test.sh` and `tools/smoke.sh`. The test
suite deliberately logs a future-schema rejection and reports shutdown leaks.
An independent regression reproduced the invalid-save fallback on the baseline.
The focused save guards, staged-write tests, schema-0-to-3 fixtures and actual
schema-1/3 world-load lab pass locally. The test suite and smoke check also pass.
The staged-write tests include a simulated partial pending file and an actual
failed backup promotion. See `docs/orchestration/reports/codex-c0-save-safety.md`
for commands, observed warnings and limits. Browser/IDBFS and mobile filesystem
behavior remain unverified, so this is not a production release approval.

After C0, material fusion requires an approved rule version and compatibility
fixtures; its formulas and automatic migration are not authorized by C0.
