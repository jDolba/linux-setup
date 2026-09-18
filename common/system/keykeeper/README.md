# keyKeeper

`keyKeeper` is secure storage only. Bootstrap creates its mode-`0700` home,
`.ssh`, and `.ssh/keys` directories. Private keys are manually provisioned as
`keyKeeper:keyKeeper`, normally mode `0600`, and never enter this repository.

`key-keeper-unlock KEY-NAME [MINUTES]` performs a manually authorised, fixed
sudo operation. It opens only a validated keyKeeper key, adds it to the
invoking user's existing SSH agent with the native `ssh-add -t` lifetime, and
never returns private-key bytes through output or a user-owned file. The helper
does not provide a shell or arbitrary command execution as `keyKeeper`.

The corresponding public key is stored at
`/var/lib/key-keeper/public/KEY-NAME.pub`; it is safe to reference from SSH
configuration. Use `key-keeper-lock KEY-NAME` to remove that managed identity
early, or `key-keeper-lock --all` to remove all recorded keyKeeper identities.
