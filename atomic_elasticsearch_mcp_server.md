# Internal Elasticsearch MCP Server

Read-only Model Context Protocol (MCP) access to an Elasticsearch cluster from
VS Code over Remote SSH. The installer deploys a dedicated Python MCP server on
the Elasticsearch host and uses `stdio`, so it does not create an MCP network
listener or alter an existing MCP server on another machine.

## Validated deployment

| Component | Value |
| --- | --- |
| Operating system | Ubuntu 24.04 |
| Elasticsearch host | `192.168.1.172` |
| Elasticsearch endpoint | `https://127.0.0.1:9200` |
| Elasticsearch version tested | `9.4.2` |
| MCP transport | `stdio` |
| MCP client | VS Code through Remote SSH |
| VS Code remote user tested | `freddygonzalez` |
| Authentication | Restricted Elasticsearch API key |
| TLS trust | Elasticsearch HTTP CA certificate |

## Architecture

```text
VS Code on administrator workstation
        |
        | Remote SSH
        v
192.168.1.172
  VS Code Remote extension host
        |
        | stdio
        v
  Internal Elasticsearch MCP server
        |
        | HTTPS + API key + CA verification
        v
  Elasticsearch on 127.0.0.1:9200
```

The server is created under `/opt/mcp-servers/elasticsearch`. Runtime secrets
and trust material are kept under `/etc/mcp-elasticsearch`.

## Exposed tools

| Tool | Purpose |
| --- | --- |
| `elasticsearch_health` | Returns cluster, node, shard, and pending-task health data. |
| `list_data_streams` | Lists approved `logs-*` and `metrics-*` logical data streams. |
| `search_logs` | Performs a bounded simple-text search against one `logs-*` stream. |
| `recent_metrics` | Returns recent documents from one `metrics-*` stream. |

The implementation deliberately does not expose arbitrary Elasticsearch DSL,
write operations, index deletion, template management, or unrestricted system
index access.

## Prerequisites

Before running the installer, the Elasticsearch host must have:

- Elasticsearch reachable at `https://127.0.0.1:9200`.
- `/etc/elasticsearch/certs/http_ca.crt` present.
- A valid encoded, read-only API key stored at
  `/etc/mcp-elasticsearch/api-key`.
- A VS Code Remote SSH user already created.
- Internet or package-repository access for `apt` and Python package installs.

The API key used during validation had these effective privileges:

```json
{
  "cluster": ["monitor"],
  "indices": [
    {
      "names": [
        "logs-*",
        "metrics-*",
        ".ds-logs-*",
        ".ds-metrics-*"
      ],
      "privileges": [
        "read",
        "view_index_metadata",
        "monitor"
      ],
      "allow_restricted_indices": false
    }
  ]
}
```

Never use the `elastic` superuser credential as the MCP runtime identity.

## Installation

Copy `install_elasticsearch_mcp.sh` to the Elasticsearch host and execute it as
root, supplying the VS Code Remote SSH username:

```bash
chmod 0700 install_elasticsearch_mcp.sh
sudo ./install_elasticsearch_mcp.sh freddygonzalez
```

The installer:

1. Installs Python and virtual-environment prerequisites.
2. Creates the `mcp-elasticsearch` system group.
3. Grants the selected Remote SSH user membership in that group.
4. Creates protected application and configuration directories.
5. Copies the Elasticsearch CA certificate.
6. Protects the API key with group-readable mode `0640`.
7. Creates the isolated Python virtual environment.
8. Installs supported MCP and Elasticsearch Python packages.
9. Writes the read-only MCP server.
10. Compiles the Python source and performs an authenticated Elasticsearch
    connection test.

Successful installation ends with output similar to:

```text
Connected to Elasticsearch 9.4.2 on lab-ubuntu24-aap-client-962-172
Installation complete.
```

Reconnect the entire VS Code Remote SSH window after installation. Existing
processes do not automatically receive new supplementary group memberships.

## VS Code workspace configuration

The included `examples/mcp.json` must appear at `.vscode/mcp.json` directly
beneath the folder currently opened as the VS Code workspace.

Example layout:

```text
/home/freddygonzalez/elastic-mcp-workspace/
└── .vscode/
    └── mcp.json
```

