## Why

The manually deployed Local Documents MCP server is difficult to reproduce consistently and lacks a reviewable deployment contract. This change introduces an idempotent, target-gated Ansible deployment for a persistent, loopback-only, read-only MCP service so VS Code Remote SSH clients can safely access approved documents.

## What Changes

- Add a reusable Ansible role and deployment playbook for Ubuntu 24.04 and RHEL 9-compatible targets.
- Require explicit target-host and exposed-directory variables, with fail-before-change validation and safe filesystem-access checks.
- Deploy a pinned or bounded Python environment, FastMCP/MCP application, systemd service, configuration, permissions, and optional VS Code integration.
- Expose directory listing, text reading, filename/content search, and metadata tools with traversal, symlink, hidden-file, sensitive-file, size, and result-limit protections.
- Default the service to Streamable HTTP on `127.0.0.1:8010/mcp`; keep firewall management and remote binding opt-in.
- Add deployment verification fixtures and syntax/validation tests, plus documentation for all variables and their security implications.

## Capabilities

### New Capabilities

- `local-documents-mcp-deployment`: Ansible-managed deployment and lifecycle of a secure, read-only Local Documents MCP service.

### Modified Capabilities

- None.

## Impact

Adds an `ansible/` content tree, Python runtime dependencies isolated under `/opt/local-documents-mcp/.venv`, a systemd service and configuration under `/etc/local-documents-mcp`, a dedicated service account, and optional VS Code workspace/user configuration. It does not modify any MCP server on another host.
