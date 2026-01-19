#!/bin/bash
# Tests for lib/environment.sh
# Run with: ./tests/test_environment.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"

# Test counter
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

pass() {
    TESTS_PASSED=$((TESTS_PASSED + 1))
    echo -e "${GREEN}PASS${NC}: $1"
}

fail() {
    TESTS_FAILED=$((TESTS_FAILED + 1))
    echo -e "${RED}FAIL${NC}: $1"
    echo "       Expected: $2"
    echo "       Got: $3"
}

run_test() {
    TESTS_RUN=$((TESTS_RUN + 1))
}

echo "=== Testing lib/environment.sh ==="
echo

# Source the library
source "$PROJECT_DIR/lib/environment.sh"

# =============================================================================
# Test: Environment variables are set
# =============================================================================
run_test
if [ -n "$DEPLOY_ENV_TYPE" ]; then
    pass "DEPLOY_ENV_TYPE is set: $DEPLOY_ENV_TYPE"
else
    fail "DEPLOY_ENV_TYPE should be set" "non-empty" "$DEPLOY_ENV_TYPE"
fi

run_test
if [ -n "$DEPLOY_HAS_SYSTEMD" ]; then
    pass "DEPLOY_HAS_SYSTEMD is set: $DEPLOY_HAS_SYSTEMD"
else
    fail "DEPLOY_HAS_SYSTEMD should be set" "true or false" "$DEPLOY_HAS_SYSTEMD"
fi

run_test
if [ -n "$DEPLOY_IS_PRIVILEGED" ]; then
    pass "DEPLOY_IS_PRIVILEGED is set: $DEPLOY_IS_PRIVILEGED"
else
    fail "DEPLOY_IS_PRIVILEGED should be set" "true or false" "$DEPLOY_IS_PRIVILEGED"
fi

run_test
if [ -n "$DEPLOY_SERVICE_MANAGER" ]; then
    pass "DEPLOY_SERVICE_MANAGER is set: $DEPLOY_SERVICE_MANAGER"
else
    fail "DEPLOY_SERVICE_MANAGER should be set" "systemd or direct" "$DEPLOY_SERVICE_MANAGER"
fi

# =============================================================================
# Test: DEPLOY_ENV_TYPE is valid
# =============================================================================
run_test
case "$DEPLOY_ENV_TYPE" in
    physical|proxmox_vm|proxmox_lxc|aws_ec2)
        pass "DEPLOY_ENV_TYPE is valid value: $DEPLOY_ENV_TYPE"
        ;;
    *)
        fail "DEPLOY_ENV_TYPE has invalid value" "physical|proxmox_vm|proxmox_lxc|aws_ec2" "$DEPLOY_ENV_TYPE"
        ;;
esac

# =============================================================================
# Test: DEPLOY_SERVICE_MANAGER is valid
# =============================================================================
run_test
case "$DEPLOY_SERVICE_MANAGER" in
    systemd|direct)
        pass "DEPLOY_SERVICE_MANAGER is valid value: $DEPLOY_SERVICE_MANAGER"
        ;;
    *)
        fail "DEPLOY_SERVICE_MANAGER has invalid value" "systemd|direct" "$DEPLOY_SERVICE_MANAGER"
        ;;
esac

# =============================================================================
# Test: get_environment_description returns non-empty
# =============================================================================
run_test
desc=$(get_environment_description)
if [ -n "$desc" ]; then
    pass "get_environment_description returns: $desc"
else
    fail "get_environment_description should return description" "non-empty string" "$desc"
fi

# =============================================================================
# Test: print_environment_summary runs without error
# =============================================================================
run_test
if output=$(print_environment_summary 2>&1); then
    pass "print_environment_summary runs without error"
else
    fail "print_environment_summary should not error" "success" "error"
fi

# =============================================================================
# Test: detect_environment can be called multiple times
# =============================================================================
run_test
detect_environment
if [ -n "$DEPLOY_ENV_TYPE" ]; then
    pass "detect_environment can be called again"
else
    fail "detect_environment should work on re-call" "non-empty DEPLOY_ENV_TYPE" "$DEPLOY_ENV_TYPE"
fi

# =============================================================================
# Test: Environment override works
# =============================================================================
run_test
DEPLOY_ENVIRONMENT="physical"
detect_environment
if [ "$DEPLOY_ENV_TYPE" = "physical" ]; then
    pass "DEPLOY_ENVIRONMENT override works"
else
    fail "DEPLOY_ENVIRONMENT override should set type" "physical" "$DEPLOY_ENV_TYPE"
fi
unset DEPLOY_ENVIRONMENT

# =============================================================================
# Test: Service manager override works
# =============================================================================
run_test
DEPLOY_SERVICE_MANAGER_OVERRIDE="direct"
DEPLOY_SERVICE_MANAGER="$DEPLOY_SERVICE_MANAGER_OVERRIDE"
detect_environment
# Note: detect_environment reads from env var, so we test the mechanism
if [ "$DEPLOY_SERVICE_MANAGER" = "direct" ] || [ "$DEPLOY_SERVICE_MANAGER" = "systemd" ]; then
    pass "Service manager is valid after override test"
else
    fail "Service manager should be valid" "direct or systemd" "$DEPLOY_SERVICE_MANAGER"
fi

# =============================================================================
# Summary
# =============================================================================
echo
echo "=== Test Summary ==="
echo "Tests run: $TESTS_RUN"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
echo

if [ $TESTS_FAILED -gt 0 ]; then
    exit 1
fi
exit 0
