#!/bin/bash
#
# Lago Deploy Test Runner
# Run the same tests locally that CI runs
#
# Usage:
#   ./test/run-tests.sh [test_name]
#
# Tests:
#   validate    - Validate docker-compose config for all profiles
#   local       - Test local profile (no SSL)
#   light       - Test light profile with Pebble SSL
#   production  - Test production profile with Pebble SSL
#   all         - Run all tests (default)
#
# Examples:
#   ./test/run-tests.sh              # Run all tests
#   ./test/run-tests.sh local        # Run only local profile test
#   ./test/run-tests.sh light        # Run only light profile SSL test
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEPLOY_DIR="$(dirname "$SCRIPT_DIR")"

# Test configuration
TEST_DOMAIN="lago.test"
PEBBLE_CERT_URL="https://localhost:15000/roots/0"
MAX_WAIT_SECONDS=120
HEALTH_CHECK_INTERVAL=5

# Counters
TESTS_PASSED=0
TESTS_FAILED=0

# ===========================================================================
# Helper Functions
# ===========================================================================

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

cleanup() {
    log_info "Cleaning up containers and volumes..."
    cd "$DEPLOY_DIR"

    # Set LAGO_DOMAIN to suppress warnings during cleanup
    export LAGO_DOMAIN="${LAGO_DOMAIN:-localhost}"

    # Stop all possible profile combinations
    docker compose --profile local --profile db --profile redis down -v 2>/dev/null || true
    docker compose -f docker-compose.yml -f docker-compose.test.yml --profile light --profile db --profile redis down -v 2>/dev/null || true
    docker compose -f docker-compose.yml -f docker-compose.test.yml --profile production --profile db --profile redis down -v 2>/dev/null || true

    # Remove test network if exists
    docker network rm lago-test-network 2>/dev/null || true

    # Clean up letsencrypt directory
    rm -rf "$DEPLOY_DIR/letsencrypt" 2>/dev/null || true
}

wait_for_healthy() {
    local service=$1
    local max_wait=${2:-$MAX_WAIT_SECONDS}
    local waited=0

    log_info "Waiting for $service to be healthy..."

    while [ $waited -lt $max_wait ]; do
        if docker compose ps "$service" 2>/dev/null | grep -q "healthy"; then
            log_info "$service is healthy"
            return 0
        fi
        sleep $HEALTH_CHECK_INTERVAL
        waited=$((waited + HEALTH_CHECK_INTERVAL))
        echo -n "."
    done

    echo ""
    log_error "$service did not become healthy within ${max_wait}s"
    docker compose logs "$service" 2>/dev/null | tail -50
    return 1
}

wait_for_url() {
    local url=$1
    local max_wait=${2:-$MAX_WAIT_SECONDS}
    local insecure=${3:-false}
    local waited=0

    local curl_opts="-sf"
    if [ "$insecure" = "true" ]; then
        curl_opts="-sfk"
    fi

    log_info "Waiting for $url to respond..."

    while [ $waited -lt $max_wait ]; do
        if curl $curl_opts "$url" > /dev/null 2>&1; then
            log_info "$url is responding"
            return 0
        fi
        sleep $HEALTH_CHECK_INTERVAL
        waited=$((waited + HEALTH_CHECK_INTERVAL))
        echo -n "."
    done

    echo ""
    log_error "$url did not respond within ${max_wait}s"
    return 1
}

# ===========================================================================
# Test Functions
# ===========================================================================

test_validate() {
    log_info "=========================================="
    log_info "Testing: Config Validation"
    log_info "=========================================="

    cd "$DEPLOY_DIR"

    local profiles=(
        "local db redis"
        "light db redis"
        "production db redis"
        "light redis"
        "light db"
        "production redis"
    )

    for profile_combo in "${profiles[@]}"; do
        local profile_flags=""
        for p in $profile_combo; do
            profile_flags+=" --profile $p"
        done

        log_info "Validating: $profile_combo"
        if LAGO_DOMAIN="$TEST_DOMAIN" docker compose $profile_flags config > /dev/null 2>&1; then
            log_success "Config valid: $profile_combo"
        else
            log_error "Config invalid: $profile_combo"
            return 1
        fi
    done
}

