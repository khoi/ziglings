#!/usr/bin/env bash
set -euo pipefail

usage() {
    cat <<'EOF'
watch-exercise.sh [exercises_dir]

Observes Zig exercise files with watchexec and re-runs `zig build -Dn=<exercise>`
for the exercise that changed.
EOF
    exit 1
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
    usage
fi

run_event() {
    local path=""
    local vars=(
        WATCHEXEC_WRITTEN_PATH
        WATCHEXEC_CREATED_PATH
        WATCHEXEC_RENAMED_PATH
        WATCHEXEC_REMOVED_PATH
        WATCHEXEC_META_CHANGED_PATH
    )

    for var in "${vars[@]}"; do
        local value="${!var:-}"
        if [[ -n "$value" ]]; then
            path="$value"
            break
        fi
    done

    if [[ -z "$path" && -n "${WATCHEXEC_EVENTS_FILE:-}" && -f "$WATCHEXEC_EVENTS_FILE" ]]; then
        path="$(head -n1 "$WATCHEXEC_EVENTS_FILE")"
    fi

    if [[ -z "$path" ]]; then
        path="${WATCHEXEC_COMMON_PATH:-}"
    fi

    if [[ -z "$path" ]]; then
        exit 0
    fi

    local base="${path##*/}"
    if [[ ! "$base" =~ ^([0-9]+)_.*\.zig$ ]]; then
        echo "watchexec: ignoring $path" >&2
        exit 0
    fi

    local number=$((10#${BASH_REMATCH[1]}))
    echo "[$(date +"%H:%M:%S")] $path -> zig build -Dn=$number"
    exec zig build -Dn="$number"
}

if [[ "${1:-}" == "--event" ]]; then
    run_event
fi

watch_dir="${1:-exercises}"

if ! command -v watchexec >/dev/null; then
    echo "watchexec is required but was not found in PATH." >&2
    exit 127
fi

exec watchexec \
    --watch "$watch_dir" \
    --exts zig \
    --emit-events-to environment \
    --restart \
    -- ./tools/watch-exercise.sh --event
