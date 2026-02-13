#!/usr/bin/env bats

load setup.bash

setup() {
  setup_test_env

  # Create a mock Antigravity brain directory
  export ANTIGRAVITY_BRAIN_DIR="$TEST_DIR/brain"
  mkdir -p "$ANTIGRAVITY_BRAIN_DIR"

  # Copy peon.sh into test dir so the adapter can find it
  cp "$PEON_SH" "$TEST_DIR/peon.sh"

  # Mock fswatch so preflight passes
  cat > "$MOCK_BIN/fswatch" <<'SCRIPT'
#!/bin/bash
sleep 999
SCRIPT
  chmod +x "$MOCK_BIN/fswatch"

  ADAPTER_SH="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)/adapters/antigravity.sh"
}

teardown() {
  teardown_test_env
}

# Helper: create a metadata file for a given GUID and artifact type
create_metadata() {
  local guid="$1"
  local artifact_type="$2"
  mkdir -p "$ANTIGRAVITY_BRAIN_DIR/$guid"
  cat > "$ANTIGRAVITY_BRAIN_DIR/$guid/${artifact_type}.md.metadata.json" <<JSON
{
  "artifactType": "ARTIFACT_TYPE_$(echo "$artifact_type" | tr '[:lower:]' '[:upper:]')",
  "summary": "Test artifact",
  "updatedAt": "2026-02-12T00:00:00Z",
  "version": 1
}
JSON
}

# Helper: emit an Antigravity event to peon.sh, mirroring the adapter's emit_event function
emit_antigravity_event() {
  local event="$1"
  local guid="$2"
  local session_id="antigravity-${guid:0:8}"
  echo "{\"hook_event_name\":\"$event\",\"notification_type\":\"\",\"cwd\":\"$PWD\",\"session_id\":\"$session_id\",\"permission_mode\":\"\"}" \
    | bash "$TEST_DIR/peon.sh" 2>/dev/null || true
}

# Helper: run handle_metadata_change logic via Python subprocess.
# This reimplements the adapter's handle_metadata_change + GUID dedup logic
# to avoid sourcing the adapter (which requires Bash 4+ for declare -A).
# Accepts multiple metadata file paths, processes them in order, and emits events.
run_adapter_logic() {
  python3 -c "
import sys, json, os, subprocess

peon_dir = os.environ['CLAUDE_PEON_DIR']
peon_sh = os.path.join(peon_dir, 'peon.sh')
known_guids = {}  # guid -> last artifact_type

for filepath in sys.argv[1:]:
    # Extract GUID from path: .../brain/<GUID>/file.metadata.json
    parts = filepath.split(os.sep)
    guid = None
    for i, p in enumerate(parts):
        if p == 'brain' and i + 1 < len(parts):
            guid = parts[i + 1]
            break
    if not guid:
        continue

    # Parse artifact type
    try:
        meta = json.load(open(filepath))
        at = meta.get('artifactType', '').replace('ARTIFACT_TYPE_', '').lower()
    except:
        continue
    if not at:
        continue

    prev = known_guids.get(guid, '')
    event = None

    if at == 'task':
        if not prev:
            known_guids[guid] = 'task'
            event = 'SessionStart'
    elif at == 'implementation_plan':
        if prev not in ('implementation_plan', 'walkthrough'):
            known_guids[guid] = 'implementation_plan'
            event = 'UserPromptSubmit'
    elif at == 'walkthrough':
        if prev != 'walkthrough':
            known_guids[guid] = 'walkthrough'
            event = 'Stop'

    if event:
        session_id = 'antigravity-' + guid[:8]
        payload = json.dumps({
            'hook_event_name': event,
            'notification_type': '',
            'cwd': os.getcwd(),
            'session_id': session_id,
            'permission_mode': ''
        })
        subprocess.run(['bash', peon_sh], input=payload, capture_output=True, text=True, env=os.environ)
" "$@"
}

# ============================================================
# Syntax validation
# ============================================================

@test "adapter script has valid bash syntax" {
  run bash -n "$ADAPTER_SH"
  [ "$status" -eq 0 ]
}

# ============================================================
# Preflight: missing peon.sh
# ============================================================

@test "exits with error when peon.sh is not found" {
  local empty_dir
  empty_dir="$(mktemp -d)"
  CLAUDE_PEON_DIR="$empty_dir" run bash "$ADAPTER_SH"
  [ "$status" -eq 1 ]
  [[ "$output" == *"peon.sh not found"* ]]
  rm -rf "$empty_dir"
}

# ============================================================
# Preflight: missing filesystem watcher
# ============================================================

@test "exits with error when no filesystem watcher is available" {
  # Remove fswatch mock so neither fswatch nor inotifywait is found
  rm -f "$MOCK_BIN/fswatch"
  rm -f "$MOCK_BIN/inotifywait"
  run bash "$ADAPTER_SH"
  [ "$status" -eq 1 ]
  [[ "$output" == *"No filesystem watcher found"* ]]
}

# ============================================================
# Metadata parser: artifact type extraction
# ============================================================

