## Purpose

Provide a repeatable, target-restricted deployment of a continuously running, read-only Local Documents MCP service for authorized VS Code Remote SSH clients.

## ADDED Requirements

### Requirement: Deployment is explicitly target-gated and validated before changes
The deployment MUST require non-empty `mcp_target_host` and `mcp_exposed_directory`, and MUST fail before making changes unless the inventory host exactly matches the approved target, the directory is absolute, exists, is a directory, resolves neither to `/` nor to a protected system directory, and the service account can safely obtain read and traversal access.

#### Scenario: Wrong host is rejected
- **WHEN** the play runs on an inventory host different from `mcp_target_host`
- **THEN** validation fails before account, package, file, or service changes

#### Scenario: Unsafe or unavailable directory is rejected
- **WHEN** the requested path is relative, protected, missing, non-directory, or cannot be safely accessed
- **THEN** validation fails before deployment changes

### Requirement: Ansible deployment is supported and repeatable on approved platforms
The role MUST detect gathered OS facts, support Ubuntu 24.04 and RHEL 9-compatible systems, fail clearly on unsupported systems, resolve packages through Ansible package modules, isolate Python dependencies in the application virtual environment, and converge safely on repeated execution.

#### Scenario: Supported host converges
- **WHEN** the role runs on a supported host with a valid directory
- **THEN** required packages, isolated dependencies, application files, account, and service converge without modifying system Python

#### Scenario: Unsupported host fails clearly
- **WHEN** the target OS family/version is outside the supported set
- **THEN** the role fails with an actionable unsupported-platform message

### Requirement: Service exposes secure read-only MCP tools over Streamable HTTP
The service MUST run continuously under systemd as the configured service account, use Streamable HTTP at `/mcp`, default to `127.0.0.1:8010`, restart on failure, and expose only the configured canonical directory through listing, permitted text-file reading, filename search, content search, and file/directory metadata operations.

#### Scenario: VS Code connects locally
- **WHEN** an authorized VS Code Remote SSH process connects to `http://127.0.0.1:8010/mcp`
- **THEN** it can discover and invoke the read-only document tools without an inbound firewall rule

#### Scenario: Remote binding requires explicit approval
- **WHEN** remote network exposure is not explicitly enabled
- **THEN** the service binds only to loopback and never to `0.0.0.0` or a LAN address

### Requirement: File access is confined and policy-controlled
The server MUST canonicalize and enforce the configured root, reject traversal and symlink escapes, exclude hidden files by default, enforce blocked names/extensions, optional allowed extensions, file-size and directory/search-result limits, and controlled text decoding. It MUST not expose credentials, secrets, service configuration, or sensitive key/certificate material.

#### Scenario: Escape attempt is denied
- **WHEN** a request resolves outside the canonical root, including through a symlink
- **THEN** the request is rejected and no outside file data is returned

#### Scenario: Policy limit is exceeded
- **WHEN** a file, directory, or search exceeds its configured limit or matches a blocked policy
- **THEN** the operation is rejected or safely truncated according to the documented response contract

### Requirement: Service is non-mutating and auditable
The MCP server MUST never execute files or shell commands and MUST never create, modify, rename, or delete exposed files. It MUST log tool name, result status, and approved relative path to the systemd journal without file contents, secrets, or complete request payloads.

#### Scenario: Mutating request is unavailable
- **WHEN** a client attempts an operation outside the read-only tool set
- **THEN** no mutation is performed and the request is rejected

#### Scenario: Safe audit event is emitted
- **WHEN** a tool request completes or is rejected
- **THEN** the journal contains tool and result status plus only an approved relative path when applicable

### Requirement: Optional client integration is controlled
The role MUST document every variable and its security implications, and MUST configure VS Code only when enabled and when a target user/workspace is explicitly usable. Firewall management and remote network exposure MUST remain disabled by default.

#### Scenario: Defaults preserve local-only deployment
- **WHEN** optional settings are not overridden
- **THEN** VS Code integration follows its documented default, firewall management is off, and remote binding is off
