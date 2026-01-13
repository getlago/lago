#!/bin/bash

GREEN=$(tput setaf 2)
CYAN=$(tput setaf 6)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
NORMAL=$(tput sgr0)
BOLD=$(tput bold)

ENV_FILE=".env"

# Flags
DRY_RUN=false
NON_INTERACTIVE=false
SKIP_DOWNLOAD=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --non-interactive|-y)
            NON_INTERACTIVE=true
            shift
            ;;
        --skip-download)
            SKIP_DOWNLOAD=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --dry-run          Show what would be executed without running"
            echo "  --non-interactive  Use environment variables, no prompts (or -y)"
            echo "  --skip-download    Use local docker-compose.yml instead of downloading"
            echo "  --help             Show this help message"
            echo ""
            echo "Environment variables for non-interactive mode:"
            echo "  LAGO_DEPLOY_CHOICE     Deployment choice: 1=Quickstart, 2=Local, 3=Light, 4=Production"
            echo "  LAGO_EXTERNAL_PG       Use external PostgreSQL: true/false (default: false)"
            echo "  LAGO_EXTERNAL_REDIS    Use external Redis: true/false (default: false)"
            echo "  LAGO_DOMAIN            Domain for Light/Production deployments"
            echo "  LAGO_ACME_EMAIL        Email for SSL certificates"
            echo "  POSTGRES_HOST          External PostgreSQL host"
            echo "  POSTGRES_USER          External PostgreSQL user"
            echo "  POSTGRES_PASSWORD      External PostgreSQL password"
            echo "  POSTGRES_PORT          External PostgreSQL port"
            echo "  POSTGRES_DB            External PostgreSQL database"
            echo "  POSTGRES_SCHEMA        External PostgreSQL schema (optional)"
            echo "  REDIS_HOST             External Redis host"
            echo "  REDIS_PORT             External Redis port"
            echo "  REDIS_PASSWORD         External Redis password (optional)"
            echo ""
            echo "Examples:"
            echo "  # Interactive local deployment"
            echo "  $0"
            echo ""
            echo "  # Non-interactive local deployment with local DB/Redis"
            echo "  LAGO_DEPLOY_CHOICE=2 $0 --non-interactive --skip-download"
            echo ""
            echo "  # Dry-run light deployment"
            echo "  LAGO_DEPLOY_CHOICE=3 LAGO_DOMAIN=lago.example.com LAGO_ACME_EMAIL=admin@example.com \\"
            echo "    $0 --non-interactive --dry-run"
            exit 0
            ;;
        *)
            echo "${RED}Unknown option: $1${NORMAL}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "${RED}Error:${NORMAL} ${BOLD}$1${NORMAL} is not installed."
        return 1
    else
        echo "${GREEN}$1 is installed.${NORMAL}"
        return 0
    fi
}

ask_yes_no() {
    local default="${2:-N}"

    if [[ "$NON_INTERACTIVE" == true ]]; then
        if [[ "$default" =~ ^[Yy] ]]; then
            echo "${YELLOW}$1 [y/N]: ${NORMAL}y (auto)"
            return 0
        else
            echo "${YELLOW}$1 [y/N]: ${NORMAL}n (auto)"
            return 1
        fi
    fi

    while true; do
        read -p "${YELLOW}$1 [y/N]: ${NORMAL}" yn </dev/tty
        yn=${yn:-N}
        case $yn in
            [Yy]*) return 0;;
            [Nn]*) return 1;;
            *) echo "${RED}Please answer yes (y) or no (n).${NORMAL}";;
        esac
    done
}

spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  echo -n " "

  while ps -p $pid &>/dev/null; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# Check if domain has A record
check_domain_dns() {
    local domain="$1"

    # Remove protocol if present
    domain=$(echo "$domain" | sed -E 's|^https?://||')

    echo "${CYAN}${BOLD}Checking DNS A record for ${domain}...${NORMAL}"

    if command -v dig &> /dev/null; then
        if dig +short A "$domain" | grep -q '^[0-9]'; then
            echo "${GREEN}Valid A record found for ${BOLD}${domain}${NORMAL}"
            return 0
        else
            echo "${RED}No valid A record found for ${BOLD}${domain}${NORMAL}"
            return 1
        fi
    elif command -v nslookup &> /dev/null; then
        if nslookup "$domain" | grep -q 'Address: [0-9]'; then
            echo "${GREEN}Valid A record found for ${BOLD}${domain}${NORMAL}"
            return 0
        else
            echo "${RED}No valid A record found for ${BOLD}${domain}${NORMAL}"
            return 1
        fi
    else
        echo "${YELLOW}Cannot check domain DNS record - neither dig nor nslookup available${NORMAL}"
        return 2
    fi
}

