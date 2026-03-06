#!/bin/bash

GREEN=$(tput setaf 2)
CYAN=$(tput setaf 6)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
NORMAL=$(tput sgr0)
BOLD=$(tput bold)

ENV_FILE=".env"
COMPOSE_FILE=""

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "${RED}❌ Error:${NORMAL} ${BOLD}$1${NORMAL} is not installed."
        return 1
    else
        echo "${GREEN}✅ $1 is installed.${NORMAL}"
        return 0
    fi
}

check_docker_compose() {
    if docker compose version &> /dev/null; then
        echo "${GREEN}✅ docker compose is installed.${NORMAL}"
        return 0
    fi

    if command -v docker-compose &> /dev/null; then
        echo "${GREEN}✅ docker-compose is installed.${NORMAL}"
        return 0
    fi

    echo "${RED}❌ Error:${NORMAL} ${BOLD}Docker Compose${NORMAL} is not installed."
    return 1
}

run_compose() {
    if docker compose version &> /dev/null; then
        docker compose -f "$COMPOSE_FILE" "$@"
    else
        docker-compose -f "$COMPOSE_FILE" "$@"
    fi
}

check_domain_dns() {
    local domain="$1"

    # Remove protocol if present
    domain=$(echo "$domain" | sed -E 's|^https?://||')

    echo "${CYAN}${BOLD}🔍 Checking DNS A record for ${domain}...${NORMAL}"

    if command -v dig &> /dev/null; then
        if dig +short A "$domain" | grep -q '^[0-9]'; then
            echo "${GREEN}✅ Valid A record found for ${BOLD}${domain}${NORMAL}"
            return 0
        else
            echo "${RED}❌ No valid A record found for ${BOLD}${domain}${NORMAL}"
            return 1
        fi
    elif command -v nslookup &> /dev/null; then
        if nslookup "$domain" | grep -q 'Address: [0-9]'; then
            echo "${GREEN}✅ Valid A record found for ${BOLD}${domain}${NORMAL}"
            return 0
        else
            echo "${RED}❌ No valid A record found for ${BOLD}${domain}${NORMAL}"
            return 1
        fi
    else
        echo "${YELLOW}⚠️ Cannot check domain DNS record - neither dig nor nslookup available${NORMAL}"
        return 2
    fi
}

ask_yes_no() {
    while true; do
        read -p "${YELLOW}👉 $1 [y/N]: ${NORMAL}" yn </dev/tty
        yn=${yn:-N}
        case $yn in
            [Yy]*) return 0;;
            [Nn]*) return 1;;
            *) echo "${RED}⚠️  Please answer yes (y) or no (n).${NORMAL}";;
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

echo "${CYAN}${BOLD}"
echo "============================="
echo "🚀 Lago Docker Deployments 🚀"
echo "=============================${NORMAL}"
echo ""

echo "${CYAN}${BOLD}🔍 Checking Dependencies...${NORMAL}"
check_command docker || MISSING_DOCKER=true
check_docker_compose || MISSING_DOCKER_COMPOSE=true

if [[ "$MISSING_DOCKER" = true || "$MISSING_DOCKER_COMPOSE" = true ]]; then
    echo "${YELLOW}⚠️ Please install missing dependencies:${NORMAL}"

    if [ "$MISSING_DOCKER" = true ]; then
        echo "👉 Docker: https://docs.docker.com/get-docker/"
    fi

    if [ "$MISSING_DOCKER_COMPOSE" = true ]; then
        echo "👉 Docker Compose: https://docs.docker.com/compose/install/"
    fi

    exit 1
fi

echo ""

