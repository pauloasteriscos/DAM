# CI - Quality Gate

## Purpose

Permanent continuous-integration quality gate for DailyTalk.

The workflow validates the API and Flutter application on every push to `main`,
every pull request targeting `main`, and on manual execution.

Workflow:

```text
.github/workflows/ci-quality-gate.yml
```

GitHub Actions display name:

```text
CI - Quality Gate
```

## Jobs

### API - Typecheck, Security & Tests

Validates:

```text
TypeScript typecheck
API integration tests
DPoP / JWS / JWE security tests
D1 migration tests
npm dependency audit
published 0001_baseline.sql immutability
```

The current API test aggregation is executed through:

```text
npm run test:phase0
```

The command name is historical; the workflow itself is permanent. It may later
be exposed through a stable `test:ci` alias as the test suite expands.

### Flutter - Analyze & Tests

Validates:

```text
Flutter dependencies
flutter analyze
Flutter automated tests
```

## Triggers

```text
push -> main
pull_request -> main
workflow_dispatch
```

## Security

The workflow has read-only repository permissions:

```yaml
permissions:
  contents: read
```

Checkout credentials are not persisted.

The quality gate:

```text
does not deploy
does not run remote D1 migrations
does not receive production secrets
does not publish mobile builds
```

## Naming convention for workflows

Use functional names rather than project-phase names.

```text
CI - Quality Gate
Build - iOS Release
Release - iOS TestFlight
Deploy - API Production
Deploy - Web Production
```

File names follow the same convention:

```text
ci-quality-gate.yml
build-ios-release.yml
release-ios-testflight.yml
deploy-api-production.yml
deploy-web-production.yml
```

## Historical Phase 0 material

Phase 0 documents and scripts remain as historical evidence where appropriate,
but the permanent CI workflow is not named after Phase 0.
