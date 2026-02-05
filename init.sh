#!/usr/bin/env bash
set -euo pipefail

# ─────────────────────────────────────────────────────────────────
# Void CI Templates - Project Initializer
#
# Usage:
#   curl -sL https://raw.githubusercontent.com/voidreamer/ci-templates/main/init.sh | bash
#   or:
#   bash <(curl -sL https://raw.githubusercontent.com/voidreamer/ci-templates/main/init.sh)
#   or locally:
#   ./init.sh
# ─────────────────────────────────────────────────────────────────

TEMPLATES_REF="v1"  # Change to @main for bleeding edge
TEMPLATES_REPO="voidreamer/ci-templates"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

print_header() {
  echo ""
  echo -e "${BLUE}${BOLD}╔══════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}${BOLD}║   Void CI Templates - Project Setup      ║${NC}"
  echo -e "${BLUE}${BOLD}╚══════════════════════════════════════════╝${NC}"
  echo ""
}

ask() {
  local prompt="$1"
  local default="$2"
  local var_name="$3"
  if [ -n "$default" ]; then
    echo -ne "${CYAN}${prompt}${NC} ${DIM}[${default}]${NC}: "
  else
    echo -ne "${CYAN}${prompt}${NC}: "
  fi
  read -r input
  eval "$var_name='${input:-$default}'"
}

ask_yn() {
  local prompt="$1"
  local default="$2"
  local var_name="$3"
  echo -ne "${CYAN}${prompt}${NC} ${DIM}[${default}]${NC}: "
  read -r input
  input="${input:-$default}"
  if [[ "$input" =~ ^[Yy] ]]; then
    eval "$var_name=true"
  else
    eval "$var_name=false"
  fi
}

choose() {
  local prompt="$1"
  shift
  local options=("$@")
  echo -e "${CYAN}${prompt}${NC}"
  for i in "${!options[@]}"; do
    echo -e "  ${BOLD}$((i+1)))${NC} ${options[$i]}"
  done
  echo -ne "${CYAN}Choice${NC} ${DIM}[1]${NC}: "
  read -r choice
  choice="${choice:-1}"
  echo "${options[$((choice-1))]}"
}

# ─── Collect Info ───────────────────────────────────────────────

print_header

# Check we're in a git repo
if ! git rev-parse --is-inside-work-tree &>/dev/null; then
  echo -e "${RED}Error: Not inside a git repository.${NC}"
  echo "Run this from the root of your project."
  exit 1
fi

PROJECT_ROOT=$(git rev-parse --show-toplevel)
echo -e "${DIM}Project root: ${PROJECT_ROOT}${NC}"
echo ""

# Project type
PROJECT_TYPE=$(choose "What type of project?" \
  "full-stack (Python backend + Node frontend + Terraform)" \
  "frontend-only (Node frontend + S3/CloudFront)" \
  "backend-only (Python backend + Lambda)" \
  "docker (Containerized app)")
echo ""

ask "Application name" "$(basename "$PROJECT_ROOT")" APP_NAME

# Cloud provider (skip for docker - it's cloud-agnostic)
CLOUD_PROVIDER=""
if [[ "$PROJECT_TYPE" != *"docker"* ]]; then
  CLOUD_PROVIDER=$(choose "Cloud provider?" \
    "AWS (Lambda + S3 + CloudFront)" \
    "GCP (Cloud Run + Cloud Storage + CDN)" \
    "Azure (Functions + Blob Storage + CDN)")
  echo ""
fi

# Cloud-specific config
AWS_REGION=""
AWS_ROLE_ARN=""
GCP_PROJECT_ID=""
GCP_REGION=""
GCP_WIF_PROVIDER=""
GCP_SERVICE_ACCOUNT=""
AZURE_SUBSCRIPTION_ID=""
AZURE_TENANT_ID=""
AZURE_CLIENT_ID=""
AZURE_RESOURCE_GROUP=""
AZURE_LOCATION=""
AUTH_METHOD=""

