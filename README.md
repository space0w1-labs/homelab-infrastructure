# homelab-infrastructure

Infrastructure and deployment configuration for my homelab, which runs on Proxmox and k3s.

| Path | Contents |
|---|---|
| `.github/workflows/` | `claude-review.yml`: Claude reviews every PR on the self-hosted runner (shared workflow in `space0w1-labs/ci`) |
| `apps/` | Kubernetes manifests for the Edison and Signal apps |
| `cluster-system/` | Cluster components: ArgoCD and the private registry |
| `terraform/github-runner/` | Terraform for the self-hosted GitHub Actions runner VM ([docs](terraform/github-runner/README.md)) |
| `terraform/tailscale-router/` | Terraform for the Tailscale subnet-router LXC ([docs](terraform/tailscale-router/README.md)) |
| `ansible/tailscale-router/` | Ansible that installs and configures Tailscale in that LXC |
