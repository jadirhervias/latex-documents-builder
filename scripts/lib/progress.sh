#!/bin/sh

# Compact progress reporting for long-running build commands. Detailed command
# output remains in the log passed to progress_run and is shown only on error.

PROGRESS_INTERVAL=${PROGRESS_INTERVAL:-15}
case $PROGRESS_INTERVAL in
  ''|*[!0-9]*) PROGRESS_INTERVAL=15 ;;
  0) PROGRESS_INTERVAL=1 ;;
esac

progress_elapsed() {
  now=$(date +%s)
  printf '%s' "$((now - PROGRESS_STARTED))"
}

progress_init() {
  PROGRESS_NAME=$1
  PROGRESS_STARTED=$(date +%s)
  printf '[%s] Build started.\n' "$PROGRESS_NAME"
}

progress_skip() {
  current=$1
  total=$2
  message=$3
  printf '[%s %s/%s +%ss] %s\n' \
    "$PROGRESS_NAME" "$current" "$total" "$(progress_elapsed)" "$message"
}

progress_run() {
  current=$1
  total=$2
  label=$3
  log_file=$4
  shift 4

  printf '[%s %s/%s +%ss] %s...\n' \
    "$PROGRESS_NAME" "$current" "$total" "$(progress_elapsed)" "$label"

  "$@" >"$log_file" 2>&1 &
  command_pid=$!
  heartbeat_elapsed=0

  while kill -0 "$command_pid" 2>/dev/null; do
    sleep 1
    heartbeat_elapsed=$((heartbeat_elapsed + 1))
    if [ "$heartbeat_elapsed" -ge "$PROGRESS_INTERVAL" ] && \
       kill -0 "$command_pid" 2>/dev/null; then
      printf '[%s %s/%s +%ss] %s: still running.\n' \
        "$PROGRESS_NAME" "$current" "$total" "$(progress_elapsed)" "$label"
      heartbeat_elapsed=0
    fi
  done

  if wait "$command_pid"; then
    printf '[%s %s/%s +%ss] %s: complete.\n' \
      "$PROGRESS_NAME" "$current" "$total" "$(progress_elapsed)" "$label"
    return 0
  else
    status=$?
    printf '[%s %s/%s +%ss] ERROR in %s. Last lines of %s:\n' \
      "$PROGRESS_NAME" "$current" "$total" "$(progress_elapsed)" "$label" "$log_file" >&2
    tail -n 30 "$log_file" >&2 || true
    return "$status"
  fi
}

progress_finish() {
  output=$1
  printf '[%s +%ss] Build complete: %s\n' \
    "$PROGRESS_NAME" "$(progress_elapsed)" "$output"
}
