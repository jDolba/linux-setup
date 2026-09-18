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

ssh-keygen -q -t ed25519 -N '' -f "$HOME/.ssh/unrelated"
ssh-agent bash -s <<'AGENT'
set -Eeuo pipefail
expect_failure() { if "$@" >/tmp/key-keeper-test-output 2>&1; then exit 1; fi; }
ssh-add "$HOME/.ssh/unrelated" >/dev/null
unrelated="$(ssh-add -l | awk 'NR == 1 { print $2 }')"

default_output="$(/home/developer/.local/bin/key-keeper-unlock test-loader-key 2>&1)"
grep -F 'unlocked for 5 minutes' <<<"$default_output"
grep -F 'Lifetime set to 300 seconds' <<<"$default_output"
test "$(ssh-add -l | wc -l)" -eq 2

explicit_output="$(/home/developer/.local/bin/key-keeper-unlock test-loader-key 10 2>&1)"
grep -F 'unlocked for 10 minutes' <<<"$explicit_output"
grep -F 'Lifetime set to 600 seconds' <<<"$explicit_output"
test "$(ssh-add -l | wc -l)" -eq 2
ssh-add -l | grep -F "$unrelated" >/dev/null

/home/developer/.local/bin/key-keeper-lock test-loader-key
test "$(ssh-add -l | wc -l)" -eq 1
ssh-add -l | grep -F "$unrelated" >/dev/null

/home/developer/.local/bin/key-keeper-unlock test-loader-key 1 >/dev/null
/home/developer/.local/bin/key-keeper-lock --all
test "$(ssh-add -l | wc -l)" -eq 1
ssh-add -l | grep -F "$unrelated" >/dev/null

expect_failure /home/developer/.local/bin/key-keeper-unlock missing-key 10
expect_failure /home/developer/.local/bin/key-keeper-unlock ../../etc/passwd 10
expect_failure /home/developer/.local/bin/key-keeper-unlock test-loader-key foo
expect_failure /home/developer/.local/bin/key-keeper-unlock test-loader-key 0
expect_failure /home/developer/.local/bin/key-keeper-unlock test-loader-key -10
AGENT
DEVELOPER

[[ "$(stat -c '%U:%G:%a' "$key_path")" == "$before_metadata" ]] || fail 'Unlock changed private-key metadata'
[[ ! -e /home/developer/.ssh/test-loader-key ]] || fail 'Unlock copied a private key into the user home'

printf 'keyKeeper unlock verification passed.\n'