case "$CLOUD_PROVIDER" in
  *"AWS"*)
    ask "AWS region" "ca-central-1" AWS_REGION
    AUTH_METHOD=$(choose "AWS authentication method?" \
      "OIDC (recommended - no static keys)" \
      "Static keys (AWS_ACCESS_KEY_ID / SECRET)")
    echo ""
    if [[ "$AUTH_METHOD" == *"OIDC"* ]]; then
      ask "AWS IAM Role ARN (leave empty to fill later)" "" AWS_ROLE_ARN
    fi
    ;;
  *"GCP"*)
    ask "GCP project ID" "" GCP_PROJECT_ID
    ask "GCP region" "us-central1" GCP_REGION
    AUTH_METHOD=$(choose "GCP authentication method?" \
      "Workload Identity Federation (recommended - no static keys)" \
      "Service Account Key (GCP_SA_KEY secret)")
    echo ""
    if [[ "$AUTH_METHOD" == *"Workload"* ]]; then
      ask "Workload Identity Provider (leave empty to fill later)" "" GCP_WIF_PROVIDER
      ask "Service Account email (leave empty to fill later)" "" GCP_SERVICE_ACCOUNT
    fi
    ;;
  *"Azure"*)
    ask "Azure subscription ID" "" AZURE_SUBSCRIPTION_ID
    ask "Azure resource group" "" AZURE_RESOURCE_GROUP
    ask "Azure location" "canadacentral" AZURE_LOCATION
    AUTH_METHOD=$(choose "Azure authentication method?" \
      "OIDC / Federated Credentials (recommended - no static keys)" \
      "Service Principal credentials (AZURE_CREDENTIALS secret)")
    echo ""
    if [[ "$AUTH_METHOD" == *"OIDC"* ]]; then
      ask "Azure tenant ID (leave empty to fill later)" "" AZURE_TENANT_ID
      ask "Azure client/app ID (leave empty to fill later)" "" AZURE_CLIENT_ID
    fi
    ;;
esac

# Domain
ask "Custom domain (leave empty for none)" "" CUSTOM_DOMAIN

# Notifications
ask_yn "Enable Telegram notifications?" "y" ENABLE_TELEGRAM

# Features based on project type
ENABLE_POSTGRES=false
ENABLE_LIGHTHOUSE=false
ENABLE_MOBILE=false
ENABLE_DOCKER=false
ENABLE_I18N=false

case "$PROJECT_TYPE" in
  *"full-stack"*)
    ask_yn "Enable PostgreSQL for backend tests?" "y" ENABLE_POSTGRES
    ask_yn "Enable Lighthouse performance audits?" "y" ENABLE_LIGHTHOUSE
    ask_yn "Enable mobile builds (iOS/Android)?" "n" ENABLE_MOBILE
    ask_yn "Enable i18n translations (DeepL)?" "n" ENABLE_I18N
    BACKEND_DIR="backend"
    FRONTEND_DIR="frontend"
    ask "Backend directory" "$BACKEND_DIR" BACKEND_DIR
    ask "Frontend directory" "$FRONTEND_DIR" FRONTEND_DIR
    ;;
  *"frontend-only"*)
    ask_yn "Enable Lighthouse performance audits?" "y" ENABLE_LIGHTHOUSE
    ask_yn "Enable mobile builds (iOS/Android)?" "n" ENABLE_MOBILE
    FRONTEND_DIR="."
    ask "Frontend directory" "$FRONTEND_DIR" FRONTEND_DIR
    ;;
  *"backend-only"*)
    ask_yn "Enable PostgreSQL for tests?" "y" ENABLE_POSTGRES
    BACKEND_DIR="backend"
    ask "Backend directory" "$BACKEND_DIR" BACKEND_DIR
    ;;
  *"docker"*)
    ENABLE_DOCKER=true
    ask "Dockerfile path" "Dockerfile" DOCKERFILE_PATH
    ask "Docker context" "." DOCKER_CONTEXT
    ;;
esac

echo ""

# ─── Generate Workflow ──────────────────────────────────────────

