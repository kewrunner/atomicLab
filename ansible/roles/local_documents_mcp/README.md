# local_documents_mcp

Deploys a dedicated, read-only FastMCP Streamable HTTP service for one approved directory. Run with `-e mcp_target_host=... -e mcp_exposed_directory=/srv/documents`.

Required variables are `mcp_target_host` (exact inventory hostname) and `mcp_exposed_directory` (absolute, existing, non-system directory). The role rejects protected roots, traversal, and unusable access before mutation.

Defaults: service/account/group `local-documents-mcp`, install `/opt/local-documents-mcp`, config `/etc/local-documents-mcp`, loopback `127.0.0.1:8010/mcp`, 5 MB files, 500 directory items, 100 search files, 50 results. Hidden files are disabled; blocked extensions include executable/scripts/keys/certificates and blocked names include `.env` and SSH files. An empty allowed-extension list means no additional extension restriction. Limits reduce resource exposure; changing bind address, allowing remote network, firewall management, or VS Code configuration expands trust and must be reviewed.

The role supports Ubuntu 24.04 and RHEL 9-compatible systems, installs OS packages with Ansible, and installs bounded Python dependencies only in `.venv`. The service uses systemd hardening, journal audit events without contents, and never mutates or executes exposed files. `local_documents_mcp_vscode_workspace` enables optional workspace `mcp.json` generation; firewall management is intentionally not implemented unless separately added and approved.
