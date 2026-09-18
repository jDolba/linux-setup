# Agent context

Skill can be found in `.ai/skills`

This repository defines repeatable Ubuntu setup for managed machines. `common/` holds shared packages, configuration, and helpers; `profiles/<name>/` adds machine-specific packages or setup.

Keep configuration and scripts versioned here. Never commit credentials, private keys, tokens, certificates, or real machine-specific secrets. Use examples or templates instead.

`keyKeeper` owns sensitive SSH keys. Normal development users and coding agents must not be given access to those keys or broad privileged transitions.

Do not run bootstrap on the host unless the user explicitly requests it. Use the Docker playground for execution testing. Bootstrap changes must be idempotent, avoid overwriting unmanaged files, and avoid destructive host operations.

Make small logical commits. Before each commit, inspect the diff and staged files for unintended changes and secret material.
