#!/usr/bin/env bash
set -euo pipefail

# lago-worktree — Run isolated frontend (and optionally API) instances per git worktree
#
# Creates worktrees of the front repo and optionally the API repo,
# running each on a different port.
# Access via http://localhost:<port>.
#
# Usage:
#   lago-worktree create <branch> [--from-front=<base>] [--from-api=<base>]
#   lago-worktree up <name>
#   lago-worktree down <name>
#   lago-worktree destroy <name>
#   lago-worktree ps

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
FRONT_PATH="$(cd "$SCRIPT_DIR/.." && pwd)"
LAGO_PATH="$(cd "$FRONT_PATH/.." && pwd)"
WORKTREE_DIR="$LAGO_PATH/front-worktrees"

API_PATH="$LAGO_PATH/api"
API_WORKTREE_DIR="$LAGO_PATH/api-worktrees"

# Front ports: 3001, 3002, 3003, ...
PORT_START=3001
# API ports: 4001, 4002, 4003, ...
API_PORT_START=4001

# --- Helpers ---

slot_file() { echo "$LAGO_PATH/.worktree-slots"; }

find_free_port() {
  local sf
  sf="$(slot_file)"
  touch "$sf"
  for i in $(seq 0 99); do
    local p=$((PORT_START + i))
    if ! grep -q ":${p}:" "$sf" 2>/dev/null && ! lsof -i ":${p}" &>/dev/null; then
      echo "$p"
      return
    fi
  done
  echo "Error: no free front port" >&2; exit 1
}

find_free_api_port() {
  local sf
  sf="$(slot_file)"
  touch "$sf"
  for i in $(seq 0 99); do
    local p=$((API_PORT_START + i))
    if ! grep -q ":${p}:" "$sf" 2>/dev/null && ! lsof -i ":${p}" &>/dev/null; then
      echo "$p"
      return
    fi
  done
  echo "Error: no free API port" >&2; exit 1
}

# Slot format: name:front_port:front_base:api_port:api_base
# Without API worktree: LAGO-0001:3001:main::
# With API worktree:    LAGO-0001:3001:main:4001:feat/endpoint
register() {
  local sf; sf="$(slot_file)"; touch "$sf"
  grep -v "^${1}:" "$sf" > "$sf.tmp" 2>/dev/null || true; mv "$sf.tmp" "$sf"
  echo "${1}:${2}:${3}:${4:-}:${5:-}" >> "$sf"
}
unregister() { local sf; sf="$(slot_file)"; if [[ -f "$sf" ]]; then grep -v "^${1}:" "$sf" > "$sf.tmp" 2>/dev/null || true; mv "$sf.tmp" "$sf"; fi; }

get_port()       { local sf; sf="$(slot_file)"; if [[ -f "$sf" ]]; then grep "^${1}:" "$sf" 2>/dev/null | head -1 | cut -d: -f2; fi; true; }
get_front_base() { local sf; sf="$(slot_file)"; if [[ -f "$sf" ]]; then local b; b="$(grep "^${1}:" "$sf" 2>/dev/null | head -1 | cut -d: -f3)"; echo "${b:-main}"; else echo "main"; fi; }
get_api_port()   { local sf; sf="$(slot_file)"; if [[ -f "$sf" ]]; then grep "^${1}:" "$sf" 2>/dev/null | head -1 | cut -d: -f4; fi; true; }
get_api_base()   { local sf; sf="$(slot_file)"; if [[ -f "$sf" ]]; then grep "^${1}:" "$sf" 2>/dev/null | head -1 | cut -d: -f5; fi; true; }