mkdir -p "$PROJECT_ROOT/.github/workflows"

CI_FILE="$PROJECT_ROOT/.github/workflows/ci.yml"

# ─── Deploy Job Generators (per cloud) ──────────────────────────

generate_common_domain_inputs() {
  local env_name="$1"
  local domain="${2:-}"
  if [ -n "$domain" ]; then
    local display_domain="$domain"
    if [ "$env_name" = "staging" ]; then
      display_domain="staging-${domain}"
    fi
    echo "      custom-domain: ${display_domain}"
    echo "      health-check-url: https://${display_domain}"
  fi
}

generate_common_dir_inputs() {
  if [[ "$PROJECT_TYPE" == *"frontend-only"* ]]; then
    echo "      backend-type: none"
    echo "      run-migrations: false"
    echo "      frontend-dir: \"${FRONTEND_DIR}\""
  elif [[ "$PROJECT_TYPE" == *"backend-only"* ]]; then
    echo "      backend-dir: \"${BACKEND_DIR}\""
  else
    echo "      backend-dir: \"${BACKEND_DIR}\""
    echo "      frontend-dir: \"${FRONTEND_DIR}\""
  fi
}

generate_common_secrets() {
  local env_name="$1"
  if [[ "$PROJECT_TYPE" != *"frontend-only"* ]]; then
    cat <<SECRETS
      TERRAFORM_VARS: |
        TF_VAR_environment=${env_name}
      DATABASE_URL: \${{ secrets.DATABASE_URL_$(echo "$env_name" | tr '[:lower:]' '[:upper:]') }}
SECRETS
  fi
  if [[ "$PROJECT_TYPE" == *"frontend"* ]] || [[ "$PROJECT_TYPE" == *"full-stack"* ]]; then
    cat <<SECRETS
      VITE_ENV_VARS: |
        VITE_API_URL=\${{ secrets.API_URL_$(echo "$env_name" | tr '[:lower:]' '[:upper:]') }}
SECRETS
  fi
  if [ "$ENABLE_TELEGRAM" = true ]; then
    cat <<SECRETS
      TELEGRAM_BOT_TOKEN: \${{ secrets.TELEGRAM_BOT_TOKEN }}
      TELEGRAM_CHAT_ID: \${{ secrets.TELEGRAM_CHAT_ID }}
SECRETS
  fi
}

generate_deploy_job() {
  local env_name="$1"
  local branch="$2"
  local state_key="$3"
  local domain="${4:-}"
  local needs="$5"

  case "$CLOUD_PROVIDER" in
    *"AWS"*)
      cat <<JOB
  deploy-${env_name}:
    needs: [${needs}]
    if: github.event_name == 'push' && github.ref == 'refs/heads/${branch}'
    uses: ${TEMPLATES_REPO}/.github/workflows/deploy-aws.yml@${TEMPLATES_REF}
    with:
      environment: ${env_name}
      terraform-state-key: ${state_key}
      app-name: ${APP_NAME}
      aws-region: ${AWS_REGION}
JOB
      generate_common_dir_inputs
      generate_common_domain_inputs "$env_name" "$domain"
      if [[ "$AUTH_METHOD" == *"OIDC"* ]]; then
        echo "      aws-role-arn: ${AWS_ROLE_ARN:-arn:aws:iam::ACCOUNT_ID:role/github-actions-deploy}"
      fi
      echo "    secrets:"
      if [[ "$AUTH_METHOD" != *"OIDC"* ]]; then
        cat <<SECRETS
      AWS_ACCESS_KEY_ID: \${{ secrets.AWS_ACCESS_KEY_ID }}
      AWS_SECRET_ACCESS_KEY: \${{ secrets.AWS_SECRET_ACCESS_KEY }}
