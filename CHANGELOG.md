# Changelog

## 1.1.0 - 2026-10-23

- Added `Integration_Log__c` and a Platform Event subscriber trigger, so every final integration failure is stored for reporting and alerting.
- Added an OpenAPI 3 contract for the mock API, contract tests that check the server against it, OpenAPI linting in CI, and a Docker Compose file.
- Added Dependabot and a security policy.

## 1.0.0 - 2026-10-23

- Core banking client with Named Credential, retries, correlation IDs, Platform Event errors, Flow/agent invocable action, Dockerized mock API and CI.
