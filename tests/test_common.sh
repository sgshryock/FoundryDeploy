#!/bin/bash
# Tests for lib/common.sh
# Run with: ./tests/test_common.sh

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

echo "=== Testing lib/common.sh ==="
echo

# Source the library
source "$PROJECT_DIR/lib/common.sh"

# =============================================================================
# Test: Logging functions exist
# =============================================================================
run_test
if type log_info &>/dev/null; then
    pass "log_info function exists"
else
    fail "log_info function should exist" "defined" "undefined"
fi

run_test
if type log_ok &>/dev/null; then
    pass "log_ok function exists"
else
    fail "log_ok function should exist" "defined" "undefined"
fi

run_test
if type log_warn &>/dev/null; then
    pass "log_warn function exists"
else
    fail "log_warn function should exist" "defined" "undefined"
fi

run_test
if type log_error &>/dev/null; then
    pass "log_error function exists"
else
    fail "log_error function should exist" "defined" "undefined"
fi

# =============================================================================
# Test: Service functions exist
# =============================================================================
run_test
if type service_start &>/dev/null; then
    pass "service_start function exists"
else
    fail "service_start function should exist" "defined" "undefined"
fi

run_test
if type service_stop &>/dev/null; then
    pass "service_stop function exists"
else
    fail "service_stop function should exist" "defined" "undefined"
fi

run_test
if type service_reload &>/dev/null; then
    pass "service_reload function exists"
else
    fail "service_reload function should exist" "defined" "undefined"
fi

run_test
if type service_restart &>/dev/null; then
    pass "service_restart function exists"
else
    fail "service_restart function should exist" "defined" "undefined"
fi

run_test
if type service_enable &>/dev/null; then
    pass "service_enable function exists"
else
    fail "service_enable function should exist" "defined" "undefined"
fi

run_test
if type is_service_running &>/dev/null; then
    pass "is_service_running function exists"
else
    fail "is_service_running function should exist" "defined" "undefined"
fi

# =============================================================================
# Test: Docker functions exist
# =============================================================================
run_test
if type check_docker &>/dev/null; then
    pass "check_docker function exists"
else
    fail "check_docker function should exist" "defined" "undefined"
fi

run_test
if type check_docker_daemon &>/dev/null; then
    pass "check_docker_daemon function exists"
else
    fail "check_docker_daemon function should exist" "defined" "undefined"
fi

run_test
if type check_docker_compose &>/dev/null; then
    pass "check_docker_compose function exists"
else
    fail "check_docker_compose function should exist" "defined" "undefined"
fi

# =============================================================================
# Test: Validation functions exist
# =============================================================================
run_test
if type validate_non_empty &>/dev/null; then
    pass "validate_non_empty function exists"
else
    fail "validate_non_empty function should exist" "defined" "undefined"
fi

run_test
if type validate_port &>/dev/null; then
    pass "validate_port function exists"
else
    fail "validate_port function should exist" "defined" "undefined"
fi

run_test
if type validate_hostname &>/dev/null; then
    pass "validate_hostname function exists"
else
    fail "validate_hostname function should exist" "defined" "undefined"
fi

# =============================================================================
# Test: validate_non_empty works correctly
# =============================================================================
run_test
if validate_non_empty "test" "field" 2>/dev/null; then
    pass "validate_non_empty accepts non-empty string"
else
    fail "validate_non_empty should accept non-empty" "success" "failure"
fi

run_test
if ! validate_non_empty "" "field" 2>/dev/null; then
    pass "validate_non_empty rejects empty string"
else
    fail "validate_non_empty should reject empty" "failure" "success"
fi

# =============================================================================
# Test: validate_port works correctly
# =============================================================================
run_test
if validate_port "80" 2>/dev/null; then
    pass "validate_port accepts valid port 80"
else
    fail "validate_port should accept 80" "success" "failure"
fi

run_test
if validate_port "443" 2>/dev/null; then
    pass "validate_port accepts valid port 443"
else
    fail "validate_port should accept 443" "success" "failure"
fi

run_test
if validate_port "65535" 2>/dev/null; then
    pass "validate_port accepts max port 65535"
else
    fail "validate_port should accept 65535" "success" "failure"
fi

