# Void CI Templates

Reusable GitHub Actions workflows for full-stack AWS serverless projects. Extracts common CI/CD patterns into callable workflows so you can build a complete pipeline in a few lines.

Designed for projects with a Python backend (Lambda), a Node.js frontend (S3 + CloudFront), and Terraform infrastructure, but each workflow can be used independently.

## Quick Start

Reference any workflow from your project's GitHub Actions:

```yaml
name: CI/CD

on:
  push:
    branches: [main]
  pull_request:
    branches: [main]

jobs:
  test-backend:
    uses: voidreamer/ci-templates/.github/workflows/test-python.yml@main
    with:
      postgres: true

  test-frontend:
    uses: voidreamer/ci-templates/.github/workflows/test-node.yml@main

  deploy:
    needs: [test-backend, test-frontend]
    if: github.event_name == 'push'
    uses: voidreamer/ci-templates/.github/workflows/deploy-aws.yml@main
    with:
      environment: production
      terraform-state-key: prod/terraform.tfstate
      app-name: MyApp
    secrets:
      AWS_ACCESS_KEY_ID: ${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
```

## Available Workflows

| Workflow | Description | Key Inputs |
|----------|-------------|------------|
| `deploy-aws.yml` | Full AWS deploy: Terraform + Lambda + S3 + CloudFront | `environment`, `terraform-state-key`, `app-name` |
| `test-python.yml` | Python backend tests with optional PostgreSQL | `python-version`, `postgres`, `test-command` |
| `test-node.yml` | Node.js frontend tests, lint, and build | `node-version`, `test-command`, `build` |
| `notify-telegram.yml` | Telegram deploy notifications | `app-name`, `environment`, `status` |
| `translate-i18n.yml` | DeepL auto-translation for i18n locales | `locales-path`, `source-lang` |
| `lighthouse.yml` | Lighthouse CI performance audit | `working-directory`, `config-path` |
| `android-build.yml` | Capacitor Android debug APK build | `node-version`, `java-version` |
| `ios-build.yml` | Capacitor iOS simulator build | `node-version`, `working-directory` |

## Workflow Details

### deploy-aws.yml

Full deployment pipeline for AWS serverless projects. Runs Terraform to provision infrastructure, deploys the Python backend to Lambda, builds and deploys the frontend to S3, invalidates CloudFront, runs a health check, and sends a Telegram notification.

Features:
- Concurrency group prevents parallel deploys to the same environment
- Handles Terraform variable injection via the `TERRAFORM_VARS` secret
- Handles Vite environment variables via the `VITE_ENV_VARS` secret
- Optional backend deployment (set `backend-type: none` for frontend-only projects)
- Optional Alembic migrations
- S3 sync with proper cache headers (immutable for hashed assets, no-cache for index.html)
- Health check with retries (non-blocking)
- Telegram notifications on success or failure

Required inputs:
- `environment` (string): staging or prod
- `terraform-state-key` (string): S3 key for Terraform state
- `app-name` (string): used in notifications

Required secrets:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`

Optional secrets:
- `TERRAFORM_VARS`: newline-separated `TF_VAR_xxx=value` pairs
- `VITE_ENV_VARS`: newline-separated `VITE_xxx=value` pairs for frontend build
- `DATABASE_URL`: for Alembic migrations
- `TELEGRAM_BOT_TOKEN` and `TELEGRAM_CHAT_ID`: for notifications

### test-python.yml

Runs Python tests with optional linting (ruff) and PostgreSQL service container.

```yaml
uses: voidreamer/ci-templates/.github/workflows/test-python.yml@main
with:
  python-version: "3.11"
  working-directory: backend
  postgres: true
  lint: true
  test-command: "python -m pytest tests/ -v --tb=short"
```

### test-node.yml

Runs Node.js tests with optional linting and build step. Can upload build artifacts.

```yaml
uses: voidreamer/ci-templates/.github/workflows/test-node.yml@main
with:
  node-version: "22"
  working-directory: frontend
  lint: true
  build: true
  upload-build: false
```

### notify-telegram.yml

Standalone Telegram notification workflow. Useful when you want notifications without the full deploy workflow.

```yaml
uses: voidreamer/ci-templates/.github/workflows/notify-telegram.yml@main
with:
  app-name: MyApp
  environment: production
  status: success
  url: https://app.example.com
secrets:
  TELEGRAM_BOT_TOKEN: ${{ secrets.TELEGRAM_BOT_TOKEN }}
  TELEGRAM_CHAT_ID: ${{ secrets.TELEGRAM_CHAT_ID }}
```

### translate-i18n.yml

Runs a DeepL translation script and auto-commits new translations. Expects a Node.js script at the configured `script-path` that reads source locale files and writes translated versions.

```yaml
uses: voidreamer/ci-templates/.github/workflows/translate-i18n.yml@main
with:
  locales-path: frontend/public/locales
  source-lang: en
secrets:
  DEEPL_API_KEY: ${{ secrets.DEEPL_API_KEY }}
```

### lighthouse.yml

Runs Lighthouse CI against a built frontend. Requires a `lighthouserc.json` config file.

```yaml
uses: voidreamer/ci-templates/.github/workflows/lighthouse.yml@main
with:
  working-directory: frontend
  config-path: .github/lighthouse/lighthouserc.json
```

### android-build.yml

Builds a Capacitor Android debug APK and uploads it as an artifact.

```yaml
uses: voidreamer/ci-templates/.github/workflows/android-build.yml@main
with:
  java-version: "21"
  app-id: com.example.myapp
```

### ios-build.yml

Builds a Capacitor iOS app for the simulator (unsigned). Runs on macOS.

```yaml
uses: voidreamer/ci-templates/.github/workflows/ios-build.yml@main
with:
  app-id: com.example.myapp
```

## Examples

Complete example pipelines are available in the `examples/` directory:

- `examples/full-stack.yml`: Full pipeline with backend tests, frontend tests, Lighthouse, staging/production deploys, and mobile builds
- `examples/frontend-only.yml`: Frontend-only project with S3 + CloudFront deploy

## Dependabot

A template `dependabot.yml` is available in `dependabot/dependabot.yml`. Copy it to `.github/dependabot.yml` in your project and adjust the directories to match your setup.

## License

MIT. See [LICENSE](LICENSE).
