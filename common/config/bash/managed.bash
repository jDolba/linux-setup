# Loaded from ~/.bashrc by linux-setup. Keep personal shell settings outside this file.

export PATH="$HOME/.local/bin:$PATH"

# Shortcuts used across projects.
alias dcup='docker compose down && docker compose up -d'
alias gitfr='git fetch --all --prune && git rebase -i origin/main'
