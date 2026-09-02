#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
ansible-playbook --syntax-check playbooks/deploy_local_documents_mcp.yml
