#!/usr/bin/env bash
set -euo pipefail

# ============================================================================
# buildit — WSL Development Environment Setup
# ============================================================================
#
# This script sets up a fresh WSL instance for the buildit + ibah stack.
# Run it from anywhere — it creates all required directories and configs.
#
# What it does:
#   1. Installs system packages (git, curl, docker, etc.)
#   2. Installs Bun (JS runtime used by ibah MCP)
#   3. Installs Node.js via Homebrew/Linuxbrew
#   4. Installs Claude Code CLI
#   5. Installs GitHub CLI (gh)
#   6. Clones the ibah and buildit repos
#   7. Installs ibah dependencies
#   8. Starts ibah infrastructure (Postgres, RabbitMQ, server, worker, dashboard)
#   9. Configures Claude Code MCP + plugins
#  10. Configures WSL networking (mirrored mode)
#
# Prerequisites:
#   - WSL2 with Ubuntu (22.04+)
#   - Windows Terminal or equivalent
#   - An Anthropic API key (for Claude Code)
#   - A GitHub account (gh auth login)
#
# Usage:
#   chmod +x setup-wsl.sh
#   ./setup-wsl.sh
#
# ============================================================================

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log()  { echo -e "${GREEN}[✓]${NC} $1"; }
warn() { echo -e "${YELLOW}[!]${NC} $1"; }
info() { echo -e "${BLUE}[i]${NC} $1"; }
err()  { echo -e "${RED}[✗]${NC} $1"; }

# --- Paths ---
DEV_ROOT="$HOME/Dev/kode4"
IBAH_REPO="$DEV_ROOT/ibah-archaeologist-series"
BUILDIT_REPO="$DEV_ROOT/buildit"
CLAUDE_DIR="$HOME/.claude"
CLAUDE_PLUGINS_DIR="$CLAUDE_DIR/plugins"

GITHUB_USER="ticky74"
IBAH_GITHUB_REPO="ticky74/ibah-archaeologist-series"
BUILDIT_GITHUB_REPO="ticky74/buildit"

echo ""
echo "============================================"
echo "  buildit — WSL Development Setup"
echo "============================================"
echo ""

# ============================================================================
# 1. SYSTEM PACKAGES
# ============================================================================
info "Updating system packages..."
sudo apt-get update -qq
sudo apt-get install -y -qq \
  build-essential \
  ca-certificates \
  curl \
  git \
  gnupg \
  lsb-release \
  unzip \
  wget \
  jq \
  > /dev/null 2>&1
log "System packages installed"

# ============================================================================
# 2. DOCKER
# ============================================================================
if command -v docker &>/dev/null; then
  log "Docker already installed ($(docker --version))"
else
  info "Installing Docker..."
  sudo install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
  sudo chmod a+r /etc/apt/keyrings/docker.gpg
  echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
    $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
  sudo apt-get update -qq
  sudo apt-get install -y -qq docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin > /dev/null 2>&1
  sudo usermod -aG docker "$USER"
  log "Docker installed — you may need to restart WSL for group membership to take effect"
fi

# Ensure docker compose (v2 plugin) works
if docker compose version &>/dev/null; then
  log "Docker Compose v2 available"
else
  warn "Docker Compose v2 plugin not found. Install: sudo apt-get install docker-compose-plugin"
fi

# ============================================================================
# 3. BUN
# ============================================================================
if command -v bun &>/dev/null; then
  log "Bun already installed ($(bun --version))"
else
  info "Installing Bun..."
  curl -fsSL https://bun.sh/install | bash
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
  log "Bun installed ($(bun --version))"
fi

# ============================================================================
# 4. NODE.JS (via Linuxbrew)
# ============================================================================
if command -v node &>/dev/null; then
  log "Node.js already installed ($(node --version))"
else
  info "Installing Linuxbrew + Node.js..."
  if ! command -v brew &>/dev/null; then
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
    echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >> "$HOME/.bashrc"
  fi
  brew install node
  log "Node.js installed ($(node --version))"