check_and_stop_containers(){
    containers_to_check=("lago-quickstart")

    for container in "${containers_to_check[@]}"; do
        if [ "$(docker ps -q -f name="^/${container}$")" ]; then
            echo "${YELLOW}Detected running container: ${BOLD}$container${NORMAL}"

            if ask_yes_no "Do you want to stop ${BOLD}${container}${NORMAL}?"; then
                echo -n "${CYAN}Stopping ${container}...${NORMAL}"

                (docker stop "$container" &>/dev/null) &
                spinner $!

                echo "${GREEN}done.${NORMAL}"

                if ask_yes_no "Do you want to remove ${BOLD}${container}${NORMAL}?"; then
                    echo -n "${CYAN}Deleting ${container}...${NORMAL}"

                    (docker rm "$container" &>/dev/null) &
                    spinner $!

                    echo "${GREEN}done.${NORMAL}"
                fi
            else
                echo "${RED}Please manually stop ${container} before proceeding.${NORMAL}"
                exit 1
            fi
        fi
    done

    # Check for existing lago compose project
    if docker compose -p "lago" ps -q &>/dev/null || docker-compose -p "lago" ps -q &>/dev/null; then
        running_services=$(docker compose -p "lago" ps -q 2>/dev/null || docker-compose -p "lago" ps -q 2>/dev/null)
        if [ -n "$running_services" ]; then
            echo "${YELLOW}Detected running Docker Compose project: ${BOLD}lago${NORMAL}"

            if ask_yes_no "Do you want to stop ${BOLD}lago${NORMAL}?"; then
                docker compose -p "lago" down &>/dev/null || docker-compose -p "lago" down &>/dev/null
                echo "${GREEN}lago stopped.${NORMAL}"

                if ask_yes_no "Do you want to clean volumes and all data from ${BOLD}lago${NORMAL}?"; then
                    docker volume rm -f lago_rsa_data lago_postgres_data lago_redis_data lago_storage_data 2>/dev/null
                    echo "${GREEN}lago data has been cleaned up.${NORMAL}"
                fi
            else
                echo "${RED}Please manually stop lago before proceeding.${NORMAL}"
                exit 1
            fi
        fi
    fi
}

echo "${CYAN}${BOLD}"
echo "============================="
echo "Lago Docker Deployments"
echo "=============================${NORMAL}"
echo ""

echo "${CYAN}${BOLD}Checking Dependencies...${NORMAL}"
check_command docker || MISSING_DOCKER=true
check_command docker-compose || check_command "docker compose" || MISSING_DOCKER_COMPOSE=true

if [[ "$MISSING_DOCKER" = true || "$MISSING_DOCKER_COMPOSE" = true ]]; then
    echo "${YELLOW}Please install missing dependencies:${NORMAL}"

    if [ "$MISSING_DOCKER" = true ]; then
        echo "Docker: https://docs.docker.com/get-docker/"
    fi

    if [ "$MISSING_DOCKER_COMPOSE" = true ]; then
        echo "Docker Compose: https://docs.docker.com/compose/install/"
    fi
    exit 1
fi

echo ""

# Checks existing deployments
echo "${CYAN}${BOLD}Checking for existing Lago deployments...${NORMAL}"
check_and_stop_containers
echo ""

templates=(
    "Quickstart|One-line Docker run command, ideal for testing"
    "Local|Local installation of Lago, without SSL support"
    "Light|Light Lago installation, ideal for small production usage"
    "Production|Optimized Production Setup for scalability and performances"
)

# Display Templates
echo "${BOLD}Available Deployments:${NORMAL}"
i=1
for template in "${templates[@]}"; do
    IFS='|' read -r key desc <<< "$template"
    echo "${YELLOW}[$i]${NORMAL} ${BOLD}${key}${NORMAL} - ${desc}"
    ((i++))
done
echo ""

