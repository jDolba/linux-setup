# Security review

Before every commit, inspect `git diff --cached` and the staged file list. Search staged text for private-key blocks, passwords, API tokens, access tokens, and credential files. Do not rely only on `.gitignore`.

Review bootstrap changes for unmanaged-file overwrites, broad sudo rules, dangerous group membership, weak `keyKeeper` ownership or permissions, and normal-user access to `keyKeeper`'s home or SSH keys. Docker tests must not mount host SSH data, `/etc`, `/run`, Docker's socket, or another sensitive host location.
