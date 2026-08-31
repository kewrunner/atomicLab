# Apache Domain VirtualHosts

`deploy.yml` manages explicitly requested Apache reverse-proxy sites on Debian
and Ubuntu hosts. It accepts `sites_add` as a domain, comma-separated domains,
or an Ansible list and normalizes the values into `apache_sites_to_add`.

The backend variable is `apache_proxy_backend`, defaulting to
`http://127.0.0.1:5601`. Only absolute `http://` and `https://` backends without
paths are accepted. WebSocket upgrades derive `ws://` or `wss://` from that
backend; ordinary HTTP uses `ProxyPass` and `ProxyPassReverse`.

Managed files are `/etc/apache2/sites-available/<domain>.conf` and
`<domain>-le-ssl.conf`, marked with:

```text
# Managed by Ansible: apache-domain-vhost-management
```

Unmanaged files at those deterministic paths are never overwritten. HTTPS is
rendered only when both Let’s Encrypt files exist under
`/etc/letsencrypt/live/<domain>/`. Existing managed HTTPS files are retained if
certificates later disappear and the inconsistency is reported.

The workflow validates the Debian Apache layout, required modules, all domains,
the backend, and ownership before changing files. Changed managed state runs
`apache2ctl configtest`; Apache is reloaded only after a successful test. V1
does not roll back files after a failed test, request certificates, install
Apache, change DNS/firewalls, delete vhosts, or disable unrelated sites.

Example:

```bash
ansible-playbook -i inventory deploy.yml \
  -e 'sites_add=elastic.atomicharvest.com, elastic.wazo.tv' \
  -e apache_proxy_backend=http://127.0.0.1:5601
```
