# keyKeeper

`keyKeeper` is secure storage only. Bootstrap creates its mode-`0700` home,
`.ssh`, and `.ssh/keys` directories. Private keys are manually provisioned as
`keyKeeper:keyKeeper`, normally mode `0600`, and never enter this repository.

`key-keeper-unlock KEY-NAME [MINUTES]` performs a manually authorised, fixed
sudo operation. It opens only a validated keyKeeper key, adds it to the
invoking user's existing SSH agent with the native `ssh-add -t` lifetime, and
never returns private-key bytes through output or a user-owned file. The helper
does not provide a shell or arbitrary command execution as `keyKeeper`.

The helper stores public-key metadata under `/var/lib/key-keeper/public/` to
identify managed agent identities for locking and to select them from SSH
configuration. An `IdentityFile` ending in `.pub` tells SSH to ask the agent
for the matching identity; it does not give the normal user private-key access.
Use `key-keeper-lock KEY-NAME` to remove that managed identity early, or
`key-keeper-lock --all` to remove all recorded keyKeeper identities.
