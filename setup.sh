#!/usr/bin/env bash
# setup.sh — saturday-project (Terraform + Ansible + Docker/Flask app -> AWS EC2)
# Safe by design: Terraform is init + validate ONLY. Nothing is applied to AWS.
set -e

REPO="saturday-project"
OWNER="UncleD0886475978"
CLONE_URL="https://github.com/${OWNER}/${REPO}.git"
TARGET_DIR="$HOME/repos/${REPO}"

echo "==> Step 1/6: Locate or clone ${REPO}"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
if [ -d ".git" ] && git remote get-url origin 2>/dev/null | grep -qi "${REPO}"; then
  REPO_DIR="$PWD"
elif [ -d "${SCRIPT_DIR}/.git" ] && git -C "${SCRIPT_DIR}" remote get-url origin 2>/dev/null | grep -qi "${REPO}"; then
  REPO_DIR="${SCRIPT_DIR}"
elif [ -d "${TARGET_DIR}/.git" ]; then
  REPO_DIR="${TARGET_DIR}"
  git -C "${REPO_DIR}" pull --ff-only || echo "    (git pull skipped/failed — continuing with existing checkout)"
else
  if ! command -v git >/dev/null 2>&1; then
    echo "ERROR: git is not installed. Install it: https://git-scm.com/downloads"
    exit 1
  fi
  mkdir -p "$HOME/repos"
  git clone "${CLONE_URL}" "${TARGET_DIR}"
  REPO_DIR="${TARGET_DIR}"
fi
cd "${REPO_DIR}"
echo "    Working in: ${REPO_DIR}"

echo "==> Step 2/6: Check prerequisites (Terraform, Docker, Python/Ansible)"
MISSING=0
if ! command -v terraform >/dev/null 2>&1; then
  echo "MISSING: terraform — install from https://developer.hashicorp.com/terraform/install"
  MISSING=1
fi
if ! command -v docker >/dev/null 2>&1; then
  echo "MISSING: docker — install Docker Desktop from https://www.docker.com/products/docker-desktop/"
  MISSING=1
fi
if ! command -v python3 >/dev/null 2>&1; then
  echo "MISSING: python3 — install from https://www.python.org/downloads/"
  MISSING=1
fi
if [ "${MISSING}" -ne 0 ]; then
  echo "Install the tool(s) above, then re-run this script."
  exit 1
fi
if ! docker info >/dev/null 2>&1; then
  echo "ERROR: Docker is installed but the daemon is not running. Start Docker Desktop: https://www.docker.com/products/docker-desktop/"
  exit 1
fi
echo "    terraform: $(terraform version | head -n 1)"
echo "    docker:    $(docker --version)"

echo "==> Step 3/6: Ansible — use system ansible, or a local venv"
ANSIBLE_PLAYBOOK=""
if command -v ansible-playbook >/dev/null 2>&1; then
  ANSIBLE_PLAYBOOK="ansible-playbook"
elif [ -x ".venv/bin/ansible-playbook" ]; then
  ANSIBLE_PLAYBOOK=".venv/bin/ansible-playbook"
else
  echo "    ansible not found — creating .venv and installing ansible with pip..."
  python3 -m venv .venv
  .venv/bin/pip install --upgrade pip >/dev/null
  .venv/bin/pip install ansible
  ANSIBLE_PLAYBOOK=".venv/bin/ansible-playbook"
fi
echo "    Using: ${ANSIBLE_PLAYBOOK}"

echo "==> Step 4/6: Terraform — init + validate ONLY (no plan/apply, no AWS cost)"
if [ -d terraform ]; then
  (cd terraform && terraform init && terraform validate)
  echo "    Terraform configuration is valid."
else
  echo "    No terraform/ directory found — skipping."
fi

echo "==> Step 5/6: Ansible — syntax-check the deploy playbook (does not touch any host)"
if [ -f ansible/deploy.yml ]; then
  if [ -f ansible/inventory.ini ]; then
    ${ANSIBLE_PLAYBOOK} -i ansible/inventory.ini --syntax-check ansible/deploy.yml
  else
    ${ANSIBLE_PLAYBOOK} --syntax-check ansible/deploy.yml
  fi
  echo "    ansible/deploy.yml syntax OK."
else
  echo "    No ansible/deploy.yml found — skipping."
fi

echo "==> Step 6/6: Docker — build and run the app in app/ (Flask)"
APP_PORT="5000"
if [ -f app/Dockerfile ]; then
  EXPOSED="$(grep -i '^EXPOSE' app/Dockerfile | awk '{print $2}' | head -n 1 || true)"
  if [ -n "${EXPOSED}" ]; then APP_PORT="${EXPOSED}"; fi
  docker build -t saturday-project-app app
  docker rm -f saturday-project-app >/dev/null 2>&1 || true
  docker run -d --name saturday-project-app -p "${APP_PORT}:${APP_PORT}" saturday-project-app
  echo "    Waiting for the app to answer on port ${APP_PORT}..."
  OK=0
  for i in $(seq 1 15); do
    if curl -fs "http://localhost:${APP_PORT}/" >/dev/null 2>&1; then OK=1; break; fi
    sleep 2
  done
  if [ "${OK}" -eq 1 ]; then
    echo "    App is up: http://localhost:${APP_PORT}"
  else
    echo "    App container started but did not answer yet — check: docker logs saturday-project-app"
  fi
else
  echo "    No app/Dockerfile found — skipping Docker build."
fi

cat <<EOF

✅ saturday-project verified locally (Terraform validated, playbook syntax-checked, app container built).

NEXT COMMANDS
  Run/use:
    • App (already running):  http://localhost:${APP_PORT}
    • Re-check Terraform:      cd terraform && terraform validate
    • Deploy for real (DELIBERATE — this is the only step that creates AWS resources):
          cd terraform && terraform plan && terraform apply
      ⚠️ AWS COST WARNING: apply creates a real EC2 instance in AWS and it bills
         by the hour until destroyed. The Ansible deploy then targets the host
         in ansible/inventory.ini:  ansible-playbook -i ansible/inventory.ini ansible/deploy.yml
  Stop:
    • App container:  docker stop saturday-project-app && docker rm saturday-project-app
    • AWS resources:  cd terraform && terraform destroy   (stops the EC2 billing)
  Logs:
    • App:       docker logs -f saturday-project-app
    • Terraform: terminal output in terraform/ (state: terraform/terraform.tfstate after an apply)
EOF