test_local() {
    log_info "=========================================="
    log_info "Testing: Local Profile (no SSL)"
    log_info "=========================================="

    cd "$DEPLOY_DIR"
    cleanup

    # Generate RSA key
    export LAGO_RSA_PRIVATE_KEY="$(openssl genrsa 2048 2>/dev/null | openssl base64 -A)"
    # Set dummy LAGO_DOMAIN to suppress warnings (not used by local profile)
    export LAGO_DOMAIN="localhost"

    log_info "Starting local profile..."
    docker compose --profile local --profile db --profile redis up -d

    # Wait for services
    sleep 10

    # Check API health
    if wait_for_url "http://localhost:3000/health" 120; then
        log_success "API health check passed"
    else
        log_error "API health check failed"
        docker compose --profile local --profile db --profile redis logs api-local
        return 1
    fi

    # Check frontend
    if curl -sf "http://localhost:80" > /dev/null 2>&1; then
        log_success "Frontend is accessible"
    else
        log_error "Frontend is not accessible"
        return 1
    fi

    # Check worker is running
    if docker compose --profile local --profile db --profile redis ps worker 2>/dev/null | grep -q "Up\|running"; then
        log_success "Worker is running"
    else
        log_warning "Worker status unclear"
    fi

    cleanup
    log_success "Local profile test completed"
}

test_light() {
    log_info "=========================================="
    log_info "Testing: Light Profile (with Pebble SSL)"
    log_info "=========================================="

    cd "$DEPLOY_DIR"
    cleanup

    # Generate RSA key
    export LAGO_RSA_PRIVATE_KEY="$(openssl genrsa 2048 2>/dev/null | openssl base64 -A)"
    export LAGO_DOMAIN="$TEST_DOMAIN"
    export LAGO_ACME_EMAIL="test@$TEST_DOMAIN"

    # Add lago.test to /etc/hosts if not present (requires sudo)
    if ! grep -q "$TEST_DOMAIN" /etc/hosts 2>/dev/null; then
        log_warning "Adding $TEST_DOMAIN to /etc/hosts (may require sudo)"
        echo "127.0.0.1 $TEST_DOMAIN" | sudo tee -a /etc/hosts > /dev/null || true
    fi

    log_info "Starting light profile with Pebble..."
    docker compose -f docker-compose.yml -f docker-compose.test.yml \
        --profile light --profile db --profile redis up -d

    # Wait for Pebble and challtestsrv
    log_info "Waiting for Pebble ACME server..."
    sleep 10
    for i in {1..30}; do
        if curl -sfk "https://localhost:14000/dir" > /dev/null 2>&1; then
            log_success "Pebble ACME server is ready"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Pebble ACME server failed to start"
            docker compose -f docker-compose.yml -f docker-compose.test.yml \
                --profile light --profile db --profile redis logs pebble challtestsrv
            return 1
        fi
        sleep 2
    done

    # Wait for API (via Traefik)
    sleep 15
    if wait_for_url "https://$TEST_DOMAIN/api/health" 120 true; then
        log_success "API accessible via HTTPS"
    else
        log_error "API not accessible via HTTPS"
        docker compose -f docker-compose.yml -f docker-compose.test.yml \
            --profile light --profile db --profile redis logs traefik api
        return 1
    fi

    # Check frontend via HTTPS
    if curl -sfk "https://$TEST_DOMAIN" > /dev/null 2>&1; then
        log_success "Frontend accessible via HTTPS"
    else
        log_error "Frontend not accessible via HTTPS"
        return 1
    fi

    # Verify SSL certificate was issued
    log_info "Verifying SSL certificate..."
    local cert_info
    cert_info=$(echo | openssl s_client -connect "$TEST_DOMAIN:443" -servername "$TEST_DOMAIN" 2>/dev/null | openssl x509 -noout -issuer 2>/dev/null || true)
    if echo "$cert_info" | grep -qi "pebble"; then
        log_success "SSL certificate issued by Pebble"
    else
        log_warning "Could not verify Pebble certificate issuer"
    fi

    cleanup
    log_success "Light profile SSL test completed"
}