check_and_stop_containers(){
    containers_to_check=("lago-quickstart")

    for container in "${containers_to_check[@]}"; do
        if [ "$(docker ps -q -f name="^/${container}$")" ]; then
            echo "${YELLOW}⚠️  Detected running container: ${BOLD}$container${NORMAL}"

            if ask_yes_no "Do you want to stop ${BOLD}${container}${NORMAL}?"; then
                echo -n "${CYAN}⏳ Stopping ${container}...${NORMAL}"

                (docker stop "$container" &>/dev/null) &
                spinner $!

                echo "${GREEN}✅ done.${NORMAL}"

                if ask_yes_no "Do you want to remove ${BOLD}${container}${NORMAL}?"; then
                    echo -n "${CYAN}⏳ Deleting ${container}...${NORMAL}"

                    (docker rm "$container" &>/dev/null) &
                    spinner $!

                    echo "${GREEN}✅ done.${NORMAL}"
                fi
            else
                echo "${RED}⚠️ Please manually stop ${container} before proceeding.${NORMAL}"
                exit 1
            fi
        fi
    done

    compose_projects=("lago-local" "lago-light" "lago-production")
    for project in "${compose_projects[@]}"; do
        if docker compose version &> /dev/null; then
            running_services=$(docker compose -p "$project" ps -q 2>/dev/null)
        else
            running_services=$(docker-compose -p "$project" ps -q 2>/dev/null)
        fi

        if [ -n "$running_services" ]; then
            echo "${YELLOW}⚠️  Detected running Docker Compose project: ${BOLD}$project${NORMAL}"

            if ask_yes_no "Do you want to stop ${BOLD}${project}${NORMAL}?"; then
                if docker compose version &> /dev/null; then
                    docker compose -p "$project" down &>/dev/null
                else
                    docker-compose -p "$project" down &>/dev/null
                fi
                echo "${GREEN}✅ ${project} stopped.${NORMAL}"

                if ask_yes_no "Do you want to clean volumes and all data from ${BOLD}${project}${NORMAL}?"; then
                    docker volume rm -f lago_rsa_data lago_postgres_data lago_redis_data lago_storage_data
                    echo "${GREEN}✅ ${project} data has been cleaned up.${NORMAL}"
                fi
            else
                echo "${RED}⚠️ Please manually stop ${project} before proceeding.${NORMAL}"
                exit 1
            fi
        fi
    done
}

# Checks existing deployments
echo "${CYAN}${BOLD}🔍 Checking for existing Lago deployments...${NORMAL}"
check_and_stop_containers
echo ""

templates=(
    "Quickstart|One-line Docker run command, ideal for testing"
    "Local|Local installation of Lago, without SSL support"
    "Light|Light Lago installation, ideal for small production usage"
    "Production|Optimized Production Setup for scalability and performances"
)

# Display Templates
echo "${BOLD}📋 Available Deployments:${NORMAL}"
i=1
for template in "${templates[@]}"; do
    IFS='|' read -r key desc <<< "$template"
    echo "${YELLOW}[$i]${NORMAL} ${BOLD}${key}${NORMAL} - ${desc}"
    ((i++))
done
echo ""

while true; do
    read -p "${CYAN}👉 Enter your choice [1-$((${#templates[@]}))]: ${NORMAL}" choice </dev/tty
    if [[ "$choice" =~ ^[1-9][0-9]*$ ]] && (( choice >= 1 && choice <= ${#templates[@]} )); then
        selected="${templates[$((choice-1))]}"
        IFS='|' read -r selected_key selected_desc <<< "$selected"
        break
    else
        echo ""
        echo "${RED}⚠️  Invalid choice, please try again.${NORMAL}"
        echo ""
    fi
done

echo ""

profile="all"

# Download docker-compose file based on choice
case "$selected_key" in
    "Local")
        echo "${CYAN}${BOLD}🚀 Downloading Local deployment files...${NORMAL}"
        COMPOSE_FILE="docker-compose.local.yml"
        curl -s -o "$COMPOSE_FILE" https://deploy.getlago.com/docker-compose.local.yml
        if [ $? -eq 0 ]; then
            echo "${GREEN}✅ Successfully downloaded Local deployment files${NORMAL}"
        else
            echo "${RED}❌ Failed to download Local deployment files${NORMAL}"
            exit 1
        fi
        ;;
    "Light")
        echo "${CYAN}${BOLD}🚀 Downloading Light deployment files...${NORMAL}"
        COMPOSE_FILE="docker-compose.light.yml"
        curl -s -o "$COMPOSE_FILE" https://deploy.getlago.com/docker-compose.light.yml
        curl -s -o .env https://deploy.getlago.com/.env.light.example
        if [ $? -eq 0 ]; then
            echo "${GREEN}✅ Successfully downloaded Light deployment files${NORMAL}"
        else
            echo "${RED}❌ Failed to download Light deployment files${NORMAL}"
            exit 1
        fi
        ;;
    "Production")
        echo "${CYAN}${BOLD}🚀 Downloading Production deployment files...${NORMAL}"
        COMPOSE_FILE="docker-compose.production.yml"
        curl -s -o "$COMPOSE_FILE" https://deploy.getlago.com/docker-compose.production.yml
        curl -s -o .env https://deploy.getlago.com/.env.production.example
        if [ $? -eq 0 ]; then
            echo "${GREEN}✅ Successfully downloaded Production deployment files${NORMAL}"
        else
            echo "${RED}❌ Failed to download Production deployment files${NORMAL}"
            exit 1
        fi
        ;;