fi

# ============================================================================
# 5. GITHUB CLI
# ============================================================================
if command -v gh &>/dev/null; then
  log "GitHub CLI already installed ($(gh --version | head -1))"
else
  info "Installing GitHub CLI..."
  (type -p wget >/dev/null || sudo apt-get install wget -y) \
    && sudo mkdir -p -m 755 /etc/apt/keyrings \
    && out=$(mktemp) && wget -nv -O"$out" https://cli.github.com/packages/githubcli-archive-keyring.gpg \
    && cat "$out" | sudo tee /etc/apt/keyrings/githubcli-archive-keyring.gpg > /dev/null \
    && sudo chmod go+r /etc/apt/keyrings/githubcli-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli-stable.list > /dev/null \
    && sudo apt-get update -qq \
    && sudo apt-get install gh -y -qq > /dev/null 2>&1
  log "GitHub CLI installed"
fi

# Check gh auth
if gh auth status &>/dev/null; then
  log "GitHub CLI authenticated as $(gh api user -q .login 2>/dev/null || echo 'unknown')"
else
  warn "GitHub CLI not authenticated. Run: gh auth login"
fi

# ============================================================================
# 6. CLAUDE CODE CLI
# ============================================================================
if command -v claude &>/dev/null; then
  log "Claude Code already installed ($(claude --version 2>/dev/null || echo 'unknown'))"
else
  info "Installing Claude Code CLI..."
  npm install -g @anthropic-ai/claude-code
  log "Claude Code installed"
fi

# ============================================================================
# 7. PROJECT DIRECTORY STRUCTURE
# ============================================================================
info "Creating project directories..."
mkdir -p "$DEV_ROOT"
mkdir -p "$CLAUDE_DIR/plugins"
mkdir -p "$CLAUDE_DIR/projects"
log "Directory structure ready: $DEV_ROOT"

# ============================================================================
# 8. CLONE REPOS
# ============================================================================
if [ -d "$IBAH_REPO/.git" ]; then
  log "ibah repo already cloned at $IBAH_REPO"
else
  info "Cloning ibah-archaeologist-series..."
  gh repo clone "$IBAH_GITHUB_REPO" "$IBAH_REPO"
  log "ibah repo cloned"
fi

if [ -d "$BUILDIT_REPO/.git" ]; then
  log "buildit repo already cloned at $BUILDIT_REPO"
else
  info "Cloning buildit..."
  gh repo clone "$BUILDIT_GITHUB_REPO" "$BUILDIT_REPO"
  log "buildit repo cloned"
fi

# ============================================================================
# 9. INSTALL IBAH DEPENDENCIES
# ============================================================================
info "Installing ibah dependencies..."
cd "$IBAH_REPO"
bun install
log "ibah dependencies installed"

# ============================================================================
# 10. IBAH ENVIRONMENT FILE
# ============================================================================
if [ -f "$IBAH_REPO/.env" ]; then
  log "ibah .env already exists"
else
  if [ -f "$IBAH_REPO/.env.example" ]; then
    cp "$IBAH_REPO/.env.example" "$IBAH_REPO/.env"
    warn "Created $IBAH_REPO/.env from .env.example — edit it with your API keys:"
    echo ""
    echo "    Required keys:"
    echo "      VOYAGE_API_KEY     — embeddings (https://dash.voyageai.com)"
    echo "      OPENROUTER_API_KEY — LLM access (https://openrouter.ai)"
    echo ""
  else
    warn "No .env.example found — create $IBAH_REPO/.env manually"
  fi
fi

# ============================================================================
# 11. START IBAH INFRASTRUCTURE (Docker)
# ============================================================================
info "Starting ibah infrastructure (Postgres, RabbitMQ, server, worker, dashboard)..."
cd "$IBAH_REPO/infra"

# Check if containers are already running
if docker ps --format '{{.Names}}' | grep -q 'ibah-postgres'; then
  log "ibah containers already running"
