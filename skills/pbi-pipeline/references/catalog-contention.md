# Catalog Contention Reference

How parallel PBI pipelines coordinate writes to shared catalog specs
under `docs/design/specs/`. 3-layer defense.

## Layer 1: Sprint planning pre-separation (primary defense)

SM records `catalog_targets[]` per PBI in `backlog.json` during sprint
planning. PBIs with overlapping `catalog_targets` MUST NOT be assigned
to different developers in parallel. SM either:

- Assigns overlapping PBIs to the same Developer (sequential), or
- Splits the PBI to remove overlap.

This is enforced in `skills/sprint-planning/SKILL.md`. Verify in your
own pipeline run via:

```bash
my_pbi_targets="$(jq -r --arg id "$PBI_ID" '.items[] | select(.id == $id) | .catalog_targets[]?' .scrum/backlog.json)"
```

## Layer 2: Runtime exclusion via flock (backstop)

Before writing to a catalog spec, acquire a flock on a per-spec lock
file. The pbi-designer agent does this; the conductor enforces by
inspecting designer's reported actions.

```bash
acquire_catalog_lock() {
  local spec_path="$1"
  local lock_id; lock_id="$(echo "$spec_path" | sed 's|/|_|g')"
  local lock_file=".scrum/locks/catalog-${lock_id}.lock"
  mkdir -p .scrum/locks
  exec {LOCK_FD}>"$lock_file"
  if ! flock -w 60 "$LOCK_FD"; then
    return 124  # timeout
  fi
  return 0
}
release_catalog_lock() {
  exec {LOCK_FD}>&-
}
```

Timeout (60s) → escalate with `escalation_reason: catalog_lock_timeout`.

## Layer 3: Conflict detection via mtime (last resort)

After releasing the lock, verify nothing else wrote in between:

```bash
verify_no_conflict() {
  local spec_path="$1" mtime_before="$2"
  local mtime_now
  mtime_now="$(stat -f %m "$spec_path" 2>/dev/null || stat -c %Y "$spec_path")"
  [ "$mtime_now" = "$mtime_before" ]
}
```

If conflict detected: discard the change, log event, retry once. On
second conflict: escalate `catalog_lock_timeout`.

## Stale lock cleanup

If a Developer dies mid-write, the flock auto-releases on process exit
(file descriptor closure). The lock file itself is left behind but is
harmless — flock attaches to FDs, not file existence. SM may sweep
`.scrum/locks/` periodically.
