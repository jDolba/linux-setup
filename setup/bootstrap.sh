#!/usr/bin/env bash
# Configure one machine profile. This script makes real system changes unless --dry-run is used.
set -Eeuo pipefail

readonly REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
readonly COMMON_DIR="$REPO_ROOT/common"
readonly PROFILES_DIR="$REPO_ROOT/profiles"

DRY_RUN=false
TARGET_USER="${BOOTSTRAP_USER:-${SUDO_USER:-${USER}}}"
TARGET_HOME=""
PROFILE=""

log() { printf '%s\n' "==> $*"; }
warn() { printf '%s\n' "WARNING: $*" >&2; }
die() { printf '%s\n' "ERROR: $*" >&2; exit 1; }

run() {
    if "$DRY_RUN"; then
        printf 'DRY RUN:'
        printf ' %q' "$@"
        printf '\n'
    else
        "$@"
    fi
}

usage() {
    cat <<'EOF'
Usage: bootstrap.sh [--dry-run] <profile>

Available profiles are directories under profiles/.
Run this script as root (normally through `make bootstrap PROFILE=<profile>`).
Set BOOTSTRAP_USER when testing as root in a container.
EOF
}

available_profiles() {
    find "$PROFILES_DIR" -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort
}

require_ubuntu() {
    [[ -r /etc/os-release ]] || die "Cannot identify this operating system."
    # shellcheck disable=SC1091
    . /etc/os-release
    [[ "${ID:-}" == "ubuntu" ]] || die "This bootstrap currently supports Ubuntu only (found: ${ID:-unknown})."
}

require_root() {
    [[ "$EUID" -eq 0 ]] || die "Run through sudo, for example: make bootstrap PROFILE=$PROFILE"
}

ensure_directory() {
    local path="$1" mode="$2" owner="$3"
    run install -d -m "$mode" -o "$owner" -g "$owner" "$path"
}

managed_link() {
    local source="$1" destination="$2" owner="$3"
    [[ -e "$source" ]] || die "Managed source does not exist: $source"

    if [[ -L "$destination" ]]; then
        if [[ "$(readlink -f "$destination")" == "$(readlink -f "$source")" ]]; then
            log "Managed link already present: $destination"
            return
        fi
        warn "Skipping $destination; it is an unmanaged symlink."
        return
    fi
    if [[ -e "$destination" ]]; then
        warn "Skipping $destination; an unmanaged file already exists."
        return
    fi

    ensure_directory "$(dirname "$destination")" 0755 "$owner"
    run ln -s "$source" "$destination"
    run chown -h "$owner:$owner" "$destination"
    log "Created managed link: $destination"
}

append_once() {
    local destination="$1" owner="$2" marker="$3" content="$4"
    if [[ -e "$destination" ]] && grep -Fqx "$marker" "$destination"; then
        log "Managed entry already present: $destination"
        return
    fi
    if "$DRY_RUN"; then
        log "Would add managed entry to: $destination"
        return
    fi
    install -d -m 0755 -o "$owner" -g "$owner" "$(dirname "$destination")"
    touch "$destination"
    chown "$owner:$owner" "$destination"
    printf '\n%s\n%s\n' "$marker" "$content" >> "$destination"
    chown "$owner:$owner" "$destination"
    log "Added managed entry: $destination"
}

