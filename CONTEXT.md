# realm/SwiftLint context
> refreshed 2026-09-09 | upstream default: main @ a510662ca

## Identity & policies
- upstream: realm/SwiftLint, default branch main, primary language Swift, English-first (yes)
- CLA/DCO: none (no CLA bot, no DCO, no contributor signup)
- AI-assisted PR policy: allowed (CONTRIBUTING even suggests asking an AI for release names; no AI-PR ban)
- signed commits required: no
- PR template: none (no .github/PULL_REQUEST_TEMPLATE.md)
- external tracker: github

## Conventions (verified from merged PRs)
- branch naming: mostly plain kebab-case description (example-macro, unused-param, windows-runner, docs-megalinter); occasional fix-/codex-/copilot- prefixes. Use plain kebab-case.
- commit style: squash-merge; CHANGELOG.md entry required for user-facing changes (hard-wrapped 80 cols, 2 trailing spaces)
- test command: `swift test` (SPM on macOS/Linux); also xcodebuild, make bazel_test, make docker_test
- CI: Azure Pipelines + Buildkite (macOS) + some GitHub Actions; external providers not connected to fork

## Maintainer picture
- active maintainers; healthy external-contributor merge cadence (many non-maintainer PRs merged Jul-Aug 2026)

## Issue-area health
- 9 open good-first-issue/help-wanted issues

## Gap ledger (dedupe — READ FIRST, never re-pick)
- `2026-09-02` self-found broken links (README Apple doc URLs, CHANGELOG `ttps://` x2, `#issue_number` placeholder) — outcome pr-opened (fork PR #1) — lesson: 5 verified broken-link fixes bundled into one docs PR
- `2026-09-08` self-found typos (10 CHANGELOG, 2 README Xcode defaults key, 1 Configuration.swift doc comment, 1 MarkdownReporter description) — outcome pr-opened (fork PR #5) — lesson: 14 meaning-preserving typo fixes bundled into one docs+source PR
- `2026-09-09` self-found typos (CONTRIBUTING "to installed", proposal template "you idea", NestingRuleExamples `swich` x2) — outcome pr-opened (fork PR #4) — lesson: 4 typo fixes across 3 files bundled into one docs/comment PR; README/README_CN `IDESkipPackagePluginFingerprintValidatation` covered by parallel PR #5

## Mined gaps (discovered, not yet attempted)
- (none yet)
