# keyKeeper

`keyKeeper` is secure storage only. Bootstrap creates its mode-`0700` home,
`.ssh`, and `.ssh/keys` directories. `key-keeper-keygen KEY-NAME [COMMENT]`
generates an Ed25519 private key directly in that protected storage and places
only the public key at `~/.ssh/KEY-NAME.pub` for the invoking user. It uses the
standard `ssh-keygen` passphrase prompt; private keys never enter this
repository or a user-owned directory.

`key-keeper-unlock KEY-NAME [MINUTES]` performs a manually authorised, fixed
sudo operation. It opens only a validated keyKeeper key, adds it to the
invoking user's existing SSH agent with the native `ssh-add -t` lifetime, and
never returns private-key bytes through output or a user-owned file. The helper
does not provide a shell or arbitrary command execution as `keyKeeper`.

The helper keeps a root-managed public-key cache solely so locking does not
need to read the private key again. SSH configuration uses the corresponding
public key already held in `~/.ssh`. An `IdentityFile` ending in `.pub` tells
SSH to ask the agent for the matching identity; it does not give the normal
user private-key access. Use
`key-keeper-lock KEY-NAME` to remove that managed identity early, or
`key-keeper-lock --all` to remove all recorded keyKeeper identities.
