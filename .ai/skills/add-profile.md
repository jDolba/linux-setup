# Add a profile

1. Create `profiles/<profile-name>/` only when a real machine role needs it.
2. Add `packages.txt` for apt packages, one package per line. Add an executable `setup.sh` only for profile-specific work that cannot be expressed as packages or managed links.
3. Put executable profile-only helpers in `bin/`; bootstrap links them into the normal user's `~/.local/bin` without overwriting unmanaged files.
4. If `setup.sh` is needed, make it idempotent, use strict Bash mode, and honour `DRY_RUN`, `BOOTSTRAP_USER`, and `BOOTSTRAP_HOME` supplied by bootstrap.
5. Run `make test-bootstrap PROFILE=<profile-name>` in Docker. Review the diff and staged files for secrets before committing.

Do not add placeholder profiles for possible future machines. Bootstrap discovers a profile from its directory, so no central list needs updating.
