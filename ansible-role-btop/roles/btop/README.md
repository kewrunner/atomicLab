# Ansible Role: btop

Installs **btop** across Enterprise Linux (RHEL/CentOS/Rocky/Alma) and Ubuntu 24.04 hosts.

## Supported
- RHEL 9
- CentOS 7/8
- Rocky 8/9, AlmaLinux 8/9
- Ubuntu 24.04 (Noble)

## Variables
```yaml
# defaults/main.yml
btop_state: present           # present / latest / absent
btop_install_from_source: false  # fallback only; not implemented in this cut
btop_update_cache: true
btop_epel_enable: true
```

## Usage
```yaml
- hosts: all
  become: true
  roles:
    - btop
```

## Notes
- On RHEL-family systems, the role enables EPEL using the official RPM URL on Red Hat,
  and the `epel-release` package on CentOS/Rocky/Alma.
- If you are on RHEL without subscription, this role still installs the EPEL release RPM
  directly from Fedora mirrors.
```
