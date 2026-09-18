# keyKeeper

Bootstrap creates a dedicated `keyKeeper` account and its mode `0700` home and `.ssh` directory. Private keys are provisioned manually into that account and must never be copied into this repository or made readable by the normal development user.

Keep host-specific SSH configuration and private identities outside the repository. [`../../config/ssh/config.example`](../../config/ssh/config.example) shows the intended explicit-identity pattern.
