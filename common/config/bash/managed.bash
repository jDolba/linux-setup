# Loaded from ~/.bashrc by linux-setup. Keep personal shell settings outside this file.

export PATH="$HOME/.local/bin:$PATH"

# GCR provides the shared desktop SSH agent. Prefer it over a stale inherited
# GNOME Keyring socket so every terminal uses the same agent.
if [[ -n "${XDG_RUNTIME_DIR:-}" && -S "$XDG_RUNTIME_DIR/gcr/ssh" ]]; then
    export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/gcr/ssh"
fi

# Shortcuts used across projects.
alias dcup='docker compose down && docker compose up -d'
alias gitfr='git fetch --all --prune && git rebase -i origin/main'