sanitize()   { echo "$1" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/_/g'; }

# --- Commands ---

cmd_create() {
  local branch="" front_base="main" api_base=""

  # Parse arguments: <branch> [--from-front=<base>] [--from-api=<base>]
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --from-front=*)
        front_base="${1#--from-front=}"
        [[ -z "$front_base" ]] && { echo "Error: --from-front requires a branch name." >&2; exit 1; }
        shift ;;
      --from-front)
        [[ -z "${2:-}" ]] && { echo "Error: --from-front requires a branch name." >&2; exit 1; }
        front_base="$2"; shift 2 ;;
      --from-api=*)
        api_base="${1#--from-api=}"
        [[ -z "$api_base" ]] && { echo "Error: --from-api requires a branch name." >&2; exit 1; }
        shift ;;
      --from-api)
        [[ -z "${2:-}" ]] && { echo "Error: --from-api requires a branch name." >&2; exit 1; }
        api_base="$2"; shift 2 ;;
      *)
        [[ -z "$branch" ]] && branch="$1" || { echo "Error: unexpected argument '$1'." >&2; exit 1; }
        shift ;;
    esac
  done

  [[ -z "$branch" ]] && { echo "Usage: lago-worktree create <branch> [--from-front=<base>] [--from-api=<base>]" >&2; exit 1; }

  local name
  name="$(echo "$branch" | sed 's|/|-|g')"

  # Validate front base branch exists locally
  cd "$FRONT_PATH"
  if ! git rev-parse --verify "$front_base" &>/dev/null; then
    echo "Error: front base branch '$front_base' does not exist locally in $FRONT_PATH." >&2; exit 1
  fi

  # Validate API base branch if specified
  local api_port=""
  if [[ -n "$api_base" ]]; then
    if ! git -C "$API_PATH" rev-parse --git-dir &>/dev/null; then
      echo "Error: API repo not found at $API_PATH." >&2; exit 1
    fi
    if ! git -C "$API_PATH" rev-parse --verify "$api_base" &>/dev/null; then
      echo "Error: API base branch '$api_base' does not exist locally in $API_PATH." >&2; exit 1
    fi
  fi

  # --- Front worktree ---
  local wt_path="$WORKTREE_DIR/$name"
  mkdir -p "$WORKTREE_DIR"

  echo "Creating front worktree '$name' (branch: $branch, from $front_base)..."

  git worktree prune 2>/dev/null || true
  if git rev-parse --verify "$branch" &>/dev/null; then
    echo "Error: front branch '$branch' already exists. Use a different branch name." >&2; exit 1
  else
    git worktree add -b "$branch" "$wt_path" "$front_base"
  fi

  # Copy .env from main front
  if [[ -f "$FRONT_PATH/.env" ]]; then
    cp "$FRONT_PATH/.env" "$wt_path/.env"
  fi

  # Install node_modules locally (needed for host commands like codegen)
  echo "Installing dependencies in '$name'..."
  (cd "$wt_path" && pnpm install)

  # --- API worktree (optional) ---
  if [[ -n "$api_base" ]]; then
    local api_wt_path="$API_WORKTREE_DIR/$name"
    mkdir -p "$API_WORKTREE_DIR"

    echo "Creating API worktree '$name' (branch: $branch, from $api_base)..."

    cd "$API_PATH"
    git worktree prune 2>/dev/null || true
    if git rev-parse --verify "$branch" &>/dev/null; then
      echo "Error: API branch '$branch' already exists in $API_PATH. Use a different branch name." >&2; exit 1
    else
      git worktree add -b "$branch" "$api_wt_path" "$api_base"
    fi

    # Copy RSA keys for encryption compatibility with shared DB
    if [[ -d "$API_PATH/config/keys" ]]; then
      mkdir -p "$api_wt_path/config/keys"
      cp -r "$API_PATH/config/keys/." "$api_wt_path/config/keys/"
    fi

    api_port="$(find_free_api_port)"
  fi

  echo ""
  cmd_up "$name" "$front_base" "$api_port" "$api_base"
}

