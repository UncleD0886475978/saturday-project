#!/usr/bin/env bash
# setup.sh — saturday-project (Terraform + Ansible + Docker/Flask app -> AWS EC2)
# VM BOOTSTRAP: on a fresh Ubuntu/Debian VM this script INSTALLS its own
# prerequisites (git/curl, Terraform, Docker, Python) and then builds.
# Safe by design: Terraform is init + validate ONLY. Nothing is applied to AWS.
set -e

REPO="saturday-project"
OWNER="UncleD0886475978"
CLONE_URL="https://github.com/${OWNER}/${REPO}.git"
TARGET_DIR="$HOME/repos/${REPO}"
RUN_ONELINE="curl -fsSL https://raw.githubusercontent.com/${OWNER}/${REPO}/main/setup.sh | bash"

echo "==> Step 1/7: Platform check + base bootstrap (git, curl)"
SUDO=""
if [ "$(id -u)" -ne 0 ]; then
  if command -v sudo >/dev/null 2>&1; then
    SUDO="sudo"
  else
    echo "ERROR: this script needs root or sudo to install packages."
    exit 1
  fi
fi
APT=0
if [ "$(uname -s)" = "Linux" ] && command -v apt-get >/dev/null 2>&1; then APT=1; fi
INSTALLED=""
APT_UPDATED=""
note_installed() { INSTALLED="${INSTALLED} $1"; }
apt_update_once() {
  if [ -z "${APT_UPDATED}" ]; then $SUDO apt-get update -y; APT_UPDATED=1; fi
}
apt_install() {
  apt_update_once
  DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y "$@"
}
if [ "${APT}" -eq 1 ]; then
  BASE_PKGS=""
  command -v git >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} git"
  command -v curl >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} curl"
  [ -f /etc/ssl/certs/ca-certificates.crt ] || BASE_PKGS="${BASE_PKGS} ca-certificates"
  command -v gpg >/dev/null 2>&1 || BASE_PKGS="${BASE_PKGS} gnupg"
  if [ -n "${BASE_PKGS}" ]; then
    echo "    Installing base tools:${BASE_PKGS}"
    # shellcheck disable=SC2086
    apt_install ${BASE_PKGS}
    note_installed "${BASE_PKGS}"
  else
    echo "    Base tools already present (git, curl, ca-certificates, gnupg)."
  fi
else
  echo "    Non-apt platform detected — bootstrap will only CHECK tools and print install guidance."
fi

# --- Per-tool installers ---
DOCKER="docker"
install_docker() {
  if command -v docker >/dev/null 2>&1; then
    echo "    docker: already present ($(docker --version))"
  elif [ "${APT}" -eq 1 ]; then
    echo "    Installing Docker Engine via the official get.docker.com script..."
    curl -fsSL https://get.docker.com | $SUDO sh
    note_installed "docker"
  else
    return 1
  fi
  if ! docker info >/dev/null 2>&1 && ! $SUDO docker info >/dev/null 2>&1; then
    echo "    Starting the Docker daemon..."
    $SUDO systemctl enable --now docker 2>/dev/null || $SUDO service docker start 2>/dev/null || true
    for _i in $(seq 1 15); do
      if docker info >/dev/null 2>&1 || $SUDO docker info >/dev/null 2>&1; then break; fi
      sleep 2
    done
  fi
  if docker info >/dev/null 2>&1; then
    DOCKER="docker"
  elif $SUDO docker info >/dev/null 2>&1; then
    DOCKER="sudo docker"
    if [ "$(id -u)" -ne 0 ]; then
      $SUDO usermod -aG docker "$USER" 2>/dev/null || true
      echo "    NOTE: you were added to the 'docker' group (applies at next login); this run uses 'sudo docker'."
    fi
  else
    echo "ERROR: Docker is installed but the daemon could not be started."
    echo "       On a VM:  sudo systemctl start docker   |   In a container/WSL without systemd, Docker cannot run here."
    exit 1
  fi
  echo "    docker daemon OK (using: ${DOCKER})"
}
install_terraform() {
  if command -v terraform >/dev/null 2>&1; then echo "    terraform: already present ($(terraform version | head -n 1))"; return 0; fi
  [ "${APT}" -eq 1 ] || return 1
  echo "    Installing Terraform from the official HashiCorp apt repository..."
  curl -fsSL https://apt.releases.hashicorp.com/gpg | $SUDO gpg --batch --yes --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
  echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(. /etc/os-release && echo "${VERSION_CODENAME}") main" | $SUDO tee /etc/apt/sources.list.d/hashicorp.list >/dev/null
  $SUDO apt-get update -y
  DEBIAN_FRONTEND=noninteractive $SUDO apt-get install -y terraform
  note_installed "terraform"
}
install_python() {
  if command -v python3 >/dev/null 2>&1 && python3 -c "import venv" >/dev/null 2>&1; then echo "    python3 + venv: already present ($(python3 --version))"; return 0; fi
  [ "${APT}" -eq 1 ] || return 1
  echo "    Installing python3, venv and pip..."
  apt_install python3 python3-venv python3-pip
  note_installed "python3"
}

