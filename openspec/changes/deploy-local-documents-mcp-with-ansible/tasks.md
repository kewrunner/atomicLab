## 1. Ansible Skeleton and Configuration

- [x] 1.1 Create the `ansible/` inventory, configuration, deployment playbook, role metadata, and documented defaults; verify the proposed file tree exists.
- [x] 1.2 Define required and optional variables, including security-sensitive defaults, bounded/pinned dependency inputs, and validation messages; verify README coverage for every variable.

## 2. Preflight and Platform Support

- [x] 2.1 Implement target-host, required-variable, canonical-path, protected-directory, existence/type, and service-account access preflight checks before mutating tasks; verify negative fixtures fail without changes.
- [x] 2.2 Implement Ubuntu 24.04 and RHEL 9-compatible fact detection and package maps using Ansible package modules; verify supported fixtures resolve packages and unsupported fixtures fail clearly.
- [x] 2.3 Create the dedicated service user/group, application/configuration directories, and least-privilege permissions; verify ownership, modes, ACLs, and exposed-directory traversal/read access.

## 3. Application and Dependency Deployment

- [x] 3.1 Add deterministic Python dependency management and create the isolated virtual environment; verify dependencies install inside `.venv` without system-Python changes or `break-system-packages`.
- [x] 3.2 Implement the Streamable HTTP MCP server and render its environment/configuration; verify endpoint startup and tool discovery at `/mcp`.
- [x] 3.3 Implement canonical-root containment, traversal/symlink-escape rejection, hidden and sensitive-file policies, extension filtering, text decoding, size/count limits, metadata, listing, file/content search, and read tools; verify unit/fixture cases for each policy and no mutation/command execution.
- [x] 3.4 Add safe audit logging for tool, status, and approved relative path without contents, secrets, or complete payloads; verify captured journal events meet the logging contract.

## 4. Service and Client Integration

- [x] 4.1 Render and manage the hardened systemd unit with loopback defaults, `/mcp`, journal logging, restart-on-failure, read-only access, and handler notifications; verify `systemctl` status and restart behavior.
- [x] 4.2 Implement guarded optional VS Code `mcp.json` configuration and explicit firewall/remote-network opt-ins; verify defaults remain loopback-only and guarded settings behave as documented.
- [x] 4.3 Add verification tasks for service health, endpoint reachability, tool discovery, and read-only behavior; verify the deployment playbook completes and is idempotent on a fixture target.

## 5. Test and Documentation Delivery

- [x] 5.1 Add syntax-check and deployment-validation scripts/playbooks plus representative fixtures for both supported OS families and invalid inputs; verify checks run successfully in the documented test command.
- [x] 5.2 Complete role README documentation for architecture, invocation, variables, security implications, dependency policy, VS Code setup, rollback, and troubleshooting; verify examples use an explicit approved host and safe directory.