Open `/home/freddygonzalez/elastic-mcp-workspace` itself in VS Code. Opening
`/home/freddygonzalez` instead will not discover a configuration nested at
`elastic-mcp-workspace/.vscode/mcp.json`.

After saving the configuration:

1. Run **Developer: Reload Window**.
2. Run **MCP: List Servers**.
3. Select `internalElasticsearch`.
4. Start the server.

Expected evidence:

```text
Starting server internalElasticsearch
Starting server from Remote extension host
Connection state: Running
Discovered 4 tools
```

## Verification

Confirm group membership in a newly connected Remote SSH session:

```bash
id
```

Confirm runtime access:

```bash
test -r /etc/mcp-elasticsearch/api-key &&
test -r /etc/mcp-elasticsearch/http_ca.crt &&
test -x /opt/mcp-servers/elasticsearch/.venv/bin/python &&
echo "MCP runtime access: PASS"
```

Confirm direct module connectivity:

```bash
/opt/mcp-servers/elasticsearch/.venv/bin/python -c '
import sys
sys.path.insert(0, "/opt/mcp-servers/elasticsearch")
import elasticsearch_mcp_server as server
info = server.es.info().body
print(info["name"], info["version"]["number"])
'
```

Example VS Code Chat tests:

```text
Use internalElasticsearch to return cluster health.
```

```text
Use internalElasticsearch to list all logs data streams.
```

```text
Use internalElasticsearch to search logs-system.auth-default for SSH events
during the last 720 hours. Return the 10 newest events.
```

## Security controls

- MCP traffic uses `stdio`; no MCP TCP port is opened.
- Elasticsearch traffic stays on loopback at `127.0.0.1:9200`.
- TLS certificate validation is enabled.
- Authentication uses a restricted API key stored outside user home folders.
- Index names are validated and limited to logical `logs-*` and `metrics-*`
  streams.
- Queries and time windows are bounded.
- Result counts are capped at 100.
- The model cannot supply arbitrary Elasticsearch request bodies.
- No write or destructive Elasticsearch method is exposed.

Treat MCP tool results as information disclosed to the configured AI client.
Local execution does not prevent returned log or metric content from being sent
to a hosted model.

## Troubleshooting

### VS Code asks for an Elasticsearch URL

Cancel the prompt. It belongs to the packaged `elastic/mcp-server-elasticsearch`
installation flow, not this custom server. Do not use the **Add Server** button.
Start `internalElasticsearch` from **MCP: List Servers**.

### Docker socket error

An error referencing a path such as:

```text
~/.docker/desktop/docker.sock
```

means VS Code launched the packaged Docker-based Elastic MCP server. Stop or
remove `elastic/mcp-server-elasticsearch`; this project does not use Docker.

### `internalElasticsearch` is missing from the list

Confirm that `.vscode/mcp.json` is immediately below the folder currently open
in VS Code. The Explorer's top-level folder is the authoritative workspace
root.

### Permission denied reading the API key

Reconnect the entire Remote SSH window and verify:

```bash
id freddygonzalez
namei -l /etc/mcp-elasticsearch/api-key
```

The user must belong to `mcp-elasticsearch`, the directory should be mode
`0750`, and the key should be owned by `root:mcp-elasticsearch` with mode
`0640`.

### Logs appear as warnings

VS Code categorizes server `stderr` as warning output. Python logging writes
normal `INFO` records to `stderr`; messages containing `INFO` are not failures.

### Server stops during window reload

Expected for `stdio`. The MCP process is a child of the Remote extension host
and stops when that host shuts down. It should restart when the workspace
reloads.

### Cluster health is yellow

In a single-node lab, yellow health commonly indicates unassigned replica
shards. Confirm that `unassigned_primary_shards` is zero before treating this
as a replica-only condition.

## Operational notes

- Rotate the Elasticsearch API key before its expiration date.
- Revoke exposed or superseded keys immediately.
- Query logical data-stream names instead of dated `.ds-*` backing indices.
- Review data freshness independently of MCP availability. During validation,
  MCP connectivity worked while an authentication data stream contained older
  records, demonstrating that transport health does not prove ingestion health.
- Re-run the installer after controlled updates to recreate the virtual
  environment and deployed server deterministically.

## Package contents

```text
elasticsearch-mcp-package/
├── README.md
├── SHA256SUMS
├── install_elasticsearch_mcp.sh
└── examples/
    └── mcp.json
```