cmd_up() {
  local name="${1:-}" front_base="${2:-}" api_port="${3:-}" api_base="${4:-}"
  [[ -z "$name" ]] && { echo "Usage: lago-worktree up <name>" >&2; exit 1; }

  local wt_path="$WORKTREE_DIR/$name"
  [[ ! -d "$wt_path" ]] && { echo "Error: $wt_path not found. Run: lago-worktree create <branch>" >&2; exit 1; }

  if ! docker ps --format '{{.Names}}' | grep -q 'lago_front_dev'; then
    echo "Error: Main stack not running. Run: lago up -d" >&2; exit 1
  fi

  # Preserve existing values when called standalone (not from cmd_create)
  [[ -z "$front_base" ]] && front_base="$(get_front_base "$name")"
  [[ -z "$api_port" ]]   && api_port="$(get_api_port "$name")"
  [[ -z "$api_base" ]]   && api_base="$(get_api_base "$name")"

  local port san compose_file
  port="$(get_port "$name")"
  [[ -z "$port" ]] && port="$(find_free_port)"
  register "$name" "$port" "$front_base" "$api_port" "$api_base"
  san="$(sanitize "$name")"
  compose_file="$wt_path/docker-compose.worktree.yml"

  # Determine API proxy target
  local api_proxy_target="http://api:3000"
  local codegen_api="http://api:3000/graphql"
  if [[ -n "$api_port" ]]; then
    api_proxy_target="http://lago_api_wt_${san}:3000"
    codegen_api="http://lago_api_wt_${san}:3000/graphql"
  fi

  # Determine codegen URL for host access (localhost, not container name)
  local codegen_host_api="http://localhost:3000/graphql"
  if [[ -n "$api_port" ]]; then
    codegen_host_api="http://localhost:${api_port}/graphql"
  fi

  # Patch .env: API calls go through Vite proxy to avoid CORS
  if [[ -f "$wt_path/.env" ]]; then
    sed -i.bak '/^API_URL=/d; /^LAGO_API_PROXY_TARGET=/d; /^CODEGEN_API=/d' "$wt_path/.env"
    rm -f "$wt_path/.env.bak"
  fi
  {
    echo "API_URL=http://localhost:${port}/api"
    echo "LAGO_API_PROXY_TARGET=${api_proxy_target}"
    echo "CODEGEN_API=${codegen_host_api}"
  } >> "$wt_path/.env"

  # Copy vite.config.ts and .gitignore from main front (has proxy + ignore rules)
  cp "$FRONT_PATH/vite.config.ts" "$wt_path/vite.config.ts"
  cp "$FRONT_PATH/.gitignore" "$wt_path/.gitignore"

  # --- API worktree container (optional) ---
  if [[ -n "$api_port" ]]; then
    local api_wt_path="$API_WORKTREE_DIR/$name"
    local api_compose="$api_wt_path/docker-compose.api-worktree.yml"

    cat > "$api_compose" << YAML
name: lago_wt_${san}

services:
  api:
    image: api_dev
    pull_policy: never
    container_name: lago_api_wt_${san}
    stdin_open: true
    tty: true
    restart: unless-stopped
    command: >
      bash -c "bundle install &&
               rm -f ./tmp/pids/server.pid &&
               ./scripts/generate.rsa.sh &&
               bundle exec rails s -b 0.0.0.0"
    volumes:
      - ${api_wt_path}:/app:cached
    env_file:
      - ${LAGO_PATH}/.env.development.default
      - ${LAGO_PATH}/.env.development
    environment:
      - DATABASE_URL=postgresql://lago:changeme@db:5432/lago
      - REDIS_URL=redis://redis:6379
      - LAGO_REDIS_CACHE_URL=redis://redis:6379
      - LAGO_PDF_URL=http://pdf:3000
      - RAILS_ENV=development
      - LAGO_KAFKA_BOOTSTRAP_SERVERS=redpanda:9092
      - LAGO_KAFKA_RAW_EVENTS_TOPIC=events-raw
      - RAILS_DEVELOPMENT_HOSTS=lago_api_wt_${san}
    ports:
      - "${api_port}:3000"
    networks:
      - lago_net

volumes: {}

networks:
  lago_net:
    external: true
    name: lago_dev_default
YAML

    echo "Starting API worktree '$name' on port ${api_port}..."
    docker compose -f "$api_compose" up -d
  fi

  # --- Front worktree container ---
  cat > "$compose_file" << YAML
name: lago_wt_${san}

services:
  front:
    image: front_dev
    pull_policy: never
    container_name: lago_front_wt_${san}
    stdin_open: true
    restart: unless-stopped
    volumes:
      - ${wt_path}:/app:cached
      - front_nm_wt_${san}:/app/node_modules
      - front_dist_wt_${san}:/app/dist
    environment:
      - NODE_ENV=development
      - API_URL=http://localhost:${port}/api
      - LAGO_API_PROXY_TARGET=${api_proxy_target}
      - LAGO_WORKTREE_NAME=${name}
      - APP_DOMAIN=https://app.lago.dev
      - CODEGEN_API=${codegen_api}
      - LAGO_DISABLE_SIGNUP=\${LAGO_DISABLE_SIGNUP:-}
      - LAGO_DISABLE_PDF_GENERATION=\${LAGO_DISABLE_PDF_GENERATION:-false}
      - NANGO_SECRET_KEY=\${NANGO_SECRET_KEY:-}
      - PORT=8080
    ports:
      - "${port}:8080"
    networks:
      - lago_net

volumes:
  front_nm_wt_${san}:
  front_dist_wt_${san}:

networks:
  lago_net:
    external: true
    name: lago_dev_default
YAML

  echo "Starting front worktree '$name' on port ${port}..."
  docker compose -f "$compose_file" up -d

  echo ""
  echo "  ✓ Front: http://localhost:${port}  [$name]"
  if [[ -n "$api_port" ]]; then
    echo "  ✓ API:   http://localhost:${api_port}  [$name]"
  else
    echo "  ○ API:   shared (main stack :3000)"
  fi
  echo ""
}

