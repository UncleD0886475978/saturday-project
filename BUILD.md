# saturday-project — BUILD

- **Repo:** `UncleD0886475978/saturday-project` — public, original (not a fork).
- **Stack actually found** (via GitHub connector directory listings):
  - Terraform: `terraform/main.tf`, `terraform/variables.tf`, `terraform/outputs.tf`
  - Ansible: `ansible/deploy.yml`, `ansible/inventory.ini`, `ansible/README.md`
  - Docker + Python: `app/Dockerfile`, `app/app.py`, `app/requirements.txt`, `app/index.html`
  - Root: `README.md`, `.gitignore`, `.github/` — **no docker-compose.yml anywhere found**, so Docker is a single-Dockerfile build/run, not Compose.
- **Inspection note:** the connector returned directory listings, not file bodies, and a later call hit GitHub HTTP 429 (rate limit), so file *contents* (e.g. the exact Flask port / AWS region) were not read. `setup.sh` therefore reads the port from `app/Dockerfile`'s `EXPOSE` line at runtime (default 5000).

## What setup.sh does

1. Uses the current checkout if its git remote mentions `saturday-project` (or the script sits in the repo root); otherwise clones into `~/repos/saturday-project` (`git pull` if already there).
2. Checks prerequisites — terraform, docker (incl. running daemon), python3 — printing the install URL for anything missing and exiting cleanly.
3. Resolves Ansible: system `ansible-playbook` if present, else creates `.venv` and `pip install ansible`.
4. Terraform: `terraform init` + `terraform validate` in `terraform/` **only** — never apply.
5. Ansible: `ansible-playbook --syntax-check ansible/deploy.yml` against `ansible/inventory.ini` — no host is touched.
6. Docker: builds `app/` and runs it as container `saturday-project-app`, waits for an HTTP answer, prints the local URL.
7. Prints next commands, including the deliberate `terraform plan && terraform apply` step with an AWS EC2 cost warning and the matching `terraform destroy`.

**Issue it prevents:** an accidental `terraform apply` (or a broken playbook/Dockerfile) creating a billable EC2 instance from an unvalidated configuration.
