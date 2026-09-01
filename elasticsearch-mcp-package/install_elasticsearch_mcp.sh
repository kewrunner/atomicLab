#!/usr/bin/env bash
set -Eeuo pipefail

readonly INSTALL_DIR="/opt/mcp-servers/elasticsearch"
readonly CONFIG_DIR="/etc/mcp-elasticsearch"
readonly SERVER_FILE="${INSTALL_DIR}/elasticsearch_mcp_server.py"
readonly VENV_DIR="${INSTALL_DIR}/.venv"
readonly MCP_GROUP="mcp-elasticsearch"

log() { printf '[INFO] %s\n' "$*"; }
fail() { printf '[ERROR] %s\n' "$*" >&2; exit 1; }

[[ ${EUID} -eq 0 ]] || fail "Run as root: sudo bash $0 <vscode-ssh-user>"
[[ $# -eq 1 ]] || fail "Usage: sudo bash $0 <vscode-ssh-user>"

readonly CLIENT_USER="$1"
id "${CLIENT_USER}" >/dev/null 2>&1 || fail "User does not exist: ${CLIENT_USER}"
[[ -s "${CONFIG_DIR}/api-key" ]] || fail "Missing ${CONFIG_DIR}/api-key"
[[ -s "/etc/elasticsearch/certs/http_ca.crt" ]] || fail "Missing Elasticsearch HTTP CA"

log "Installing required OS packages"
export DEBIAN_FRONTEND=noninteractive
apt-get update
apt-get install -y --no-install-recommends python3 python3-venv ca-certificates

log "Creating isolated service paths"
getent group "${MCP_GROUP}" >/dev/null || groupadd --system "${MCP_GROUP}"
usermod -aG "${MCP_GROUP}" "${CLIENT_USER}"
install -d -o root -g "${MCP_GROUP}" -m 0750 "${INSTALL_DIR}"
install -d -o root -g "${MCP_GROUP}" -m 0750 "${CONFIG_DIR}"
install -o root -g "${MCP_GROUP}" -m 0640 \
  /etc/elasticsearch/certs/http_ca.crt "${CONFIG_DIR}/http_ca.crt"
chown root:"${MCP_GROUP}" "${CONFIG_DIR}/api-key"
chmod 0640 "${CONFIG_DIR}/api-key"

log "Writing MCP runtime configuration"
cat >"${CONFIG_DIR}/elasticsearch.env" <<'EOF'
ELASTICSEARCH_URL=https://127.0.0.1:9200
ELASTICSEARCH_CA_CERT=/etc/mcp-elasticsearch/http_ca.crt
ELASTICSEARCH_API_KEY_FILE=/etc/mcp-elasticsearch/api-key
ELASTICSEARCH_MAX_RESULTS=100
ELASTICSEARCH_REQUEST_TIMEOUT=20
EOF
chown root:"${MCP_GROUP}" "${CONFIG_DIR}/elasticsearch.env"
chmod 0640 "${CONFIG_DIR}/elasticsearch.env"

log "Writing read-only Elasticsearch MCP server"
cat >"${SERVER_FILE}" <<'PYTHON'
#!/usr/bin/env python3
"""Read-only MCP interface for the local Elasticsearch cluster."""

from __future__ import annotations

import logging
import os
import re
import sys
from pathlib import Path
from typing import Annotated, Any, Literal

from elasticsearch import Elasticsearch
from mcp.server.fastmcp import FastMCP

logging.basicConfig(
    stream=sys.stderr,
    level=logging.INFO,
    format="%(asctime)s %(levelname)s %(name)s: %(message)s",
)
LOGGER = logging.getLogger("internal-elasticsearch-mcp")

CONFIG_FILE = Path("/etc/mcp-elasticsearch/elasticsearch.env")
DATA_STREAM_RE = re.compile(r"^(logs|metrics)-[a-zA-Z0-9_.-]+$")


def load_config(path: Path) -> None:
    if not path.is_file():
        raise RuntimeError(f"Configuration not found: {path}")
    for raw_line in path.read_text(encoding="utf-8").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        key, separator, value = line.partition("=")
        if not separator or not key:
            raise RuntimeError(f"Invalid configuration line in {path}")
        os.environ.setdefault(key.strip(), value.strip())


load_config(CONFIG_FILE)

ES_URL = os.environ["ELASTICSEARCH_URL"]
CA_CERT = os.environ["ELASTICSEARCH_CA_CERT"]
API_KEY_FILE = Path(os.environ["ELASTICSEARCH_API_KEY_FILE"])
MAX_RESULTS = int(os.getenv("ELASTICSEARCH_MAX_RESULTS", "100"))
REQUEST_TIMEOUT = int(os.getenv("ELASTICSEARCH_REQUEST_TIMEOUT", "20"))

if not Path(CA_CERT).is_file():
    raise RuntimeError(f"CA certificate not found: {CA_CERT}")
if not API_KEY_FILE.is_file():
    raise RuntimeError(f"API key file not found: {API_KEY_FILE}")

API_KEY = API_KEY_FILE.read_text(encoding="utf-8").strip()
if not API_KEY:
    raise RuntimeError("Elasticsearch API key is empty")

es = Elasticsearch(
    ES_URL,
    api_key=API_KEY,
    ca_certs=CA_CERT,
    verify_certs=True,
    request_timeout=REQUEST_TIMEOUT,
    retry_on_timeout=True,
    max_retries=2,
)

mcp = FastMCP(
    "Internal Elasticsearch",
    instructions=(
        "Read-only access to approved logs-* and metrics-* data streams. "
        "Never modify Elasticsearch data or configuration."
    ),
)


def validate_data_stream(name: str, category: str | None = None) -> str:
    clean_name = name.strip()
    if not DATA_STREAM_RE.fullmatch(clean_name):
        raise ValueError("Only logical logs-* and metrics-* data streams are allowed")
    if category and not clean_name.startswith(f"{category}-"):
        raise ValueError(f"Expected a {category}-* data stream")
    return clean_name


def bounded_size(size: int) -> int:
    return max(1, min(int(size), MAX_RESULTS))


@mcp.tool()
def elasticsearch_health() -> dict[str, Any]:
    """Return read-only Elasticsearch cluster health and shard totals."""
    LOGGER.info("Cluster health requested")
    return es.cluster.health(
        filter_path=(
            "cluster_name,status,timed_out,number_of_nodes,number_of_data_nodes,"
            "active_primary_shards,active_shards,unassigned_shards,"
            "unassigned_primary_shards,number_of_pending_tasks"
        )
    ).body


@mcp.tool()
def list_data_streams(
    category: Annotated[
        Literal["logs", "metrics", "all"],
        "Return log streams, metric streams, or both",
    ] = "all",
) -> list[dict[str, Any]]:
    """List approved logical data streams without exposing system indices."""
    pattern = "logs-*" if category == "logs" else "metrics-*" if category == "metrics" else "logs-*,metrics-*"
    LOGGER.info("Data stream inventory requested: %s", category)
    response = es.indices.get_data_stream(name=pattern)
    return [
        {
            "name": item["name"],
            "generation": item.get("generation"),
            "status": item.get("status"),
            "index_mode": item.get("index_mode"),
        }
        for item in response.body.get("data_streams", [])
    ]


@mcp.tool()
def search_logs(
    data_stream: Annotated[str, "Logical logs-* data stream name"],
    query: Annotated[str, "Simple text query; Lucene simple-query syntax is accepted"],
    hours: Annotated[int, "Search window in hours, from 1 through 720"] = 24,
    size: Annotated[int, "Number of events to return, capped by server policy"] = 20,
) -> dict[str, Any]:
    """Search an approved log stream within a bounded time window."""
    index = validate_data_stream(data_stream, "logs")
    clean_query = query.strip()
    if not clean_query or len(clean_query) > 500:
        raise ValueError("Query must contain between 1 and 500 characters")
    safe_hours = max(1, min(int(hours), 720))
    safe_size = bounded_size(size)
    LOGGER.info("Log search: stream=%s hours=%d size=%d", index, safe_hours, safe_size)
    response = es.search(
        index=index,
        size=safe_size,
        track_total_hits=10000,
        sort=[{"@timestamp": {"order": "desc", "unmapped_type": "date"}}],
        source_includes=[
            "@timestamp", "host.name", "event.action", "event.category",
            "event.outcome", "log.level", "message", "process.name",
            "source.ip", "user.name",
        ],
        query={
            "bool": {
                "filter": [{"range": {"@timestamp": {"gte": f"now-{safe_hours}h", "lte": "now"}}}],
                "must": [{"simple_query_string": {"query": clean_query, "default_operator": "and", "lenient": True}}],
            }
        },
    )
    hits = response.body.get("hits", {})
    return {
        "data_stream": index,
        "hours": safe_hours,
        "took_ms": response.body.get("took"),
        "total": hits.get("total"),
        "returned": len(hits.get("hits", [])),
        "events": [hit.get("_source", {}) for hit in hits.get("hits", [])],
    }


@mcp.tool()
def recent_metrics(
    data_stream: Annotated[str, "Logical metrics-* data stream name"],
    host_name: Annotated[str, "Optional exact host.name filter"] = "",
    minutes: Annotated[int, "Time window in minutes, from 1 through 1440"] = 60,
    size: Annotated[int, "Number of metric documents, capped by server policy"] = 20,
) -> dict[str, Any]:
    """Return recent documents from an approved metrics stream."""
    index = validate_data_stream(data_stream, "metrics")
    safe_minutes = max(1, min(int(minutes), 1440))
    safe_size = bounded_size(size)
    filters: list[dict[str, Any]] = [
        {"range": {"@timestamp": {"gte": f"now-{safe_minutes}m", "lte": "now"}}}
    ]
    if host_name.strip():
        filters.append({"term": {"host.name": host_name.strip()}})
    LOGGER.info("Metric read: stream=%s minutes=%d size=%d", index, safe_minutes, safe_size)
    response = es.search(
        index=index,
        size=safe_size,
        track_total_hits=10000,
        sort=[{"@timestamp": {"order": "desc", "unmapped_type": "date"}}],
        query={"bool": {"filter": filters}},
    )
    hits = response.body.get("hits", {})
    return {
        "data_stream": index,
        "minutes": safe_minutes,
        "took_ms": response.body.get("took"),
        "total": hits.get("total"),
        "returned": len(hits.get("hits", [])),
        "documents": [hit.get("_source", {}) for hit in hits.get("hits", [])],
    }


if __name__ == "__main__":
    LOGGER.info("Starting Internal Elasticsearch MCP server using stdio")
    mcp.run(transport="stdio")
PYTHON
chown root:"${MCP_GROUP}" "${SERVER_FILE}"
chmod 0750 "${SERVER_FILE}"

log "Creating isolated Python environment"
python3 -m venv "${VENV_DIR}"
"${VENV_DIR}/bin/python" -m pip install --upgrade pip
"${VENV_DIR}/bin/python" -m pip install 'mcp>=1.12,<2' 'elasticsearch>=9,<10'

log "Validating Python source and Elasticsearch authentication"
"${VENV_DIR}/bin/python" -m py_compile "${SERVER_FILE}"
sudo -u "${CLIENT_USER}" "${VENV_DIR}/bin/python" - <<'PYTHON'
import sys
sys.path.insert(0, "/opt/mcp-servers/elasticsearch")
import elasticsearch_mcp_server as server
info = server.es.info().body
print(f"Connected to Elasticsearch {info['version']['number']} on {info['name']}")
PYTHON

cat <<EOF

Installation complete.

VS Code Remote SSH user: ${CLIENT_USER}
Server command: ${VENV_DIR}/bin/python ${SERVER_FILE}

Reconnect the VS Code SSH session so the new ${MCP_GROUP} group membership applies.
Then add this server to the remote workspace .vscode/mcp.json:

{
  "servers": {
    "internalElasticsearch": {
      "type": "stdio",
      "command": "${VENV_DIR}/bin/python",
      "args": ["${SERVER_FILE}"]
    }
  }
}
EOF
