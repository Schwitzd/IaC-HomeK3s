# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Purpose

Infrastructure as Code for the **Farm** K3s home cluster — 3 physical nodes (sheep: RPi5 control-plane, cow: RPi5 worker, duck: i7 ThinkCentre AI worker). Uses a dual-bootstrap strategy: OpenTofu provisions essential services first, then hands off to Argo CD (GitOps) for continuous reconciliation.

## Tooling

- **OpenTofu** (not Terraform) — manages all cluster resources
- **Ansible** — node bootstrap and system configuration
- **Argo CD** — GitOps controller (deployed via OpenTofu, then takes over)
- **K3s** — installed manually per node using the official script

## Common Commands

### OpenTofu

```bash
cd terraform

tofu init
tofu plan --var-file=variables.tfvars
tofu apply --var-file=variables.tfvars
tofu apply --var-file=variables.tfvars --target=<resource>   # target specific resource
tofu import --var-file=variables.tfvars <resource> <id>
```

### Ansible

```bash
cd ansible

# Install dependencies
ansible-galaxy role install -r requirements.yaml --force
ansible-galaxy collection install -r requirements.yaml --force

# Bootstrap IPv6 on nodes
ansible-playbook -i inventory.yaml playbooks/bootstrap-ipv6.yaml -u k3s --ask-pass

# Bootstrap SSH auth (run per node)
ansible-playbook -i inventory.yaml playbooks/bootstrap-ssh.yaml --extra-vars "target=<node>" -u k3s --ask-pass

# K3s configuration (supports tags)
ansible-playbook -i inventory.yaml playbooks/k3s.yaml --tag <tag>
```

Available Ansible tags — pre-K3s: `sshd`, `apt`, `k3s-cgroup`; post-K3s: `k3s-cilium`, `k3s-rook-ceph`, `k3s-post`, `k3s-config`, `k3s-config-local`, `k3s-aliases`, `shutdown-startup`.

## Architecture

### Terraform Directory (`terraform/`)

One `.tf` file per major service (e.g., `argocd.tf`, `cilium.tf`, `traefik.tf`, `cert-manager.tf`, `rook-ceph.tf`, `prometheus.tf`, `postgresql.tf`). Shared configuration lives in:
- `main.tf` — provider instantiation
- `provider.tf` — provider configuration
- `inputs.tf` — variable declarations (`vault_url`, `vault_token`, `vault_name`)
- `locals.tf` — namespaces, Helm repo URLs, job definitions

**Helm values**: `*-values.yaml` files in `terraform/` are templates passed to `helm_release` resources.

**Network policies**: `terraform/network-policies/*.yaml` — Cilium policies applied via `fileset()` after CNI is up.

**Vault sub-module** (`terraform/iac_vault/`): Manages OpenBao identity, policies, tokens, and secret engines. Applied separately. Uses reusable modules from `github.com/Schwitzd/terraform-modules`.

### Ansible Directory (`ansible/`)

- `inventory.yaml` — defines the 3 cluster nodes
- `host_vars/{sheep,cow,duck}.yaml` — per-node settings (role, IPv6 config)
- `group_vars/all.yaml` — shared settings (k3s_version, kubeconfig context, API FQDN)
- `playbooks/` — bootstrap playbooks (IPv6, SSH, K3s)
- `roles/` — custom roles; community roles pulled via `requirements.yaml`

### Provider Configuration

All providers connect to the local kubeconfig:
```hcl
config_path    = "~/.kube/config"
config_context = "homefarm"
insecure       = true
```

Two Vault provider instances: one pointing at the local laptop bootstrap Vault, one at the Farm cluster Vault (credentials fetched from the bootstrap Vault). ArgoCD, Garage, and Azure providers also pull credentials from Vault.

### Secrets Pattern

- Secrets are **never in git** — pulled from Vault via `data.vault_generic_secret` data sources at apply time
- `variables.tfvars` is gitignored — contains `vault_url`, `vault_token`, `vault_name`
- K3s runs with `--secrets-encryption` for AES-CBC encryption at rest
- Post-bootstrap: External Secrets Operator pulls runtime secrets from OpenBao

### Bootstrap Order

1. Cilium CNI → CoreDNS → Cert-Manager + Farm CA → Traefik (Gateway API)
2. Argo CD deployed and GitOps repo registered
3. OpenBao + External Secrets Operator
4. Keycloak IdP
5. Remaining workloads handed to Argo CD (`github.com/Schwitzd/GitOps-HomeK3s`)