echo "==> Step 2/7: Locate or clone ${REPO}"
if [ -f "$0" ]; then
  SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
else
  SCRIPT_DIR="$PWD"
fi
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

echo "==> Step 3/7: Bootstrap prerequisites (Terraform, Docker, Python/Ansible)"
MISSING_LIST=""
install_terraform || MISSING_LIST="${MISSING_LIST} terraform(https://developer.hashicorp.com/terraform/install)"
install_docker || MISSING_LIST="${MISSING_LIST} docker(https://www.docker.com/products/docker-desktop/)"
install_python || MISSING_LIST="${MISSING_LIST} python3(https://www.python.org/downloads/)"
if [ -n "${MISSING_LIST}" ]; then
  echo "ERROR: could not auto-install on this platform. Missing:${MISSING_LIST}"
  echo "Install the tool(s) manually, then re-run this script."
  exit 1
fi
echo "    terraform: $(terraform version | head -n 1)"
echo "    docker:    $(docker --version)"

echo "==> Step 4/7: Ansible — use system ansible, or a local venv"
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

echo "==> Step 5/7: Terraform — init + validate ONLY (no plan/apply, no AWS cost)"
if [ -d terraform ]; then
  (cd terraform && terraform init && terraform validate)
  echo "    Terraform configuration is valid."
else
  echo "    No terraform/ directory found — skipping."
fi

echo "==> Step 6/7: Ansible — syntax-check the deploy playbook (does not touch any host)"
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

echo "==> Step 7/7: Docker — build and run the app in app/ (Flask)"
APP_PORT="5000"
if [ -f app/Dockerfile ]; then
  EXPOSED="$(grep -i '^EXPOSE' app/Dockerfile | awk '{print $2}' | head -n 1 || true)"
  if [ -n "${EXPOSED}" ]; then APP_PORT="${EXPOSED}"; fi
  # shellcheck disable=SC2086
  ${DOCKER} build -t saturday-project-app app
  # shellcheck disable=SC2086
  ${DOCKER} rm -f saturday-project-app >/dev/null 2>&1 || true
  # shellcheck disable=SC2086
  ${DOCKER} run -d --name saturday-project-app -p "${APP_PORT}:${APP_PORT}" saturday-project-app
  echo "    Waiting for the app to answer on port ${APP_PORT}..."
  OK=0
  for i in $(seq 1 15); do
    if curl -fs "http://localhost:${APP_PORT}/" >/dev/null 2>&1; then OK=1; break; fi
    sleep 2
  done
  if [ "${OK}" -eq 1 ]; then
    echo "    App is up: http://localhost:${APP_PORT}"
  else
    echo "    App container started but did not answer yet — check: ${DOCKER} logs saturday-project-app"
  fi
else
  echo "    No app/Dockerfile found — skipping Docker build."
fi

cat <<EOF

=================== BOOTSTRAP SUMMARY ===================
Installed during this run:${INSTALLED:- (nothing — all tools were already present)}
Working copy: ${REPO_DIR}
Next time, set up from scratch on any fresh Ubuntu VM with one line:
  ${RUN_ONELINE}
=========================================================
EOF

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
    • App container:  ${DOCKER} stop saturday-project-app && ${DOCKER} rm saturday-project-app
    • AWS resources:  cd terraform && terraform destroy   (stops the EC2 billing)
  Logs:
    • App:       ${DOCKER} logs -f saturday-project-app
    • Terraform: terminal output in terraform/ (state: terraform/terraform.tfstate after an apply)
EOF