SECRETS
      fi
      generate_common_secrets "$env_name"
      ;;

    *"GCP"*)
      cat <<JOB
  deploy-${env_name}:
    needs: [${needs}]
    if: github.event_name == 'push' && github.ref == 'refs/heads/${branch}'
    uses: ${TEMPLATES_REPO}/.github/workflows/deploy-gcp.yml@${TEMPLATES_REF}
    with:
      environment: ${env_name}
      gcp-project-id: ${GCP_PROJECT_ID}
      gcp-region: ${GCP_REGION}
      terraform-state-bucket: \${{ vars.TF_STATE_BUCKET }}
      terraform-state-prefix: ${env_name}/terraform
      app-name: ${APP_NAME}
JOB
      if [[ "$PROJECT_TYPE" == *"frontend-only"* ]]; then
        echo "      backend-type: none"
        echo "      frontend-dir: \"${FRONTEND_DIR}\""
      elif [[ "$PROJECT_TYPE" == *"backend-only"* ]]; then
        echo "      backend-dir: \"${BACKEND_DIR}\""
      else
        echo "      backend-dir: \"${BACKEND_DIR}\""
        echo "      frontend-dir: \"${FRONTEND_DIR}\""
      fi
      generate_common_domain_inputs "$env_name" "$domain"
      if [[ "$AUTH_METHOD" == *"Workload"* ]]; then
        echo "      workload-identity-provider: ${GCP_WIF_PROVIDER:-projects/PROJECT_NUM/locations/global/workloadIdentityPools/github-actions/providers/github}"
        echo "      service-account: ${GCP_SERVICE_ACCOUNT:-github-actions-deploy@${GCP_PROJECT_ID}.iam.gserviceaccount.com}"
      fi
      echo "    secrets:"
      if [[ "$AUTH_METHOD" != *"Workload"* ]]; then
        echo "      GCP_SA_KEY: \${{ secrets.GCP_SA_KEY }}"
      fi
      generate_common_secrets "$env_name"
      ;;

    *"Azure"*)
      cat <<JOB
  deploy-${env_name}:
    needs: [${needs}]
    if: github.event_name == 'push' && github.ref == 'refs/heads/${branch}'
    uses: ${TEMPLATES_REPO}/.github/workflows/deploy-azure.yml@${TEMPLATES_REF}
    with:
      environment: ${env_name}
      azure-subscription-id: ${AZURE_SUBSCRIPTION_ID}
      resource-group: ${AZURE_RESOURCE_GROUP}
      location: ${AZURE_LOCATION}
      terraform-state-key: ${state_key}
      app-name: ${APP_NAME}
JOB
      if [[ "$PROJECT_TYPE" == *"frontend-only"* ]]; then
        echo "      backend-type: none"
        echo "      frontend-dir: \"${FRONTEND_DIR}\""
      elif [[ "$PROJECT_TYPE" == *"backend-only"* ]]; then
        echo "      backend-dir: \"${BACKEND_DIR}\""
      else
        echo "      backend-dir: \"${BACKEND_DIR}\""
        echo "      frontend-dir: \"${FRONTEND_DIR}\""
      fi
      generate_common_domain_inputs "$env_name" "$domain"
      if [[ "$AUTH_METHOD" == *"OIDC"* ]]; then
        echo "      azure-tenant-id: ${AZURE_TENANT_ID:-TENANT_ID}"
        echo "      azure-client-id: ${AZURE_CLIENT_ID:-CLIENT_ID}"
      fi
      echo "    secrets:"
      if [[ "$AUTH_METHOD" != *"OIDC"* ]]; then
        echo "      AZURE_CREDENTIALS: \${{ secrets.AZURE_CREDENTIALS }}"
      fi
      generate_common_secrets "$env_name"
      ;;
  esac
  echo ""
}

# ─── Write the CI file ─────────────────────────────────────────