else
  docker compose up -d --build
  info "Waiting for services to be healthy..."
  sleep 10

  # Wait for postgres
  for i in {1..30}; do
    if docker exec ibah-postgres pg_isready -U archeologist &>/dev/null; then
      break
    fi
    sleep 2
  done

  if docker exec ibah-postgres pg_isready -U archeologist &>/dev/null; then
    log "Postgres is healthy"
  else
    err "Postgres failed to start — check: docker logs ibah-postgres"
  fi
fi

# ============================================================================
# 12. CONFIGURE CLAUDE CODE — MCP SERVERS
# ============================================================================
info "Configuring Claude Code MCP for buildit..."

BUILDIT_MCP_FILE="$BUILDIT_REPO/.mcp.json"
cat > "$BUILDIT_MCP_FILE" <<EOF
{
  "mcpServers": {
    "ibah": {
      "command": "bun",
      "args": ["run", "$IBAH_REPO/packages/ibah-mcp/src/index.ts"],
      "env": {
        "IBAH_SERVER_URL": "http://localhost:3100",
        "IBAH_API_KEY": "dev-local-key"
      }
    }
  }
}
EOF
log "MCP config written to $BUILDIT_MCP_FILE"

# Project-level settings for Claude Code
BUILDIT_CLAUDE_SETTINGS="$BUILDIT_REPO/.claude/settings.local.json"
mkdir -p "$(dirname "$BUILDIT_CLAUDE_SETTINGS")"
cat > "$BUILDIT_CLAUDE_SETTINGS" <<EOF
{
  "enableAllProjectMcpServers": true,
  "enabledMcpjsonServers": [
    "ibah"
  ]
}
EOF
log "Claude Code project settings written"

# ============================================================================
# 13. INSTALL CLAUDE CODE PLUGINS
# ============================================================================
info "Installing Claude Code plugins..."

install_plugin() {
  local name="$1"
  local marketplace="$2"
  if claude plugin install "${name}@${marketplace}" --yes 2>/dev/null; then
    log "Plugin installed: $name"
  else
    warn "Plugin $name may already be installed or failed — check manually"
  fi
}

# Core plugins used by buildit
install_plugin "code-simplifier" "claude-plugins-official"
install_plugin "security-guidance" "claude-plugins-official"
install_plugin "security-scanning" "claude-code-workflows"

# ============================================================================
# 14. WSL NETWORKING — MIRRORED MODE
# ============================================================================
info "Configuring WSL networking..."

# The .wslconfig file lives on the Windows side
WIN_HOME=$(wslpath "$(cmd.exe /C 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')" 2>/dev/null || echo "")

if [ -n "$WIN_HOME" ]; then
  WSLCONFIG="$WIN_HOME/.wslconfig"

  if [ -f "$WSLCONFIG" ]; then
    if grep -q 'networkingMode=mirrored' "$WSLCONFIG" 2>/dev/null; then
      log ".wslconfig already has mirrored networking"
    else
      warn ".wslconfig exists but doesn't have mirrored networking"
      echo ""
      echo "    Add/update the following in $WSLCONFIG:"
      echo ""
      echo "    [wsl2]"
      echo "    networkingMode=mirrored"
      echo "    dnsTunneling=true"
      echo "    firewall=true"
      echo ""
    fi
  else
    info "Creating .wslconfig with mirrored networking..."
    cat > "$WSLCONFIG" <<'WSLEOF'
[wsl2]
memory=20GB
swap=4GB
processors=4
networkingMode=mirrored
dnsTunneling=true
firewall=true
WSLEOF
    log ".wslconfig created at $WSLCONFIG"
    warn "Restart WSL for networking changes to take effect: wsl --shutdown"
  fi
else
  warn "Could not detect Windows home directory"
  echo ""
  echo "    Manually create C:\\Users\\<you>\\.wslconfig with:"
  echo ""
  echo "    [wsl2]"
  echo "    memory=20GB"
  echo "    swap=4GB"
  echo "    processors=4"
  echo "    networkingMode=mirrored"
  echo "    dnsTunneling=true"
  echo "    firewall=true"
  echo ""
