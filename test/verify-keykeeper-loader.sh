#!/usr/bin/env bash
# Exercise a throwaway key and agent inside the Docker playground.
set -Eeuo pipefail

key_path=/home/keyKeeper/.ssh/test-loader-key
ssh-keygen -q -t ed25519 -N '' -f "$key_path"
chown keyKeeper:keyKeeper "$key_path" "$key_path.pub"
chmod 0600 "$key_path"

ssh-agent bash -lc '
    /repo/common/bin/keykeeper-load-key test-loader-key 1
    ssh-add -l >/dev/null
    test -f "$HOME/.ssh/linux-setup-identities/test-loader-key.pub"
'

printf 'keyKeeper loader verification passed.\n'