{
  cat <<HEADER
# Generated by Void CI Templates init script
# https://github.com/${TEMPLATES_REPO}

name: CI/CD Pipeline

on:
  push:
    branches: [main, staging]
  pull_request:
    branches: [main, staging]

jobs:
HEADER

  # ── Test jobs ──

  if [[ "$PROJECT_TYPE" == *"full-stack"* ]] || [[ "$PROJECT_TYPE" == *"backend-only"* ]]; then
    cat <<JOB
  test-backend:
    uses: ${TEMPLATES_REPO}/.github/workflows/test-python.yml@${TEMPLATES_REF}
    with:
      working-directory: "${BACKEND_DIR}"
      postgres: ${ENABLE_POSTGRES}

JOB
  fi

  if [[ "$PROJECT_TYPE" == *"full-stack"* ]] || [[ "$PROJECT_TYPE" == *"frontend-only"* ]]; then
    local_wd="${FRONTEND_DIR}"
    cat <<JOB
  test-frontend:
    uses: ${TEMPLATES_REPO}/.github/workflows/test-node.yml@${TEMPLATES_REF}
    with:
      working-directory: "${local_wd}"

JOB
  fi

  if [[ "$PROJECT_TYPE" == *"docker"* ]]; then
    cat <<JOB
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build Docker image (test)
        run: docker build -f ${DOCKERFILE_PATH} ${DOCKER_CONTEXT}

JOB
  fi

  # ── Lighthouse ──

  if [ "$ENABLE_LIGHTHOUSE" = true ]; then
    cat <<JOB
  lighthouse:
    if: github.event_name == 'pull_request'
    uses: ${TEMPLATES_REPO}/.github/workflows/lighthouse.yml@${TEMPLATES_REF}
    with:
      working-directory: "${FRONTEND_DIR}"

JOB
  fi

  # ── Deploy jobs ──

  if [[ "$PROJECT_TYPE" == *"docker"* ]]; then
    cat <<JOB
  docker-staging:
    needs: [test]
    if: github.event_name == 'push' && github.ref == 'refs/heads/staging'
    uses: ${TEMPLATES_REPO}/.github/workflows/docker-build.yml@${TEMPLATES_REF}
    with:
      context: "${DOCKER_CONTEXT}"
      dockerfile: "${DOCKERFILE_PATH}"
      tag-strategy: branch

  docker-production:
    needs: [test]
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    uses: ${TEMPLATES_REPO}/.github/workflows/docker-build.yml@${TEMPLATES_REF}
    with:
      context: "${DOCKER_CONTEXT}"
      dockerfile: "${DOCKERFILE_PATH}"
      tag-strategy: sha

JOB
  else
    # AWS deploy jobs
    case "$PROJECT_TYPE" in
      *"full-stack"*)
        NEEDS="test-backend, test-frontend";;
      *"frontend-only"*)
        NEEDS="test-frontend";;
      *"backend-only"*)
        NEEDS="test-backend";;
    esac

    generate_deploy_job "staging" "staging" "staging/terraform.tfstate" "$CUSTOM_DOMAIN" "$NEEDS"
    generate_deploy_job "production" "main" "prod/terraform.tfstate" "$CUSTOM_DOMAIN" "$NEEDS"
  fi

  # ── i18n ──

  if [ "$ENABLE_I18N" = true ]; then
    cat <<JOB
  translate:
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    uses: ${TEMPLATES_REPO}/.github/workflows/translate-i18n.yml@${TEMPLATES_REF}
    with:
      locales-path: "${FRONTEND_DIR}/public/locales"
    secrets:
      DEEPL_API_KEY: \${{ secrets.DEEPL_API_KEY }}

JOB
  fi

  # ── Mobile ──

  if [ "$ENABLE_MOBILE" = true ]; then
    local mobile_needs
    if [[ "$PROJECT_TYPE" == *"full-stack"* ]]; then
      mobile_needs="test-frontend"
    else
      mobile_needs="test-frontend"
    fi
    cat <<JOB
  android:
    needs: [${mobile_needs}]
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    uses: ${TEMPLATES_REPO}/.github/workflows/android-build.yml@${TEMPLATES_REF}
    with:
      working-directory: "${FRONTEND_DIR}"
      app-id: com.example.${APP_NAME,,}

  # WARNING: iOS builds use macOS runners (10x minute multiplier).
  # Consider only running on tags: if: startsWith(github.ref, 'refs/tags/')
  ios:
    needs: [${mobile_needs}]
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    uses: ${TEMPLATES_REPO}/.github/workflows/ios-build.yml@${TEMPLATES_REF}
    with:
      working-directory: "${FRONTEND_DIR}"
      app-id: com.example.${APP_NAME,,}
