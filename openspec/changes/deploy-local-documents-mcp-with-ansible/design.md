## Context

The proposal replaces a manually installed Python FastMCP server with a host-local service. The design must protect arbitrary user-selected directories while supporting two OS families and a Remote SSH client.

## Goals / Non-Goals

**Goals:**

- Make deployment deterministic, idempotent, reviewable, and verifiable.
- Enforce safety gates before mutation and defense-in-depth in the server.
- Keep the default trust boundary on loopback and read-only filesystem access.

**Non-Goals:**

- Deploying to multiple hosts in one invocation, public MCP hosting, inbound firewall exposure by default, or replacing MCP servers on other hosts.

## Decisions

- Use a dedicated role with separate validation, dependencies, account, application, permissions, service, VS Code, and verification task files. This keeps preflight gates auditable and allows handlers to restart only after relevant changes.
- Use a pinned requirements file with hashes where practical; otherwise use a documented bounded-version policy and test the supported FastMCP/MCP combination. Install only into `/opt/local-documents-mcp/.venv`, avoiding system Python and `break-system-packages`.
- Render configuration through an environment file and systemd unit. The unit uses the dedicated account, journal logging, `Restart=on-failure`, loopback binding, and systemd hardening such as read-only protection with explicit read access to the exposed directory. A systemd unit is preferred over a client-launched stdio process because continuity is required.
- Implement all path checks using canonical paths and component-aware containment, with `realpath` checks for requested paths and symlink targets. Apply hidden, name, extension, size, and count policies in every relevant tool. This is safer than trusting client-side filtering.
- Make `mcp_target_host` an exact inventory assertion and perform all validation before package/account/file tasks. This prevents accidental deployment caused by a broad inventory selection.
- Keep VS Code JSON integration optional and guarded by non-empty user/workspace values. Keep firewall and remote bind switches explicit because either expands the attack surface.

## Risks / Trade-offs

- [Dependency drift] → Pin hashes or bound versions, test installation, and notify the service handler on dependency changes.
- [Filesystem permissions change after deployment] → Verify access during deployment and return actionable failures; runtime errors remain safely denied.
- [TOCTOU or unusual filesystem behavior] → Canonicalize before access, reject symlink escapes, use read-only service confinement, and avoid mutation APIs.
- [Remote exposure misconfiguration] → Default loopback, require a separate allow-remote variable, and validate the bind address against that approval.
- [Large trees/searches consume resources] → Enforce configurable item, file-size, file-count, and result limits.

## Migration Plan

Deploy with an explicit inventory host and exposed directory, run syntax and validation checks, then verify the systemd health and MCP endpoint locally. Roll back by stopping/disabling the unit and removing only resources owned by this role; preserve the exposed directory and unrelated services. Re-running the role restores the declared state.

## Open Questions

None.
