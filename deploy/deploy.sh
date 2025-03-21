#!/bin/bash

GREEN=$(tput setaf 2)
CYAN=$(tput setaf 6)
YELLOW=$(tput setaf 3)
RED=$(tput setaf 1)
NORMAL=$(tput sgr0)
BOLD=$(tput bold)

ENV_FILE=".env"

check_command() {
    if ! command -v "$1" &> /dev/null; then
        echo "${RED}❌ Error:${NORMAL} ${BOLD}$1${NORMAL} is not installed."
        return 1
    else
        echo "${GREEN}✅ $1 is installed.${NORMAL}"
        return 0
    fi
}

echo "${CYAN}${BOLD}"
echo "======================="
echo "🚀 Lago Deployment 🚀"
echo "=======================${NORMAL}"
echo ""

echo "${CYAN}${BOLD}🔍 Checking Dependencies...${NORMAL}"
check_command docker || MISSING_DOCKER=true
check_command docker-compose || check_command "docker compose" || MISSING_DOCKER_COMPOSE=true

if [ "$MISSING_DOCKER" = true ] || [ "$MISSING_DOCKER_COMPOSE" = true ]; then
    echo "${YELLOW}⚠️ Please install missing dependencies:${NORMAL}"

    if [ "$MISSING_DOCKER" = true ]; then
        echo "👉 Docker: https://docs.docker.com/get-docker/"
    fi

    if [ "$MISSING_DOCKER_COMPOSE" = true ]; then
        👉 Docker Compose: https://docs.docker.com/compose/install/
    fi
fi

echo ""

templates=(
    "Quickstart|One-line Docker run command, ideal for testing"
    "Local|Local installation of Lago, without SSL support"
    "Light|Light Lago installation, ideal for small production usage"
    "Production|Coming soon... Optimized Production Setup for scalability and performances"
)

# Display Templates
echo "${BOLD}📋 Available Templates:${NORMAL}"
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

# Execute selected deployment
case "$selected_key" in
    Quickstart)
        echo "${CYAN}🚧 Running quickstart Docker container...${NORMAL}"
        docker run -d --name lago-quickstart -p 3000:3000 -p 80:80 getlago/lago:latest
        ;;
    Production)
        echo "${RED}⚠️  Production deployment is not available yet."
        ;;
esac