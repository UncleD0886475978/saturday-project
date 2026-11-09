# saturday-project — BUILD

## One-line install (fresh Ubuntu/Debian VM)

```bash
curl -fsSL https://raw.githubusercontent.com/UncleD0886475978/saturday-project/main/setup.sh | bash
```

The script installs its own prerequisites — git/curl via apt, Terraform from the official HashiCorp apt repository, Docker via the official get.docker.com script, and Python 3 (venv/pip) via apt — then clones the repo and builds; Ansible is installed into a local `.venv` with pip if it isn't already present. Alternative (clone-and-run): `git clone https://github.com/UncleD0886475978/saturday-project.git && cd saturday-project && ./setup.sh`.

- **Repo:** `UncleD0886475978/saturday-project` — public, original (not a fork).
- **Stack actually found** (via GitHub connector directory listings):
  - Terraform: `terraform/main.tf`, `terraform/variables.tf`, `terraform/outputs.tf`
  - Ansible: `ansible/deploy.yml`, `ansible/inventory.ini`, `ansible/README.md`
  - Docker + Python: `app/Dockerfile`, `app/app.py`, `app/requirements.txt`, `app/index.html`
  - Root: `README.md`, `.gitignore`, `.github/` — **no docker-compose.yml anywhere found**, so Docker is a single-Dockerfile build/run, not Compose.
- **Inspection note:** the connector returned directory listings, not file bodies, and a later call hit GitHub HTTP 429 (rate limit), so file *contents* (e.g. the exact Flask port / AWS region) were not read. `setup.sh` therefore reads the port from `app/Dockerfile`'s `EXPOSE` line at runtime (default 5000).

## What setup.sh does

1. Bootstraps base tools (git, curl, ca-certificates, gnupg) via apt on Ubuntu/Debian; on non-apt platforms it falls back to checking tools and printing install guidance.
2. Uses the current checkout if its git remote mentions `saturday-project` (or the script sits in the repo root); otherwise clones into `~/repos/saturday-project` (`git pull` if already there).
3. Bootstraps prerequisites — installs terraform (HashiCorp apt repo), docker (get.docker.com, incl. starting the daemon and falling back to `sudo docker` when needed), and python3/venv/pip (apt) if missing; on non-apt platforms prints the install URL for anything it cannot install and exits cleanly.
4. Resolves Ansible: system `ansible-playbook` if present, else creates `.venv` and `pip install ansible`.
5. Terraform: `terraform init` + `terraform validate` in `terraform/` **only** — never apply.
6. Ansible: `ansible-playbook --syntax-check ansible/deploy.yml` against `ansible/inventory.ini` — no host is touched.
7. Docker: builds `app/` and runs it as container `saturday-project-app` (via `${DOCKER}`, i.e. `sudo docker` when needed), waits for an HTTP answer, prints the local URL.
8. Prints a bootstrap summary (tools installed during the run, working copy, one-line reinstall command), then next commands, including the deliberate `terraform plan && terraform apply` step with an AWS EC2 cost warning and the matching `terraform destroy`.

**Issue it prevents:** an accidental `terraform apply` (or a broken playbook/Dockerfile) creating a billable EC2 instance from an unvalidated configuration.
