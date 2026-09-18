# Test bootstrap safely

Run `make test-bootstrap PROFILE=laptop`. It builds the Ubuntu 24.04 Docker image, mounts only this checkout read-only at `/repo`, and runs bootstrap twice as root with `BOOTSTRAP_USER=developer`.

The verification script checks package-capable execution, profile selection, `keyKeeper` creation, permissions, managed symlinks, and duplicate configuration markers. Use `make test-shell` to investigate interactively.

Do not run `make bootstrap` to test changes on the host. Docker deliberately does not emulate systemd, so future service operations need separate manual review.
