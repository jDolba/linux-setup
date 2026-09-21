# Agent context

Skill can be found in `.ai/skills`

This repository defines repeatable Ubuntu setup for managed machines. `common/` holds shared packages, configuration, and helpers; `profiles/<name>/` adds machine-specific packages or setup.

Keep configuration and scripts versioned here. Never commit credentials, private keys, tokens, certificates, or real machine-specific secrets. Use examples or templates instead.

`keyKeeper` owns sensitive SSH keys. It is secure storage only: normal development users and coding agents must not be given filesystem access to those keys or a shell/arbitrary command transition as `keyKeeper`.

`key-keeper-unlock KEY-NAME [MINUTES]` deliberately grants the invoking user's existing SSH agent temporary use of one identity (five minutes by default). During that window every process able to use that agent, including AI agents with shell access, can authenticate as that identity. Keep unlock periods short; private-key bytes must never be written to user-controlled output or files. Note that `ssh-agent` might intentionally not have the appropriate key loaded to prevent AI agents from accessing certain remote hosts without explicit unlocking.

Do not run bootstrap on the host unless the user explicitly requests it. Use the Docker playground for execution testing. Bootstrap changes must be idempotent, avoid overwriting unmanaged files, and avoid destructive host operations.

Make small logical commits. Before each commit, inspect the diff and staged files for unintended changes and secret material.