test_production() {
    log_info "=========================================="
    log_info "Testing: Production Profile (with Pebble SSL)"
    log_info "=========================================="

    cd "$DEPLOY_DIR"
    cleanup

    # Generate RSA key
    export LAGO_RSA_PRIVATE_KEY="$(openssl genrsa 2048 2>/dev/null | openssl base64 -A)"
    export LAGO_DOMAIN="$TEST_DOMAIN"
    export LAGO_ACME_EMAIL="test@$TEST_DOMAIN"

    # Add lago.test to /etc/hosts if not present
    if ! grep -q "$TEST_DOMAIN" /etc/hosts 2>/dev/null; then
        log_warning "Adding $TEST_DOMAIN to /etc/hosts (may require sudo)"
        echo "127.0.0.1 $TEST_DOMAIN" | sudo tee -a /etc/hosts > /dev/null || true
    fi

    log_info "Starting production profile with Pebble..."
    docker compose -f docker-compose.yml -f docker-compose.test.yml \
        --profile production --profile db --profile redis up -d

    # Wait for Pebble and challtestsrv
    log_info "Waiting for Pebble ACME server..."
    sleep 10
    for i in {1..30}; do
        if curl -sfk "https://localhost:14000/dir" > /dev/null 2>&1; then
            log_success "Pebble ACME server is ready"
            break
        fi
        if [ $i -eq 30 ]; then
            log_error "Pebble ACME server failed to start"
            docker compose -f docker-compose.yml -f docker-compose.test.yml \
                --profile production --profile db --profile redis logs pebble challtestsrv
            return 1
        fi
        sleep 2
    done

    # Wait for API (via Traefik)
    sleep 20
    if wait_for_url "https://$TEST_DOMAIN/api/health" 180 true; then
        log_success "API accessible via HTTPS"
    else
        log_error "API not accessible via HTTPS"
        docker compose -f docker-compose.yml -f docker-compose.test.yml \
            --profile production --profile db --profile redis logs traefik api
        return 1
    fi

    # Check all workers are running
    log_info "Checking worker services..."
    local workers=("worker" "billing-worker" "pdf-worker" "webhook-worker" "clock-worker" "events-worker")
    for w in "${workers[@]}"; do
        if docker compose -f docker-compose.yml -f docker-compose.test.yml \
            --profile production --profile db --profile redis ps "$w" 2>/dev/null | grep -q "Up\|running"; then
            log_success "Worker $w is running"
        else
            log_warning "Worker $w status unclear"
        fi
    done

    cleanup
    log_success "Production profile SSL test completed"
}

# ===========================================================================
# Main
# ===========================================================================

main() {
    local test_name="${1:-all}"

    echo ""
    echo "=========================================="
    echo "  Lago Deploy Test Runner"
    echo "=========================================="
    echo ""

    # Ensure we're in the deploy directory
    cd "$DEPLOY_DIR"

    # Set up trap for cleanup on exit
    trap cleanup EXIT

    case "$test_name" in
        validate)
            test_validate
            ;;
        local)
            test_local
            ;;
        light)
            test_light
            ;;
        production)
            test_production
            ;;
        all)
            test_validate
            test_local
            test_light
            test_production
            ;;
        *)
            echo "Unknown test: $test_name"
            echo "Available tests: validate, local, light, production, all"
            exit 1
            ;;
    esac

    echo ""
    echo "=========================================="
    echo "  Test Summary"
    echo "=========================================="
    echo -e "  ${GREEN}Passed:${NC} $TESTS_PASSED"
    echo -e "  ${RED}Failed:${NC} $TESTS_FAILED"
    echo "=========================================="

    if [ $TESTS_FAILED -gt 0 ]; then
        exit 1
    fi
}

main "$@"