run_test
if ! validate_port "0" 2>/dev/null; then
    pass "validate_port rejects port 0"
else
    fail "validate_port should reject 0" "failure" "success"
fi

run_test
if ! validate_port "65536" 2>/dev/null; then
    pass "validate_port rejects port > 65535"
else
    fail "validate_port should reject 65536" "failure" "success"
fi

run_test
if ! validate_port "abc" 2>/dev/null; then
    pass "validate_port rejects non-numeric"
else
    fail "validate_port should reject abc" "failure" "success"
fi

# =============================================================================
# Test: validate_hostname works correctly
# =============================================================================
run_test
if validate_hostname "localhost" 2>/dev/null; then
    pass "validate_hostname accepts localhost"
else
    fail "validate_hostname should accept localhost" "success" "failure"
fi

run_test
if validate_hostname "server.local" 2>/dev/null; then
    pass "validate_hostname accepts server.local"
else
    fail "validate_hostname should accept server.local" "success" "failure"
fi

run_test
if validate_hostname "192.168.1.1" 2>/dev/null; then
    pass "validate_hostname accepts IP address"
else
    fail "validate_hostname should accept IP" "success" "failure"
fi

run_test
if validate_hostname "my-server" 2>/dev/null; then
    pass "validate_hostname accepts hostname with hyphen"
else
    fail "validate_hostname should accept hyphen" "success" "failure"
fi

# =============================================================================
# Test: parse_env_value function exists
# =============================================================================
run_test
if type parse_env_value &>/dev/null; then
    pass "parse_env_value function exists"
else
    fail "parse_env_value function should exist" "defined" "undefined"
fi

# =============================================================================
# Test: get_volume_name function exists and works
# =============================================================================
run_test
if type get_volume_name &>/dev/null; then
    pass "get_volume_name function exists"
else
    fail "get_volume_name function should exist" "defined" "undefined"
fi

run_test
volume=$(get_volume_name "test_data")
if [[ "$volume" == *"_test_data" ]]; then
    pass "get_volume_name returns prefixed volume name"
else
    fail "get_volume_name should return prefixed name" "*_test_data" "$volume"
fi

# =============================================================================
# Test: Utility functions exist
# =============================================================================
run_test
if type format_bytes &>/dev/null; then
    pass "format_bytes function exists"
else
    fail "format_bytes function should exist" "defined" "undefined"
fi

run_test
if type format_duration &>/dev/null; then
    pass "format_duration function exists"
else
    fail "format_duration function should exist" "defined" "undefined"
fi

# =============================================================================
# Test: format_bytes works correctly
# =============================================================================
run_test
result=$(format_bytes 1024)
if [[ "$result" == *"K"* ]]; then
    pass "format_bytes formats KB correctly: $result"
else
    fail "format_bytes should format KB" "*K*" "$result"
fi

run_test
result=$(format_bytes 1048576)
if [[ "$result" == *"M"* ]]; then
    pass "format_bytes formats MB correctly: $result"
else
    fail "format_bytes should format MB" "*M*" "$result"
fi

# =============================================================================
# Test: format_duration works correctly
# =============================================================================
run_test
result=$(format_duration 30)
if [[ "$result" == *"seconds"* ]]; then
    pass "format_duration formats seconds: $result"
else
    fail "format_duration should format seconds" "*seconds*" "$result"
fi

run_test
result=$(format_duration 3600)
if [[ "$result" == *"hour"* ]]; then
    pass "format_duration formats hours: $result"
else
    fail "format_duration should format hours" "*hour*" "$result"
fi

# =============================================================================
# Test: IP and URL functions exist
# =============================================================================
run_test
if type get_primary_ip &>/dev/null; then
    pass "get_primary_ip function exists"
else
    fail "get_primary_ip function should exist" "defined" "undefined"
fi

run_test
if type get_access_url &>/dev/null; then
    pass "get_access_url function exists"
else
    fail "get_access_url function should exist" "defined" "undefined"
fi

# =============================================================================
# Test: get_access_url returns valid URL
# =============================================================================
run_test
result=$(get_access_url "testhost")
if [[ "$result" == "https://"* ]]; then
    pass "get_access_url returns https URL: $result"
else
    fail "get_access_url should return https URL" "https://*" "$result"
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