JOB
  fi

} > "$CI_FILE"

# ─── Dependabot ─────────────────────────────────────────────────

DEPENDABOT_FILE="$PROJECT_ROOT/.github/dependabot.yml"
if [ ! -f "$DEPENDABOT_FILE" ]; then
  {
    cat <<HEADER
version: 2
updates:
  - package-ecosystem: "github-actions"
    directory: "/"
    schedule:
      interval: "weekly"
    groups:
      actions:
        patterns:
          - "*"
HEADER

    if [[ "$PROJECT_TYPE" == *"full-stack"* ]] || [[ "$PROJECT_TYPE" == *"backend-only"* ]]; then
      cat <<BLOCK

  - package-ecosystem: "pip"
    directory: "/${BACKEND_DIR}"
    schedule:
      interval: "weekly"
    groups:
      python-deps:
        patterns:
          - "*"
BLOCK
    fi

    if [[ "$PROJECT_TYPE" == *"full-stack"* ]] || [[ "$PROJECT_TYPE" == *"frontend-only"* ]]; then
      cat <<BLOCK

  - package-ecosystem: "npm"
    directory: "/${FRONTEND_DIR}"
    schedule:
      interval: "weekly"
    groups:
      node-deps:
        patterns:
          - "*"
BLOCK
    fi

    if [[ "$PROJECT_TYPE" != *"docker"* ]]; then
      cat <<BLOCK

  - package-ecosystem: "terraform"
    directory: "/infra"
    schedule:
      interval: "weekly"
    groups:
      terraform-deps:
        patterns:
          - "*"
BLOCK
    fi

    if [[ "$PROJECT_TYPE" == *"docker"* ]]; then
      cat <<BLOCK

  - package-ecosystem: "docker"
    directory: "/"
    schedule:
      interval: "weekly"
BLOCK
    fi

  } > "$DEPENDABOT_FILE"
  echo -e "${GREEN}Created${NC} .github/dependabot.yml"
fi

echo -e "${GREEN}Created${NC} .github/workflows/ci.yml"

# ─── Print Summary ──────────────────────────────────────────────

echo ""
echo -e "${GREEN}${BOLD}Setup complete!${NC}"
echo ""
echo -e "${BOLD}Files created:${NC}"
echo -e "  ${CYAN}.github/workflows/ci.yml${NC}  - CI/CD pipeline"
echo -e "  ${CYAN}.github/dependabot.yml${NC}    - Dependency updates"
echo ""

# ── Secrets needed ──

echo -e "${BOLD}GitHub Secrets to configure:${NC}"
echo -e "  ${DIM}(Settings > Secrets and variables > Actions)${NC}"
echo ""

case "$CLOUD_PROVIDER" in
  *"AWS"*)
    if [[ "$AUTH_METHOD" == *"OIDC"* ]]; then
      echo -e "  ${YELLOW}AWS (OIDC):${NC}"
      if [ -z "$AWS_ROLE_ARN" ]; then
        echo -e "    Update ${CYAN}aws-role-arn${NC} in ci.yml after creating the IAM role"
        echo -e "    ${DIM}Use the Terraform module: terraform/oidc/ in ci-templates${NC}"
      fi
    else
      echo -e "  ${YELLOW}AWS:${NC}"
      echo "    AWS_ACCESS_KEY_ID"
      echo "    AWS_SECRET_ACCESS_KEY"
    fi
    ;;
  *"GCP"*)
    if [[ "$AUTH_METHOD" == *"Workload"* ]]; then
      echo -e "  ${YELLOW}GCP (Workload Identity):${NC}"
      if [ -z "$GCP_WIF_PROVIDER" ]; then
        echo -e "    Update ${CYAN}workload-identity-provider${NC} and ${CYAN}service-account${NC} in ci.yml"
        echo -e "    ${DIM}Use the Terraform module: terraform/oidc-gcp/ in ci-templates${NC}"
      fi
    else
      echo -e "  ${YELLOW}GCP:${NC}"
      echo "    GCP_SA_KEY (service account key JSON)"
    fi
    ;;
  *"Azure"*)
    if [[ "$AUTH_METHOD" == *"OIDC"* ]]; then
      echo -e "  ${YELLOW}Azure (Federated Credentials):${NC}"
      if [ -z "$AZURE_CLIENT_ID" ]; then
        echo -e "    Update ${CYAN}azure-tenant-id${NC} and ${CYAN}azure-client-id${NC} in ci.yml"
        echo -e "    ${DIM}Use the Terraform module: terraform/oidc-azure/ in ci-templates${NC}"
      fi
    else
      echo -e "  ${YELLOW}Azure:${NC}"
      echo "    AZURE_CREDENTIALS (service principal JSON)"
    fi
    ;;
