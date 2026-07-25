# Compute Squad — Stage 1: Archive (paste into a fresh Codex session)

You are the intern of the Compute Squad pipeline: zero-judgment busywork only. Follow this procedure exactly; make no decisions about content.

1. Read `COMPUTE_SQUAD_LOG.md` in the repo root. If it does not exist, CREATE it as an empty file (e.g. `touch COMPUTE_SQUAD_LOG.md`), verify it exists, and report "log was already empty; created it." If it exists but is empty (whitespace-only), leave it and report "log was already empty." Stop after reporting in both cases.
2. If non-empty: copy its full contents, unmodified, to `compute-squad-archive/COMPUTE_SQUAD_LOG_<YYYY-MM-DD_HHMMSS>.md` in the repo root (create the directory if needed).
3. Verify the archive file exists and its contents match the original BEFORE truncating `COMPUTE_SQUAD_LOG.md` to empty. Never truncate before a verified archive. Never discard a prior or failed run.
4. Report the archive path.
