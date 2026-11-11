# Tailscale subnet router (Proxmox LXC)

> **Status:** deployed 2026-11-07 as VMID 200 (`192.168.2.51`, `tailscale-router`) on proxmoxtwo. This replaced the earlier hand-built router.

Terraform creates an unprivileged Debian 12 LXC with `/dev/net/tun` passed through. Ansible then installs Tailscale, enables IP forwarding, and joins the tailnet as a subnet router for `192.168.2.0/24`.

| Path | Purpose |
|---|---|
| `terraform/tailscale-router/` | The container (this directory) |
| `ansible/tailscale-router/` | Configuration inside the container |

This code defines the lab's subnet router: VMID 200, `192.168.2.51`, hostname `tailscale-router`. Rebuilding it from scratch means `terraform apply`, then the Ansible playbook, then approving the route.

## Lab addresses in use

`.1` gateway · `.2` proxmoxone · `.3` Jellyfin · `.7` Jenkins · `.10` workstation · `.50` proxmoxtwo · `.51` this router

`variables.tf` refuses these, but it can't know about anything else. Before you pick a new address, check that nothing answers on it: `ping 192.168.2.52`, then look at the GL.iNet DHCP client list.

## TUN passthrough (the gotcha)

Tailscale needs `/dev/net/tun`. The old way was two raw lines in `/etc/pve/lxc/<id>.conf`:

```
lxc.cgroup2.devices.allow: c 10:200 rwm
lxc.mount.entry: /dev/net/tun dev/net/tun none bind,create=file
```

On Proxmox 8.1+ one line does both jobs, and works for unprivileged containers:

```
dev0: /dev/net/tun
```

bpg can set this natively (`device_passthrough { path = "/dev/net/tun" }`). But Proxmox only lets `root@pam` set `devN` entries for raw device paths, and **API tokens fail that check, even root's own tokens**. To keep token auth, `main.tf` uses a `terraform_data` step that runs this on the node over SSH right after creating the container:

```
pct set <vmid> --dev0 /dev/net/tun && pct reboot <vmid>
```

So `terraform apply` needs SSH key access as root to the target node (`ssh root@192.168.2.50` must work without a password prompt). The container ignores later drift on `device_passthrough`, so plans stay clean.

To use the native block instead, switch the provider to `username = "root@pam"` + `password`, add `device_passthrough { path = "/dev/net/tun" }` to the container, and delete the `terraform_data` resource.

## Prerequisites

1. **Proxmox API token.** Datacenter → Permissions → API Tokens → Add. Easiest is a token on `root@pam` with *Privilege Separation* unchecked. For a dedicated user, give it `PVEVMAdmin` + `PVEDatastoreUser` on `/` (also `Sys.Audit`, `SDN.Use` on PVE 8 with SDN).
2. **SSH as root to the target node** with your key loaded in ssh-agent.
3. **The template on the target node.** `debian-12-standard_12.12-1_amd64.tar.zst` on `local`. It's already on proxmoxtwo. For proxmoxone: `pveam update && pveam download local debian-12-standard_12.12-1_amd64.tar.zst`.
4. **Tailscale auth key.** login.tailscale.com → Settings → Keys → Generate auth key. *Reusable* lets you rebuild without making a new key. *Pre-approved* skips device approval if your tailnet requires it. Keys expire after 90 days at most.
5. **Ansible** on your workstation: `brew install ansible`.

## Usage

### 1. Create the container

```sh
cd terraform/tailscale-router
cp terraform.tfvars.example terraform.tfvars   # fill in
terraform init
terraform apply
```

Check it on the node: `pct config 200 | grep dev0` should print `dev0: /dev/net/tun`.

### 2. Configure it

The encrypted auth key is committed in `group_vars/tailscale_routers/vault.yml`, so a rebuild only needs the vault password:

```sh
cd ansible/tailscale-router
ansible-playbook playbook.yml --ask-vault-pass
ansible-playbook playbook.yml --ask-vault-pass --check --diff   # dry run: show what would change
```

To put in a new auth key (expired, revoked, or rotated), edit the vault in place. **Don't** copy `vault.yml.example` over it, because that replaces the real key with the placeholder:

```sh
ansible-vault edit group_vars/tailscale_routers/vault.yml
```

`vault.yml.example` only shows the format. Use it only when setting this up from scratch somewhere `vault.yml` doesn't exist yet, with `ansible-vault create group_vars/tailscale_routers/vault.yml`. Use a **reusable, non-ephemeral** key.

If you change the IP or hostname, update `inventory.ini` to match. You can run the playbook again safely. It only runs `tailscale up` if the node isn't connected yet, and only touches the routes if they differ from `vars.yml`.

### 3. Approve the route (manual)

login.tailscale.com/admin/machines → the new machine → **Edit route settings** → tick `192.168.2.0/24`. This is the one step that isn't codified. (Tailscale ACL `autoApprovers` can automate it if you want to later.)

Then from a device on the tailnet but off the LAN: `ping 192.168.2.2`.

## Replacing the router without losing access

If your workstation reaches `192.168.2.0/24` **through Tailscale** (check with `route -n get 192.168.2.50`: interface `utun*`), then replacing this container cuts Terraform off from Proxmox mid-apply. Changing `vm_id`, `hostname` or `ipv4_address` replaces it. Either:

- **Join the lab network directly** (GL.iNet Wi-Fi or ethernet) before you apply, or
- **Make before break:** bring up a second router first, then replace this one. Apply this module with a separate state (`terraform workspace new temp`) and a free VMID and IP, run the playbook against it, approve its route, and only then replace or destroy the main one. Two routers advertising the same subnet fail over to each other automatically.

After a replacement, remove the old machine from the Tailscale admin console *before* running the playbook. Otherwise the new node gets the name `tailscale-router-1`. Then approve the route again.

`terraform destroy` removes the container. It doesn't remove the machine from your tailnet.
