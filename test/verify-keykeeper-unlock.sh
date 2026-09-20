#!/usr/bin/env bash
# Exercise temporary keyKeeper-to-agent delegation in the disposable playground.
set -Eeuo pipefail

fail() { printf 'FAILED: %s\n' "$*" >&2; exit 1; }
expect_failure() {
    if "$@" >/tmp/key-keeper-test-output 2>&1; then
        fail "Expected failure: $*"
    fi
}

key_path=/home/keyKeeper/.ssh/keys/test-loader-key
ssh-keygen -q -t ed25519 -N '' -f "$key_path"
chown keyKeeper:keyKeeper "$key_path" "$key_path.pub"
chmod 0600 "$key_path"
before_metadata="$(stat -c '%U:%G:%a' "$key_path")"

# The real policy requires a password. Docker grants this one fixed command only
# so the test can exercise the same sudo transition non-interactively.
printf 'developer ALL=(root) NOPASSWD: /usr/local/libexec/key-keeper-agent-helper\n' >/etc/sudoers.d/key-keeper-test
chmod 0440 /etc/sudoers.d/key-keeper-test
visudo -cf /etc/sudoers.d/key-keeper-test >/dev/null

runuser -u developer -- bash -s <<'DEVELOPER'
set -Eeuo pipefail
key=/home/keyKeeper/.ssh/keys/test-loader-key
test ! -r "$key"
expect_failure() { if "$@" >/tmp/key-keeper-test-output 2>&1; then exit 1; fi; }
expect_failure /home/developer/.local/bin/key-keeper-unlock test-loader-key

printf '\n\n' | /home/developer/.local/bin/key-keeper-keygen test-generated-key 'developer test key'
test ! -e "$HOME/.ssh/test-generated-key"
test -f "$HOME/.ssh/test-generated-key.pub"
test "$(stat -c '%U:%G:%a' "$HOME/.ssh/test-generated-key.pub")" == 'developer:developer:644'
test ! -r /home/keyKeeper/.ssh/keys/test-generated-key
ssh-keygen -lf "$HOME/.ssh/test-generated-key.pub" >/dev/null
expect_failure /home/developer/.local/bin/key-keeper-keygen test-generated-key

ssh-keygen -q -t ed25519 -N '' -f "$HOME/.ssh/unrelated"
ssh-agent bash -s <<'AGENT'
set -Eeuo pipefail
expect_failure() { if "$@" >/tmp/key-keeper-test-output 2>&1; then exit 1; fi; }
shared_agent="$SSH_AUTH_SOCK"
runtime_directory="$(mktemp -d)"
trap 'rm -rf "$runtime_directory"' EXIT
mkdir -p "$runtime_directory/gcr"
ln -s "$shared_agent" "$runtime_directory/gcr/ssh"

XDG_RUNTIME_DIR="$runtime_directory" SHARED_AGENT="$shared_agent" ssh-agent bash -s <<'WORKER'
set -Eeuo pipefail
expect_failure() { if "$@" >/tmp/key-keeper-test-output 2>&1; then exit 1; fi; }
ssh-add "$HOME/.ssh/unrelated" >/dev/null
unrelated="$(ssh-add -l | awk 'NR == 1 { print $2 }')"

default_output="$(/home/developer/.local/bin/key-keeper-unlock test-loader-key 2>&1)"
grep -F 'unlocked for 5 minutes' <<<"$default_output"
grep -F 'Lifetime set to 300 seconds' <<<"$default_output"
grep -Eq '^Allowed at: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:[0-9]{2}$' <<<"$default_output"
grep -Eq '^Unlocked until: [0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}[+-][0-9]{2}:[0-9]{2}$' <<<"$default_output"
test "$(ssh-add -l | wc -l)" -eq 1
SSH_AUTH_SOCK="$SHARED_AGENT" ssh-add -l | grep -v -F "$unrelated" >/dev/null

explicit_output="$(/home/developer/.local/bin/key-keeper-unlock test-loader-key 10 2>&1)"
grep -F 'unlocked for 10 minutes' <<<"$explicit_output"
grep -F 'Lifetime set to 600 seconds' <<<"$explicit_output"
test "$(ssh-add -l | wc -l)" -eq 1
test "$(SSH_AUTH_SOCK="$SHARED_AGENT" ssh-add -l | wc -l)" -eq 1
ssh-add -l | grep -F "$unrelated" >/dev/null

/home/developer/.local/bin/key-keeper-lock test-loader-key
if SSH_AUTH_SOCK="$SHARED_AGENT" ssh-add -l >/dev/null 2>&1; then exit 1; fi
ssh-add -l | grep -F "$unrelated" >/dev/null

/home/developer/.local/bin/key-keeper-unlock test-loader-key 1 >/dev/null
/home/developer/.local/bin/key-keeper-lock --all
if SSH_AUTH_SOCK="$SHARED_AGENT" ssh-add -l >/dev/null 2>&1; then exit 1; fi
ssh-add -l | grep -F "$unrelated" >/dev/null

expect_failure /home/developer/.local/bin/key-keeper-unlock missing-key 10
expect_failure /home/developer/.local/bin/key-keeper-unlock ../../etc/passwd 10
expect_failure /home/developer/.local/bin/key-keeper-unlock test-loader-key foo
expect_failure /home/developer/.local/bin/key-keeper-unlock test-loader-key 0
expect_failure /home/developer/.local/bin/key-keeper-unlock test-loader-key -10
WORKER
AGENT
DEVELOPER

[[ "$(stat -c '%U:%G:%a' "$key_path")" == "$before_metadata" ]] || fail 'Unlock changed private-key metadata'
[[ ! -e /home/developer/.ssh/test-loader-key ]] || fail 'Unlock copied a private key into the user home'
[[ "$(stat -c '%U:%G:%a' /home/keyKeeper/.ssh/keys/test-generated-key)" == 'keyKeeper:keyKeeper:600' ]] || fail 'Generated private key has unsafe metadata'
[[ ! -e /home/developer/.ssh/test-generated-key ]] || fail 'Key generation copied a private key into the user home'

printf 'keyKeeper unlock verification passed.\n'