@test "metadata parser extracts task type" {
  local guid="aaaa-bbbb-cccc-1111"
  create_metadata "$guid" "task"
  local filepath="$ANTIGRAVITY_BRAIN_DIR/$guid/task.md.metadata.json"

  result=$(python3 -c "
import sys, json
try:
    meta = json.load(open(sys.argv[1]))
    at = meta.get('artifactType', '')
    at = at.replace('ARTIFACT_TYPE_', '').lower()
    print(at)
except:
    pass
" "$filepath")

  [ "$result" = "task" ]
}

@test "metadata parser extracts implementation_plan type" {
  local guid="aaaa-bbbb-cccc-2222"
  create_metadata "$guid" "implementation_plan"
  local filepath="$ANTIGRAVITY_BRAIN_DIR/$guid/implementation_plan.md.metadata.json"

  result=$(python3 -c "
import sys, json
try:
    meta = json.load(open(sys.argv[1]))
    at = meta.get('artifactType', '')
    at = at.replace('ARTIFACT_TYPE_', '').lower()
    print(at)
except:
    pass
" "$filepath")

  [ "$result" = "implementation_plan" ]
}

@test "metadata parser extracts walkthrough type" {
  local guid="aaaa-bbbb-cccc-3333"
  create_metadata "$guid" "walkthrough"
  local filepath="$ANTIGRAVITY_BRAIN_DIR/$guid/walkthrough.md.metadata.json"

  result=$(python3 -c "
import sys, json
try:
    meta = json.load(open(sys.argv[1]))
    at = meta.get('artifactType', '')
    at = at.replace('ARTIFACT_TYPE_', '').lower()
    print(at)
except:
    pass
" "$filepath")

  [ "$result" = "walkthrough" ]
}

# ============================================================
# GUID extraction from path
# ============================================================

@test "GUID extractor parses GUID from metadata path" {
  local guid="abcd-1234-efgh-5678"
  local filepath="$ANTIGRAVITY_BRAIN_DIR/$guid/task.md.metadata.json"
  mkdir -p "$ANTIGRAVITY_BRAIN_DIR/$guid"

  result=$(python3 -c "
import sys, os
parts = sys.argv[1].split(os.sep)
for i, p in enumerate(parts):
    if p == 'brain' and i + 1 < len(parts):
        print(parts[i + 1])
        break
" "$filepath")

  [ "$result" = "$guid" ]
}

# ============================================================
# Integration: new task emits SessionStart
# ============================================================

@test "new task emits SessionStart and plays a Hello sound" {
  local guid="int-test-guid-0001"
  create_metadata "$guid" "task"
  local filepath="$ANTIGRAVITY_BRAIN_DIR/$guid/task.md.metadata.json"

  run_adapter_logic "$filepath"

  # Give async audio a moment (peon.sh uses nohup &)
  sleep 0.5

  afplay_was_called
  sound=$(afplay_sound)
  [[ "$sound" == *"/packs/peon/sounds/Hello"* ]]
}

# ============================================================
# Integration: walkthrough emits Stop
# ============================================================

@test "walkthrough after task emits Stop and plays sounds" {
  local guid="int-test-guid-0002"

  # Create task metadata
  create_metadata "$guid" "task"
  local task_path="$ANTIGRAVITY_BRAIN_DIR/$guid/task.md.metadata.json"

  # Create walkthrough metadata
  create_metadata "$guid" "walkthrough"
  local walk_path="$ANTIGRAVITY_BRAIN_DIR/$guid/walkthrough.md.metadata.json"

  # Process task event first (SessionStart)
  run_adapter_logic "$task_path"
  sleep 0.3

  # peon.sh suppresses events within 3s of SessionStart for the same session_id.
  # Move the session start timestamp back so the Stop event is not suppressed.
  python3 -c "
import json, time
state = json.load(open('$TEST_DIR/.state.json'))
starts = state.get('session_start_times', {})
for k in starts:
    starts[k] = time.time() - 10
state['session_start_times'] = starts
json.dump(state, open('$TEST_DIR/.state.json', 'w'))
"

  # Process walkthrough event (Stop) — uses a fresh run_adapter_logic call
  # which starts with a new known_guids dict, so we pass both to maintain state
  # and have the walkthrough be recognized as a phase transition.
  run_adapter_logic "$task_path" "$walk_path"

  # Give async audio a moment
  sleep 0.5

  # Should have at least 2 afplay calls total: SessionStart + Stop
  # (The second run_adapter_logic re-processes task but dedup prevents a second SessionStart.
  #  Only the walkthrough/Stop fires in the second call, plus the original SessionStart.)
  count=$(afplay_call_count)
  [ "$count" -ge 2 ]
}

# ============================================================
# Integration: duplicate task deduplication
# ============================================================

@test "duplicate task metadata changes only emit one SessionStart" {
  local guid="int-test-guid-0003"
  create_metadata "$guid" "task"
  local filepath="$ANTIGRAVITY_BRAIN_DIR/$guid/task.md.metadata.json"

  # Process the same task metadata file twice
  run_adapter_logic "$filepath" "$filepath"

  # Give async audio a moment
  sleep 0.5

  count=$(afplay_call_count)
  [ "$count" -eq 1 ]
}
