# Jenkins controller (Proxmox LXC)

> **Status:** migrated 2026-11-09 from a rootless Podman container on the workstation to VMID 109 (`192.168.2.7`, `jenkins`) on proxmoxone. The container was built by hand first and then written up here, so the first `terraform apply` is an **import** (see below), not a create.

Terraform creates an unprivileged Debian 12 LXC with nesting and keyctl turned on so Docker can run inside it. Ansible then installs Java 21, Jenkins (pinned), and Docker (pinned), and lets Docker push to the k3s registry over plain HTTP.

| Path | Purpose |
|---|---|
| `terraform/jenkins/` | The container (this directory) |
| `ansible/jenkins/` | Packages and configuration inside the container |

Jenkins listens on **http://192.168.2.7:8080/**. `JENKINS_HOME` is `/var/lib/jenkins` on the container's root disk. Neither Terraform nor Ansible manages its contents (jobs, credentials, plugins); those come from a backup.

## What the pipelines need from this box

`signal-pipeline` runs `docker build --load` and `docker push` to `192.168.2.100:30500`, then pushes image tags to `space0w1-labs/homelab-infrastructure` with the `github-token-id` credential. (`edison-pipeline` does the same but is retired.) So the container needs:

- Docker that works inside an LXC (nesting + keyctl, and the pinned versions below)
- `192.168.2.100:30500` in Docker's `insecure-registries`
- the `jenkins` user in the `docker` group

`github-token-id` (username `space0w1`) needs write access to this repo, which belongs to the `space0w1-labs` org. Use a classic token with `public_repo`, or a fine-grained token whose resource owner is `space0w1-labs`. A fine-grained token owned by `space0w1` can clone but not push, and the push fails with a 403.

## Gotchas

**keyctl needs SSH.** Proxmox only lets `root@pam` change LXC feature flags other than `nesting`, and API tokens fail that check (the same restriction as `dev0` in `terraform/tailscale-router`). `main.tf` sets `nesting` through the API and adds `keyctl` with `pct set` over SSH, then reboots the container. It skips both if keyctl is already on, so `terraform apply` needs `ssh root@<node>` to work without a password prompt.

**Docker is pinned to 28.5.2 / containerd 1.7.27 (runc 1.2.5).** On Proxmox 8.3, newer runc fails to start any container inside an LXC:

```
open sysctl net.ipv4.ip_unprivileged_port_start file: reopen fd 8: permission denied
```

Docker 29 requires containerd 2.x, so Docker stays on 28 too. runc 1.2.5 predates the late-2025 runc security fixes. **Upgrade the Proxmox host**, then raise `docker_version` / `containerd_version` in `ansible/jenkins/group_vars/jenkins/vars.yml` and re-run the playbook.

**Jenkins is pinned and held.** Plugins are built against a core version. To upgrade: back up `JENKINS_HOME`, raise `jenkins_version`, re-run the playbook, then update plugins in the UI.

**`prevent_destroy` is on.** Anything that would replace the container fails the plan, because replacing it deletes `JENKINS_HOME`. To really rebuild, take a backup first and remove the lifecycle line temporarily.

## Prerequisites

Same as `terraform/tailscale-router`: a Proxmox API token, SSH as root to the node, the Debian 12 template on the node (already on proxmoxone), and Ansible on your workstation.

## Usage

### Adopt the existing container (once)

```sh
cd terraform/jenkins
cp terraform.tfvars.example terraform.tfvars   # fill in
terraform init
terraform import proxmox_virtual_environment_container.jenkins proxmoxone/109
terraform plan    # review: should be in-place changes only (tags, description)
terraform apply
```

The `keyctl` step runs once after import, sees the flag is already set, and doesn't reboot.

Then check that Ansible agrees with what's on the box:

```sh
cd ../../ansible/jenkins
ansible-playbook playbook.yml --check --diff
ansible-playbook playbook.yml
```

The first real run swaps the hand-made apt key files (`*.gpg`) for the `*.asc` files the playbook manages, and rewrites `daemon.json` with different whitespace, which restarts Docker once (don't run it mid-build). Packages, versions, holds and groups already match.

### Rebuild from scratch

1. **Back up `JENKINS_HOME`** from the old container (or use a `vzdump` backup of it):

   ```sh
   ssh root@192.168.2.7 'systemctl stop jenkins && tar -C /var/lib/jenkins --exclude=./war --exclude=./caches -czf - .' > jenkins_home.tgz
   ```

2. Create and configure the container:

   ```sh
   terraform apply
   cd ../../ansible/jenkins && ansible-playbook playbook.yml
   ```

3. Restore `JENKINS_HOME`. `secret.key` and `secrets/` must come along, or every stored credential becomes unreadable:

   ```sh
   ssh root@192.168.2.7 'systemctl stop jenkins && rm -rf /var/lib/jenkins/* && tar -C /var/lib/jenkins -xzf - && chown -R jenkins:jenkins /var/lib/jenkins && systemctl start jenkins' < jenkins_home.tgz
   ```

### Moving to another node

No Terraform needed: `vzdump 109` on the old node, copy the archive, `pct restore 109 <archive>` on the new one (or `pct migrate` if the nodes are clustered). Then point `proxmox_node` / `proxmox_node_ssh_host` at the new node, `terraform state rm proxmox_virtual_environment_container.jenkins`, and import it again as `<new-node>/109`.
