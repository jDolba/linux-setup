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

Coding agents and everyday development run as the normal user. Sensitive SSH private keys belong only to `keyKeeper`, whose home, `.ssh`, and `.ssh/keys` directories are mode `0700`. Bootstrap creates the account structure but never creates, copies, or versions private keys. Keys are manually provisioned as `keyKeeper:keyKeeper`, normally mode `0600`.

The identity lifecycle is deliberately brief:

```text
LOCKED: keyKeeper owns the private key; the normal user cannot read or use it.
    key-keeper-unlock hetzner-prod 10
UNLOCKED FOR 10 MINUTES: the key remains unreadable, but is usable through the
normal user's existing ssh-agent.
    native ssh-agent expiry
LOCKED
```

Run `key-keeper-unlock KEY-NAME [MINUTES]`; the default is five minutes and the maximum is 1,440. The command asks sudo for an explicit privileged transition, validates the key name, and uses `ssh-add -t` with the selected user's existing `SSH_AUTH_SOCK`. It never changes private-key ownership or permissions, copies it into the user home, or emits its contents. A fixed root-owned helper has no shell or arbitrary-command mode as `keyKeeper`.

Use `key-keeper-lock KEY-NAME` to remove one managed identity early, or `key-keeper-lock --all` to remove all managed identities while leaving unrelated agent identities alone. The helper retains root-managed public-key metadata solely to identify those managed identities; normal SSH authentication uses the agent and does not refer to a protected private-key path.

Sensitive identities are unavailable while locked. Running `key-keeper-unlock` temporarily makes the selected identity usable by processes running in the current user's environment, including AI agents with shell access. Keep unlock periods short. The five-minute default is intentional.

Never commit credentials, private keys, tokens, certificates, or real secret values.

## Agent context

[`AGENTS.md`](AGENTS.md) contains concise, tool-independent operational instructions for coding agents. It complements this human-facing guide.