cmd_down() {
  local name="${1:-}"
  [[ -z "$name" ]] && { echo "Usage: lago-worktree down <name>" >&2; exit 1; }

  # Stop API worktree container if present
  local api_compose="$API_WORKTREE_DIR/$name/docker-compose.api-worktree.yml"
  if [[ -f "$api_compose" ]]; then
    docker compose -f "$api_compose" down -v
    rm -f "$api_compose"
  fi

  # Stop front worktree container
  local wt_path="$WORKTREE_DIR/$name"
  local compose_file="$wt_path/docker-compose.worktree.yml"

  [[ -f "$compose_file" ]] && docker compose -f "$compose_file" down -v
  rm -f "$compose_file"
  # NOTE: Do NOT unregister here — the slot entry preserves metadata (front_base,
  # api_port, api_base) so that "lago-worktree up" can restore the same configuration.
  # Unregistration happens only in cmd_destroy.
  echo "Done."
}

cmd_destroy() {
  local name="${1:-}"
  [[ -z "$name" ]] && { echo "Usage: lago-worktree destroy <name>" >&2; exit 1; }

  local wt_path="$WORKTREE_DIR/$name"
  local api_wt_path="$API_WORKTREE_DIR/$name"
  local has_api_wt="no"
  [[ -d "$api_wt_path" ]] && has_api_wt="yes"

  echo ""
  echo "  ⚠  WARNING: This action is irreversible!"
  echo ""
  echo "     The following will be permanently deleted from your machine:"
  echo "     • Docker container(s) and volumes for '$name'"
  echo "     • Local front worktree branch '$name'"
  echo "     • All files, changes and uncommitted work in:"
  echo "       $wt_path"
  if [[ "$has_api_wt" == "yes" ]]; then
    echo "     • Local API worktree branch '$name'"
    echo "     • All files, changes and uncommitted work in:"
    echo "       $api_wt_path"
  fi
  echo ""
  echo "     This does NOT affect the remote repository."
  echo ""
  read -rp "  Are you sure? [y/N] " confirm
  [[ "$confirm" != [yY] ]] && { echo "  Aborted."; return; }
  echo ""

  # 1. Stop containers + remove volumes
  cmd_down "$name"
  unregister "$name"

  # 2. Remove front git worktree and branch
  cd "$FRONT_PATH"
  if [[ -d "$wt_path" ]]; then
    git worktree remove "$wt_path" --force 2>/dev/null || rm -rf "$wt_path"
  fi
  git worktree prune 2>/dev/null || true
  git branch -D "$name" 2>/dev/null || true

  # 3. Remove API git worktree and branch (if present)
  if [[ "$has_api_wt" == "yes" ]]; then
    cd "$API_PATH"
    git worktree remove "$api_wt_path" --force 2>/dev/null || rm -rf "$api_wt_path"
    git worktree prune 2>/dev/null || true
    git branch -D "$name" 2>/dev/null || true
  fi

  echo "Worktree '$name' destroyed."
}

