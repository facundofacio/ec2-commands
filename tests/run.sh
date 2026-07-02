#!/usr/bin/env bash
# Runner de tests para common.sh. Corre en macOS (bash 3.2) y Ubuntu.
set -u
TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(cd "$TESTS_DIR/.." && pwd)"
export PATH="$TESTS_DIR/mock:$PATH"
export MOCK_AWS_CONFIG="$TESTS_DIR/fixtures/aws_config"

PASS=0; FAIL=0

assert_eq() { # <actual> <expected> <msg>
  if [ "$1" = "$2" ]; then PASS=$((PASS+1)); printf '  ok: %s\n' "$3"
  else FAIL=$((FAIL+1)); printf '  FAIL: %s (got [%s] want [%s])\n' "$3" "$1" "$2"; fi
}
assert_ok() { # <rc> <msg>
  if [ "$1" -eq 0 ]; then PASS=$((PASS+1)); printf '  ok: %s\n' "$2"
  else FAIL=$((FAIL+1)); printf '  FAIL: %s (rc=%s)\n' "$2" "$1"; fi
}
assert_fail() { # <rc> <msg>
  if [ "$1" -ne 0 ]; then PASS=$((PASS+1)); printf '  ok: %s\n' "$2"
  else FAIL=$((FAIL+1)); printf '  FAIL: %s (rc=0)\n' "$2"; fi
}

# shellcheck source=/dev/null
. "$REPO_DIR/common.sh" || { echo "no se pudo sourcear common.sh"; exit 1; }

test_resolve_prefers_ec2cli_dir() {
  local tmp; tmp=$(mktemp -d)
  mkdir -p "$tmp/.ec2-cli"
  printf 'X=i-0123456789abcdef0:legacy-static:us-east-1:a:/k.pem\n' > "$tmp/.ec2-cli/config.ini"
  local got; got=$(HOME="$tmp" resolve_config_file)
  assert_eq "$got" "$tmp/.ec2-cli/config.ini" "resolve usa ~/.ec2-cli si existe"
  rm -rf "$tmp"
}

test_resolve_falls_back_to_repo() {
  local tmp; tmp=$(mktemp -d)
  local got; got=$(HOME="$tmp" resolve_config_file)
  assert_eq "$got" "$COMMON_DIR/config.ini" "resolve cae al repo si no hay ~/.ec2-cli"
  rm -rf "$tmp"
}

test_load_config_parses_fields() {
  local tmp; tmp=$(mktemp -d); mkdir -p "$tmp/.ec2-cli"
  printf 'DEVELOPMENT=i-0123456789abcdef0:DevAccess-123456789012:us-east-1:dev-server:~/keys/k.pem\n' > "$tmp/.ec2-cli/config.ini"
  HOME="$tmp" load_config DEVELOPMENT
  assert_eq "$INSTANCE_ID" "i-0123456789abcdef0" "instance id"
  assert_eq "$AWS_PROFILE" "DevAccess-123456789012" "profile"
  assert_eq "$AWS_REGION" "us-east-1" "region"
  assert_eq "$SSH_HOST_ALIAS" "dev-server" "ssh alias"
  assert_eq "$PEM_FILE" "$tmp/keys/k.pem" "pem con ~ expandido"
  rm -rf "$tmp"
}

test_load_config_missing_returns_1() {
  local tmp; tmp=$(mktemp -d); mkdir -p "$tmp/.ec2-cli"
  printf 'DEVELOPMENT=i-0123456789abcdef0:legacy-static:us-east-1:a:/k.pem\n' > "$tmp/.ec2-cli/config.ini"
  HOME="$tmp" load_config no-existe >/dev/null 2>&1
  assert_fail "$?" "load_config retorna 1 si no encuentra la config"
  rm -rf "$tmp"
}

test_is_sso_profile_true() {
  is_sso_profile DevAccess-123456789012
  assert_ok "$?" "detecta perfil SSO"
}

test_is_sso_profile_false_for_static() {
  is_sso_profile legacy-static
  assert_fail "$?" "perfil estático no es SSO"
}

test_ensure_session_static_no_login() {
  local tmp; tmp=$(mktemp -d); local marker="$tmp/marker"
  MOCK_SESSION_VALID="" MOCK_LOGIN_MARKER="$marker" ensure_aws_session legacy-static
  assert_ok "$?" "sesión OK para perfil estático"
  [ -f "$marker" ]; assert_fail "$?" "no se llamó a sso login para estático"
  rm -rf "$tmp"
}

test_ensure_session_valid_no_login() {
  local tmp; tmp=$(mktemp -d); local marker="$tmp/marker"
  MOCK_SESSION_VALID="1" MOCK_LOGIN_MARKER="$marker" ensure_aws_session DevAccess-123456789012
  assert_ok "$?" "sesión SSO ya válida"
  [ -f "$marker" ]; assert_fail "$?" "no se llamó a sso login si la sesión es válida"
  rm -rf "$tmp"
}

test_ensure_session_expired_triggers_login() {
  local tmp; tmp=$(mktemp -d); local marker="$tmp/marker"
  MOCK_SESSION_VALID="" MOCK_LOGIN_MARKER="$marker" ensure_aws_session DevAccess-123456789012 >/dev/null 2>&1
  assert_ok "$?" "sesión recuperada tras login"
  [ -f "$marker" ]; assert_ok "$?" "se llamó a sso login al expirar"
  rm -rf "$tmp"
}

for t in $(declare -F | awk '{print $3}' | grep '^test_'); do
  printf '%s\n' "$t"
  "$t"
done

printf '\n%s passed, %s failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