read_package_file() {
    local package_file="$1"
    [[ -f "$package_file" ]] || return 0
    while IFS= read -r package; do
        [[ -z "$package" || "$package" == \#* ]] && continue
        PACKAGES+=("$package")
    done < "$package_file"
}

install_packages() {
    PACKAGES=()
    read_package_file "$COMMON_DIR/system/packages/common.txt"
    read_package_file "$PROFILE_DIR/packages.txt"
    ((${#PACKAGES[@]})) || return
    log "Installing ${#PACKAGES[@]} package(s)."
    run apt-get update
    run apt-get install -y --no-install-recommends "${PACKAGES[@]}"
}

setup_keykeeper() {
    local keykeeper_home
    if ! id -u keyKeeper >/dev/null 2>&1; then
        run useradd --create-home --shell /bin/bash keyKeeper
        log "Created keyKeeper user."
        if "$DRY_RUN"; then
            log "Would prepare keyKeeper home and .ssh directory."
            return
        fi
    else
        log "keyKeeper user already exists."
    fi
    keykeeper_home="$(getent passwd keyKeeper | cut -d: -f6)"
    [[ -n "$keykeeper_home" ]] || die "Unable to determine keyKeeper home directory."
    ensure_directory "$keykeeper_home" 0700 keyKeeper
    ensure_directory "$keykeeper_home/.ssh" 0700 keyKeeper
    ensure_directory "$keykeeper_home/.ssh/keys" 0700 keyKeeper
    log "Prepared keyKeeper home and key directory."
}

install_keykeeper_helper() {
    local helper_source="$COMMON_DIR/system/keykeeper/key-keeper-agent-helper"
    local helper_destination=/usr/local/libexec/key-keeper-agent-helper
    local sudoers_destination="/etc/sudoers.d/key-keeper-agent-$TARGET_USER"
    local temporary_sudoers

    [[ -x "$helper_source" ]] || die "Missing keyKeeper helper: $helper_source"
    run install -D -m 0755 -o root -g root "$helper_source" "$helper_destination"
    if "$DRY_RUN"; then
        log "Would install restricted sudo policy for keyKeeper helper."
        return
    fi
    temporary_sudoers="$(mktemp)"
    printf '%s ALL=(root) %s\n' "$TARGET_USER" "$helper_destination" > "$temporary_sudoers"
    visudo -cf "$temporary_sudoers" >/dev/null || die 'Generated keyKeeper sudo policy is invalid.'
    install -m 0440 -o root -g root "$temporary_sudoers" "$sudoers_destination"
    rm -f "$temporary_sudoers"
    log "Installed restricted sudo policy for keyKeeper helper."
}

link_bin_directory() {
    local bin_dir="$1" command
    [[ -d "$bin_dir" ]] || return 0
    while IFS= read -r -d '' command; do
        [[ -x "$command" ]] || continue
        managed_link "$command" "$TARGET_HOME/.local/bin/$(basename "$command")" "$TARGET_USER"
    done < <(find "$bin_dir" -maxdepth 1 -type f -print0)
}

apply_common_configuration() {
    managed_link "$COMMON_DIR/config/bash/managed.bash" "$TARGET_HOME/.config/linux-setup/bash/managed.bash" "$TARGET_USER"
    append_once "$TARGET_HOME/.bashrc" "$TARGET_USER" \
        '# linux-setup: managed bash configuration' \
        '[ -r "$HOME/.config/linux-setup/bash/managed.bash" ] && . "$HOME/.config/linux-setup/bash/managed.bash"'

    managed_link "$COMMON_DIR/config/git/config" "$TARGET_HOME/.config/linux-setup/git/config" "$TARGET_USER"
    append_once "$TARGET_HOME/.gitconfig" "$TARGET_USER" \
        '# linux-setup: managed git configuration' \
        $'[include]
    path = ~/.config/linux-setup/git/config'

    ensure_directory "$TARGET_HOME/.ssh" 0700 "$TARGET_USER"
    managed_link "$COMMON_DIR/config/ssh/config" "$TARGET_HOME/.ssh/config.d/linux-setup.conf" "$TARGET_USER"

    managed_link "$COMMON_DIR/config/tmux/tmux.conf" "$TARGET_HOME/.tmux.conf" "$TARGET_USER"
    link_bin_directory "$COMMON_DIR/bin"
}

apply_profile() {
    local profile_ssh_config="$PROFILE_DIR/config/ssh/config"
    if [[ -f "$profile_ssh_config" ]]; then
        managed_link "$profile_ssh_config" "$TARGET_HOME/.ssh/config" "$TARGET_USER"
        if [[ ! -L "$TARGET_HOME/.ssh/config" ]] || [[ "$(readlink -f "$TARGET_HOME/.ssh/config")" != "$(readlink -f "$profile_ssh_config")" ]]; then
            warn "Skipping managed SSH configuration because $TARGET_HOME/.ssh/config is unmanaged."
        fi
    else
        append_once "$TARGET_HOME/.ssh/config" "$TARGET_USER" \
            '# linux-setup: managed SSH configuration' \
            'Include ~/.ssh/config.d/*.conf'
    fi
    link_bin_directory "$PROFILE_DIR/bin"
    if [[ -x "$PROFILE_DIR/setup.sh" ]]; then
        log "Running profile setup: $PROFILE"
        BOOTSTRAP_USER="$TARGET_USER" BOOTSTRAP_HOME="$TARGET_HOME" DRY_RUN="$DRY_RUN" "$PROFILE_DIR/setup.sh"
    fi
}

main() {
    local arg
    while (($#)); do
        arg="$1"
        case "$arg" in
            --dry-run) DRY_RUN=true ;;
            -h|--help) usage; exit 0 ;;
            -*) die "Unknown option: $arg" ;;
            *)
                [[ -z "${PROFILE:-}" ]] || die "Specify exactly one profile."
                PROFILE="$arg"
                ;;
        esac
        shift
    done
    [[ -n "${PROFILE:-}" ]] || { usage; exit 2; }
    [[ "$PROFILE" =~ ^[a-zA-Z0-9][a-zA-Z0-9_-]*$ ]] || die "Invalid profile name: $PROFILE"
    PROFILE_DIR="$PROFILES_DIR/$PROFILE"
    [[ -d "$PROFILE_DIR" ]] || die "Unknown profile '$PROFILE'. Available: $(available_profiles | paste -sd ', ' -)"

    require_ubuntu
    if ! "$DRY_RUN"; then
        require_root
    fi
    id -u "$TARGET_USER" >/dev/null 2>&1 || die "Target user does not exist: $TARGET_USER"
    TARGET_HOME="$(getent passwd "$TARGET_USER" | cut -d: -f6)"
    [[ -n "$TARGET_HOME" ]] || die "Unable to determine home directory for $TARGET_USER"

    log "Applying common setup and profile '$PROFILE' for user '$TARGET_USER'."
    install_packages
    setup_keykeeper
    install_keykeeper_helper
    apply_common_configuration
    apply_profile
    log "Bootstrap completed for profile '$PROFILE'."
}

main "$@"