cmd_ps() {
  local sf
  sf="$(slot_file)"
  echo ""
  if [[ ! -f "$sf" ]] || [[ ! -s "$sf" ]]; then
    echo "  No worktree instances."
    echo ""; return
  fi

  # Collect running containers once
  local running_containers
  running_containers="$(docker ps --format '{{.Names}}')"

  # First pass: collect rows and compute max column widths
  local rows=() wn=4 wf=5 wa=3 ws=6  # min widths = header lengths

  while IFS=: read -r n p fb ap ab; do
    [[ -z "$n" ]] && continue
    [[ -z "$p" ]] && continue
    local san st="stopped"
    san="$(sanitize "$n")"
    [[ -z "$fb" ]] && fb="main"

    echo "$running_containers" | grep -q "lago_front_wt_${san}" && st="running"

    local front_col="http://localhost:${p} [${fb}]"
    local api_col="shared"
    if [[ -n "$ap" ]]; then
      api_col="http://localhost:${ap} [${ab}]"
      if ! echo "$running_containers" | grep -q "lago_api_wt_${san}"; then
        [[ "$st" == "running" ]] && st="partial" || true
      fi
    fi

    rows+=("${n}|${front_col}|${api_col}|${st}")
    (( ${#n} > wn )) && wn=${#n}
    (( ${#front_col} > wf )) && wf=${#front_col}
    (( ${#api_col} > wa )) && wa=${#api_col}
    (( ${#st} > ws )) && ws=${#st}
  done < "$sf"

  # Second pass: print with dynamic widths
  local gap=3
  printf "  %-*s%-*s%-*s%s\n" $((wn+gap)) "NAME" $((wf+gap)) "FRONT" $((wa+gap)) "API" "STATUS"
  printf "  %-*s%-*s%-*s%s\n" $((wn+gap)) "----" $((wf+gap)) "-----" $((wa+gap)) "---" "------"

  for row in "${rows[@]}"; do
    IFS='|' read -r rn rf ra rs <<< "$row"
    printf "  %-*s%-*s%-*s%s\n" $((wn+gap)) "$rn" $((wf+gap)) "$rf" $((wa+gap)) "$ra" "$rs"
  done
  echo ""
}

# --- Main ---
cmd="${1:-help}"; shift || true
case "$cmd" in
  create)  cmd_create "$@" ;;
  up)      cmd_up "$@" ;;
  down)    cmd_down "$@" ;;
  destroy) cmd_destroy "$@" ;;
  ps)      cmd_ps ;;
  *)
    cat << 'EOF'
lago-worktree — Isolated frontend (+ optional API) per git worktree

  Main:      https://app.lago.dev       (via Traefik)
  Worktree:  http://localhost:<port>     (direct)

Commands:
  create <branch> [--from-front=<b>] [--from-api=<b>]
                                    Create worktree(s) + start
  up <name>                         Start existing worktree(s)
  down <name>                       Stop container(s)
  destroy <name>                    Stop + delete worktree(s)
  ps                                List instances

Without --from-api, the front uses the shared main API (:3000).
With --from-api=<branch>, a dedicated API container is created.

Front ports auto-assigned: 3001, 3002, ...
API ports auto-assigned:   4001, 4002, ...

Examples:
  lago-worktree create LAGO-0001
  lago-worktree create LAGO-0001 --from-front=feat/ui --from-api=feat/endpoint
  lago-worktree create LAGO-0001 --from-api=main
  lago-worktree ps
  lago-worktree down LAGO-0001
  lago-worktree destroy LAGO-0001
EOF
    ;;
esac