esac

if [[ "$PROJECT_TYPE" != *"docker"* ]]; then
  echo ""
  echo -e "  ${YELLOW}Per environment:${NC}"
  if [[ "$PROJECT_TYPE" != *"frontend-only"* ]]; then
    echo "    DATABASE_URL_STAGING"
    echo "    DATABASE_URL_PRODUCTION"
  fi
  if [[ "$PROJECT_TYPE" == *"frontend"* ]] || [[ "$PROJECT_TYPE" == *"full-stack"* ]]; then
    echo "    API_URL_STAGING"
    echo "    API_URL_PRODUCTION"
  fi
fi

if [ "$ENABLE_TELEGRAM" = true ]; then
  echo ""
  echo -e "  ${YELLOW}Telegram:${NC}"
  echo "    TELEGRAM_BOT_TOKEN"
  echo "    TELEGRAM_CHAT_ID"
fi

if [ "$ENABLE_I18N" = true ]; then
  echo ""
  echo -e "  ${YELLOW}Translations:${NC}"
  echo "    DEEPL_API_KEY"
fi

# OIDC setup instructions
REPO_SLUG=$(git remote get-url origin 2>/dev/null | sed 's/.*github.com[:/]//' | sed 's/.git$//' || echo "your-org/your-repo")
if [[ "$AUTH_METHOD" == *"OIDC"* ]] || [[ "$AUTH_METHOD" == *"Workload"* ]]; then
  echo ""
  echo -e "${BOLD}OIDC Setup (one-time):${NC}"
  case "$CLOUD_PROVIDER" in
    *"AWS"*)
      echo -e "  1. ${DIM}cd ci-templates/terraform/oidc${NC}"
      echo -e "  2. ${DIM}terraform init && terraform apply -var='github_repos=[\"${REPO_SLUG}\"]'${NC}"
      echo -e "  3. Copy the output ${CYAN}role_arn${NC} into your ci.yml"
      ;;
    *"GCP"*)
      echo -e "  1. ${DIM}cd ci-templates/terraform/oidc-gcp${NC}"
      echo -e "  2. ${DIM}terraform init && terraform apply -var='gcp_project_id=${GCP_PROJECT_ID}' -var='github_repos=[\"${REPO_SLUG}\"]'${NC}"
      echo -e "  3. Copy outputs ${CYAN}workload_identity_provider${NC} and ${CYAN}service_account_email${NC} into your ci.yml"
      ;;
    *"Azure"*)
      echo -e "  1. ${DIM}cd ci-templates/terraform/oidc-azure${NC}"
      echo -e "  2. ${DIM}terraform init && terraform apply -var='github_repos=[\"${REPO_SLUG}\"]'${NC}"
      echo -e "  3. Copy outputs ${CYAN}client_id${NC} and ${CYAN}tenant_id${NC} into your ci.yml"
      ;;
  esac
fi

echo ""
echo -e "${DIM}Docs: https://github.com/${TEMPLATES_REPO}${NC}"
echo ""