if [[ "$NON_INTERACTIVE" == true && -n "$LAGO_DEPLOY_CHOICE" ]]; then
    choice="$LAGO_DEPLOY_CHOICE"
    if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && (( choice >= 1 && choice <= ${#templates[@]} )); then
        selected="${templates[$((choice-1))]}"
        IFS='|' read -r selected_key selected_desc <<< "$selected"
        echo "${CYAN}Enter your choice [1-$((${#templates[@]}))]: ${NORMAL}${choice} (auto)"
    else
        echo "${RED}Invalid LAGO_DEPLOY_CHOICE: $choice${NORMAL}"
        exit 1
    fi
else
    while true; do
        read -p "${CYAN}Enter your choice [1-$((${#templates[@]}))]: ${NORMAL}" choice </dev/tty
        if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && (( choice >= 1 && choice <= ${#templates[@]} )); then
            selected="${templates[$((choice-1))]}"
            IFS='|' read -r selected_key selected_desc <<< "$selected"
            break
        else
            echo ""
            echo "${RED}Invalid choice, please try again.${NORMAL}"
            echo ""
        fi
    done
fi

echo ""

# Initialize profile arrays
profiles=()
external_pg=false
external_redis=false

# Set deployment profile based on choice
case "$selected_key" in
    "Local")
        profiles+=("local")
        ;;
    "Light")
        profiles+=("light")
        ;;
    "Production")
        profiles+=("production")
        ;;
esac

# Handle Quickstart separately (doesn't use compose)
if [[ "$selected_key" == "Quickstart" ]]; then
    if [[ "$DRY_RUN" == true ]]; then
        echo "${YELLOW}${BOLD}[DRY-RUN] Would execute:${NORMAL}"
        echo "${YELLOW}  docker run -d --name lago-quickstart -p 3000:3000 -p 80:80 getlago/lago:latest${NORMAL}"
        echo ""
        echo "${GREEN}${BOLD}Dry-run completed successfully!${NORMAL}"
    else
        echo "${CYAN}Running quickstart Docker container...${NORMAL}"
        docker run -d --name lago-quickstart -p 3000:3000 -p 80:80 getlago/lago:latest &>/dev/null
        echo ""
        echo "${GREEN}${BOLD}Lago deployment started successfully!${NORMAL}"
    fi
    exit 0
fi

# Download docker-compose file
if [[ "$SKIP_DOWNLOAD" == true ]]; then
    echo "${CYAN}${BOLD}Skipping download (using local docker-compose.yml)...${NORMAL}"
    if [[ ! -f "docker-compose.yml" ]]; then
        echo "${RED}Error: docker-compose.yml not found in current directory${NORMAL}"
        exit 1
    fi
    echo "${GREEN}Using local docker-compose.yml${NORMAL}"
elif [[ "$DRY_RUN" == true ]]; then
    echo "${CYAN}${BOLD}[DRY-RUN] Would download deployment files...${NORMAL}"
    echo "${YELLOW}curl -s -o docker-compose.yml https://deploy.getlago.com/docker-compose.yml${NORMAL}"
else
    echo "${CYAN}${BOLD}Downloading deployment files...${NORMAL}"
    curl -s -o docker-compose.yml https://deploy.getlago.com/docker-compose.yml
    if [ $? -eq 0 ]; then
        echo "${GREEN}Successfully downloaded deployment files${NORMAL}"
    else
        echo "${RED}Failed to download deployment files${NORMAL}"
        exit 1
    fi
fi

echo ""

# Check for external services (not applicable for Local)
if [[ "$selected_key" == "Light" || "$selected_key" == "Production" ]]; then
    mandatory_vars=("LAGO_DOMAIN" "LAGO_ACME_EMAIL")

    if [[ -n "$LAGO_DOMAIN" ]]; then
        check_domain_dns "$LAGO_DOMAIN"
        if [[ $? -eq 1 ]] && ! ask_yes_no "No valid DNS record found. Continue anyway?"; then
            echo "${YELLOW}Deployment aborted.${NORMAL}"
            exit 1
        fi
    fi
fi

# Ask about external PostgreSQL
use_external_pg=false
if [[ "$NON_INTERACTIVE" == true ]]; then
    if [[ "$LAGO_EXTERNAL_PG" == "true" ]]; then
        use_external_pg=true
        echo "${YELLOW}Do you want to use an external PostgreSQL instance? [y/N]: ${NORMAL}y (auto)"
    else
        echo "${YELLOW}Do you want to use an external PostgreSQL instance? [y/N]: ${NORMAL}n (auto)"
    fi
else
    if ask_yes_no "Do you want to use an external PostgreSQL instance?"; then
        use_external_pg=true
    fi
fi

if [[ "$use_external_pg" == true ]]; then
    mandatory_vars+=("POSTGRES_HOST" "POSTGRES_USER" "POSTGRES_PASSWORD" "POSTGRES_PORT" "POSTGRES_DB")
    external_pg=true

    if [[ "$NON_INTERACTIVE" == true ]]; then
        if [[ -n "$POSTGRES_SCHEMA" ]]; then
            mandatory_vars+=("POSTGRES_SCHEMA")
            echo "${YELLOW}Does your PG Database use a schema other than public? [y/N]: ${NORMAL}y (auto)"
        else
            echo "${YELLOW}Does your PG Database use a schema other than public? [y/N]: ${NORMAL}n (auto)"
        fi
    elif ask_yes_no "Does your PG Database use a schema other than public?"; then
        mandatory_vars+=("POSTGRES_SCHEMA")
    fi
else
    profiles+=("db")
fi

# Ask about external Redis
use_external_redis=false
if [[ "$NON_INTERACTIVE" == true ]]; then
    if [[ "$LAGO_EXTERNAL_REDIS" == "true" ]]; then
        use_external_redis=true
        echo "${YELLOW}Do you want to use an external Redis instance? [y/N]: ${NORMAL}y (auto)"
    else
        echo "${YELLOW}Do you want to use an external Redis instance? [y/N]: ${NORMAL}n (auto)"
    fi
else
    if ask_yes_no "Do you want to use an external Redis instance?"; then
        use_external_redis=true
    fi
fi

if [[ "$use_external_redis" == true ]]; then
    mandatory_vars+=("REDIS_HOST" "REDIS_PORT")
    external_redis=true

    if [[ "$NON_INTERACTIVE" == true ]]; then
        if [[ -n "$REDIS_PASSWORD" ]]; then
            mandatory_vars+=("REDIS_PASSWORD")
            echo "${YELLOW}Does your Redis instance need a password? [y/N]: ${NORMAL}y (auto)"
        else
            echo "${YELLOW}Does your Redis instance need a password? [y/N]: ${NORMAL}n (auto)"
        fi
    elif ask_yes_no "Does your Redis instance need a password?"; then
        mandatory_vars+=("REDIS_PASSWORD")
    fi
else
    profiles+=("redis")
fi

echo ""

# Handle environment variables for Light/Production
if [[ "$selected_key" == "Light" || "$selected_key" == "Production" ]]; then
    echo "${CYAN}${BOLD}Checking mandatory environment variables...${NORMAL}"

    # Load Existing .env values (skip file operations in dry-run)
    if [[ "$DRY_RUN" != true ]]; then
        if [ -f "$ENV_FILE" ]; then
            # shellcheck disable=SC2046
            export $(grep -v '^#' "$ENV_FILE" | xargs)
            echo "${GREEN}Loaded existing .env file.${NORMAL}"
        else
            touch "$ENV_FILE"
            echo "${YELLOW}No .env file found. Created a new one.${NORMAL}"
        fi
    fi

    # Check/collect mandatory variables
    env_content="# Updated by Lago Deploy"
    missing_vars=()

    for var in "${mandatory_vars[@]}"; do
        if [ -z "${!var}" ]; then
            if [[ "$NON_INTERACTIVE" == true ]]; then
                missing_vars+=("$var")
            else
                read -p "${YELLOW}$var is missing. Enter value: ${NORMAL}" user_input </dev/tty
                export "${var}=${user_input}"
            fi
        else
            echo "${GREEN}$var is already set.${NORMAL}"
        fi
        env_content+=$'\n'"${var}=${!var}"
    done

    # Check for missing vars in non-interactive mode
    if [[ ${#missing_vars[@]} -gt 0 ]]; then
        echo "${RED}Error: Missing required environment variables in non-interactive mode:${NORMAL}"
        for var in "${missing_vars[@]}"; do
            echo "  - $var"
        done
        exit 1
    fi

    # Write .env file (or show what would be written in dry-run)
    if [[ "$DRY_RUN" == true ]]; then
        echo ""
        echo "${YELLOW}${BOLD}[DRY-RUN] Would write to .env:${NORMAL}"
        echo "$env_content" | sed 's/^/  /'
    else
        echo "$env_content" > "$ENV_FILE"
        echo "${GREEN}${BOLD}.env file updated successfully.${NORMAL}"
    fi
    echo ""
fi

# Build the profile flags
profile_flags=""
for profile in "${profiles[@]}"; do
    profile_flags+=" --profile ${profile}"
done

# Execute deployment
echo "${CYAN}Running ${selected_key} Docker Compose deployment...${NORMAL}"
echo "${CYAN}Profiles: ${profiles[*]}${NORMAL}"

if [[ "$DRY_RUN" == true ]]; then
    echo ""
    echo "${YELLOW}${BOLD}[DRY-RUN] Would execute:${NORMAL}"
    echo "${YELLOW}  docker compose${profile_flags} up -d${NORMAL}"
    echo ""
    echo "${GREEN}${BOLD}Dry-run completed successfully!${NORMAL}"
    echo ""
    echo "To actually deploy, run without --dry-run flag"
else
    docker compose${profile_flags} up -d &>/dev/null || \
    docker-compose${profile_flags} up -d &>/dev/null

    echo ""
    echo "${GREEN}${BOLD}Lago deployment started successfully!${NORMAL}"
fi

echo ""
echo "Usage:"
echo "  View logs:    docker compose${profile_flags} logs -f"
echo "  Stop:         docker compose${profile_flags} down"
echo "  Restart:      docker compose${profile_flags} restart"
