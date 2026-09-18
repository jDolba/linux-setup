# linux-setup

Versioned Ubuntu setup for managed machines. Shared setup lives in `common/`; a selected directory in `profiles/` adds the machine role.

## Fresh machine

Clone the repository, review its configuration and scripts, then apply an available profile:

```bash
git clone <repository-url> linux-setup
cd linux-setup
make bootstrap PROFILE=laptop
```

`bootstrap` makes real system changes: it installs packages, creates the `keyKeeper` account, and manages configuration links. Review it before running it. To see intended operations first, run:

```bash
make dry-run PROFILE=laptop
```

The only current profile is `laptop`. Add a future machine by creating `profiles/<name>/` with a `packages.txt`, optional executable `setup.sh`, optional `bin/`, or all three. Profile discovery is automatic; bootstrap does not need a new conditional.

## Layout

- `common/` contains shared package lists, shell/Git/SSH/tmux configuration, helpers, and system setup.
- `profiles/laptop/` contains the laptop baseline.
- `setup/bootstrap.sh` applies common setup and the chosen profile.
- `test/` contains the isolated Ubuntu playground.

Managed configuration is symlinked from the checkout where appropriate. The laptop profile owns the complete managed SSH config, including the copied laptop host aliases. Existing unmanaged files are reported and left unchanged. Bash configuration is extended with one marked source entry instead of being replaced.

## Testing

Use Docker to test without modifying the workstation:

```bash
make test-shell
make test-bootstrap PROFILE=laptop
```

`test-bootstrap` builds a disposable Ubuntu 24.04 container, runs bootstrap twice, and verifies users, permissions, links, managed configuration markers, and idempotency. The repository is its only bind mount and is mounted read-only. Docker does not emulate systemd; service-management work requires later manual verification.

## Security model

Coding agents and everyday development run as the normal user. Sensitive SSH private keys belong only to `keyKeeper`, whose home and `.ssh` directory are mode `0700`. Bootstrap creates the account structure but never creates, copies, or versions keys. Host-specific identities belong in private untracked files; see `common/config/ssh/config.example` for the explicit-identity pattern.

Run `keykeeper-load-key <key-name> [minutes]` to add `/home/keyKeeper/.ssh/<key-name>` to the current user's existing SSH agent for a limited time; the default is five minutes and the maximum is 1,440. The helper uses normal sudo authentication, creates only a public-key companion under `~/.ssh/key-keeper-identities/`, and streams the private key directly into `ssh-add` without writing it beneath the normal user's home. After expiry, SSH cannot authenticate with that identity unless it is loaded again.

`keykeeper-ssh` is an explicit helper that invokes SSH as `keyKeeper` through normal sudo authentication. There is no passwordless sudo policy or broad home-directory sharing. Never commit credentials, private keys, tokens, certificates, or real secret values.

## Agent context

[`AGENTS.md`](AGENTS.md) contains concise, tool-independent operational instructions for coding agents. It complements this human-facing guide.