fi

# WSL-side /etc/wsl.conf
if [ -f /etc/wsl.conf ]; then
  log "/etc/wsl.conf already exists"
else
  info "Creating /etc/wsl.conf..."
  sudo tee /etc/wsl.conf > /dev/null <<'WSLCONF'
[network]
generateResolvConf = true

[boot]
systemd = true

[automount]
options = "metadata,umask=22,fmask=11"
WSLCONF
  log "/etc/wsl.conf created"
fi

# ============================================================================
# 15. SHELL PROFILE — PATH SETUP
# ============================================================================
info "Ensuring PATH entries in .bashrc..."

BASHRC="$HOME/.bashrc"

add_to_bashrc() {
  local line="$1"
  if ! grep -qF "$line" "$BASHRC" 2>/dev/null; then
    echo "$line" >> "$BASHRC"
    log "Added to .bashrc: $line"
  fi
}

add_to_bashrc 'export BUN_INSTALL="$HOME/.bun"'
add_to_bashrc 'export PATH="$BUN_INSTALL/bin:$PATH"'
add_to_bashrc 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"'

# ============================================================================
# 16. VERIFY EVERYTHING
# ============================================================================
echo ""
echo "============================================"
echo "  Verification"
echo "============================================"
echo ""

check() {
  local name="$1"
  local cmd="$2"
  if eval "$cmd" &>/dev/null; then
    log "$name"
  else
    err "$name"
  fi
}

check "git installed"               "git --version"
check "docker installed"            "docker --version"
check "docker compose installed"    "docker compose version"
check "bun installed"               "bun --version"
check "node installed"              "node --version"
check "gh installed"                "gh --version"
check "claude installed"            "claude --version"
check "gh authenticated"            "gh auth status"
check "ibah repo exists"            "test -d $IBAH_REPO/.git"
check "buildit repo exists"         "test -d $BUILDIT_REPO/.git"
check "ibah node_modules"           "test -d $IBAH_REPO/node_modules"
check "ibah .env exists"            "test -f $IBAH_REPO/.env"
check "ibah-postgres running"       "docker ps --format '{{.Names}}' | grep -q ibah-postgres"
check "ibah-rabbitmq running"       "docker ps --format '{{.Names}}' | grep -q ibah-rabbitmq"
check "ibah-server running"         "docker ps --format '{{.Names}}' | grep -q ibah-server"
check "ibah-worker running"         "docker ps --format '{{.Names}}' | grep -q ibah-worker"
check "ibah-dashboard running"      "docker ps --format '{{.Names}}' | grep -q ibah-dashboard"
check "ibah API responding"         "curl -sf http://localhost:3100/api/v1/health > /dev/null 2>&1 || curl -sf http://localhost:3100 > /dev/null 2>&1"
check "MCP config exists"           "test -f $BUILDIT_REPO/.mcp.json"
check "WSL mirrored networking"     "grep -q networkingMode=mirrored '$WIN_HOME/.wslconfig' 2>/dev/null || grep -q networkingMode=mirrored /mnt/c/Users/*/.wslconfig 2>/dev/null"

echo ""
echo "============================================"
echo "  Services"
echo "============================================"
echo ""
echo "  ibah API:       http://localhost:3100"
echo "  ibah Dashboard: http://localhost:3000"
echo "  RabbitMQ Admin: http://localhost:15672  (archeologist / local-dev)"
echo "  PostgreSQL:     localhost:5432          (archeologist / local-dev)"
echo ""
echo "============================================"
echo "  Next Steps"
echo "============================================"
echo ""
echo "  1. If .env needs API keys, edit: $IBAH_REPO/.env"
echo "  2. cd $BUILDIT_REPO && claude"
echo "  3. The ibah MCP tools (ibah-search, ibah-query) will be available"
echo ""
echo "  If WSL networking was just configured, restart WSL:"
echo "    (from PowerShell) wsl --shutdown"
echo "    Then reopen your terminal."
echo ""
log "Setup complete!"