esac

echo ""

# Check Env Vars depending on the deployment
if [[ "$selected_key" == "Light" || "$selected_key" == "Production" ]]; then
    mandatory_vars=("LAGO_DOMAIN" "LAGO_ACME_EMAIL")
    if [[ "$selected_key" == "Production" ]]; then
        mandatory_vars+=("PORTAINER_USER" "PORTAINER_PASSWORD")
    fi
    external_pg=false
    external_redis=false

    if [[ -n "$LAGO_DOMAIN" ]]; then
        check_domain_dns "$LAGO_DOMAIN"
        if [[ $? -eq 1 ]] && ! ask_yes_no "No valid DNS record found. Continue anyway?"; then
            echo "${YELLOW}⚠️ Deployment aborted.${NORMAL}"
            exit 1
        fi
    fi

    if ask_yes_no "Do you want to use an external PostgreSQL instance?"; then
        mandatory_vars+=("POSTGRES_HOST" "POSTGRES_USER" "POSTGRES_PASSWORD" "POSTGRES_PORT" "POSTGRES_DB")
        external_pg=true

        if ask_yes_no "Does your PG Database use an other schema than public?"; then
            mandatory_vars+=("POSTGRES_SCHEMA")
        fi
    fi

    if ask_yes_no "Do you want to use an external Redis instance?"; then
        mandatory_vars+=("REDIS_HOST" "REDIS_PORT")
        external_redis=true

        if ask_yes_no "Does you Redis instance need a password?"; then
            mandatory_vars+=("REDIS_PASSWORD")
        fi
    fi
    
    if $external_pg && $external_redis; then
        profile="all-no-db"
    elif $external_pg; then
        profile="all-no-pg"
    elif $external_redis; then
        profile="all-no-redis"
    fi

    echo ""

    echo "${CYAN}${BOLD}🔧 Checking mandatory environment variables...${NORMAL}"

    # Load Existing .env values
    if [ -f "$ENV_FILE" ]; then
        # shellcheck disable=SC2046
        export $(grep -v '^#' "$ENV_FILE" | xargs)
        echo "${GREEN}✅ Loaded existing .env file.${NORMAL}"
    else
        touch "$ENV_FILE"
        echo "${YELLOW}⚠️  No .env file found. Created a new one.${NORMAL}"
    fi

    {
        echo "# Updated by Lago Deploy"
        for var in "${mandatory_vars[@]}"; do
            if [ -z "${!var}" ]; then
                read -p "${YELLOW}⚠️  $var is missing. Enter value: ${NORMAL}" user_input </dev/tty
                echo "${var}=${user_input}"
            else
                echo "${GREEN}✅ $var is already set.${NORMAL}"
                echo "${var}=${!var}"
            fi
        done
    } > "$ENV_FILE"

    echo "${GREEN}${BOLD}✅ .env file updated successfully.${NORMAL}"
    echo ""
fi

# Execute selected deployment
case "$selected_key" in
    Quickstart)
        echo "${CYAN}🚧 Running quickstart Docker container...${NORMAL}"
        docker run -d --name lago-quickstart -p 3000:3000 -p 80:80 getlago/lago:latest &>/dev/null
        ;;
    Local)
        echo "${CYAN}🚧 Running Local Docker Compose deployment...${NORMAL}"
        run_compose up -d
        ;;
    Light)
        echo "${CYAN}🚧 Running Light Docker Compose deployment...${NORMAL}"
        run_compose up -d --profile "$profile"
        ;;
    Production)
        echo "${CYAN}🚧 Running Production Docker Compose deployment...${NORMAL}"
        run_compose up -d --profile "$profile"
        ;;
esac

echo ""
echo "${GREEN}${BOLD}🎉 Lago deployment started successfully!${NORMAL}"
