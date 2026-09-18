#!/usr/bin/env bash
# Assertions for the disposable Docker playground. Run after bootstrap twice.
set -Eeuo pipefail

profile="${1:?profile is required}"
developer_home=/home/developer

fail() { printf 'FAILED: %s\n' "$*" >&2; exit 1; }
assert_link() {
    local destination="$1" source="$2"
    [[ -L "$destination" ]] || fail "Expected symlink: $destination"
    [[ "$(readlink -f "$destination")" == "$source" ]] || fail "Unexpected link target: $destination"
}
assert_mode() {
    local path="$1" mode="$2"
    [[ "$(stat -c '%a' "$path")" == "$mode" ]] || fail "Expected mode $mode: $path"
}

id keyKeeper >/dev/null || fail 'keyKeeper was not created'
assert_mode /home/keyKeeper 700
assert_mode /home/keyKeeper/.ssh 700
assert_link "$developer_home/.config/linux-setup/bash/managed.bash" /repo/common/config/bash/managed.bash
assert_link "$developer_home/.config/linux-setup/git/config" /repo/common/config/git/config
assert_link "$developer_home/.ssh/config.d/linux-setup.conf" /repo/common/config/ssh/config
assert_link "$developer_home/.tmux.conf" /repo/common/config/tmux/tmux.conf
assert_link "$developer_home/.local/bin/keykeeper-ssh" /repo/common/bin/keykeeper-ssh
[[ "$(grep -Fxc '# linux-setup: managed bash configuration' "$developer_home/.bashrc")" == 1 ]] || fail 'Bash marker was duplicated'
[[ "$(grep -Fxc '# linux-setup: managed git configuration' "$developer_home/.gitconfig")" == 1 ]] || fail 'Git marker was duplicated'
[[ "$(grep -Fxc '# linux-setup: managed SSH configuration' "$developer_home/.ssh/config")" == 1 ]] || fail 'SSH marker was duplicated'

printf 'Bootstrap verification passed for profile %s.\n' "$profile"
