#!/usr/bin/env bash
# Flight Deck doctor: read-only install self-check.
#
# Inspects the local Claude Code config for a Flight Deck install and prints
# a PASS / MISS / OPTIONAL report, one line per item, with a one-line remedy
# after each miss. This script is read-only: it only inspects files and
# prints a report. It never creates, edits, deletes, or chmods anything, and
# it never writes to CLAUDE.md or settings.json.
#
# Required vs optional: the three skill folders and the CLAUDE.md activation
# block are required for a working install, so a miss there counts toward
# the failing exit code. The hooks, their settings.json registrations,
# curl, and the Concise output style are all documented as optional in the
# README and SKILL.md (the hooks are offered and asked about, never
# installed automatically), so a miss there is reported as OPTIONAL / not
# installed and never affects the exit code. jq is needed only to verify
# hook registrations and by the hooks themselves at runtime, so a missing
# jq is also optional for the exit code; the checks that depend on it are
# reported as skipped rather than failed.
#
# Usage: bash tools/doctor.sh

set -uo pipefail

CLAUDE_DIR="${HOME}/.claude"
SKILLS_DIR="${CLAUDE_DIR}/skills"
HOOKS_DIR="${CLAUDE_DIR}/hooks"
SETTINGS_FILE="${CLAUDE_DIR}/settings.json"
CLAUDE_MD="${CLAUDE_DIR}/CLAUDE.md"
OUTPUT_STYLES_DIR="${CLAUDE_DIR}/output-styles"

checks=0
required_issues=0
optional_missing=0
skipped=0

pass() {
  checks=$((checks + 1))
  printf 'PASS  %s\n' "$1"
}

# A required item is missing: this is a real problem and counts toward the
# failing exit code.
miss() {
  checks=$((checks + 1))
  required_issues=$((required_issues + 1))
  printf 'MISS  %s\n' "$1"
  printf '      remedy: %s\n' "$2"
}

# An optional item is not installed: informational only, never affects the
# exit code.
optional_miss() {
  checks=$((checks + 1))
  optional_missing=$((optional_missing + 1))
  printf 'OPTIONAL  %s: not installed\n' "$1"
  printf '      remedy: %s\n' "$2"
}

# An optional check could not run (jq missing): informational only, never
# affects the exit code.
skip_check() {
  checks=$((checks + 1))
  skipped=$((skipped + 1))
  printf 'OPTIONAL  %s: cannot verify without jq\n' "$1"
  printf '      remedy: %s\n' "$2"
}

echo "Flight Deck doctor: read-only install check"
echo "Config dir: ${CLAUDE_DIR}"
echo

# 1. Skill folders: mission-control, test-discipline, design-fidelity.
# Required. Each must resolve to a directory, whether a real folder or a
# symlink.
echo "-- Skills, required (~/.claude/skills/) --"
for skill in mission-control test-discipline design-fidelity; do
  path="${SKILLS_DIR}/${skill}"
  if [ -d "$path" ]; then
    if [ -L "$path" ]; then
      pass "skill folder: ${skill} (symlink)"
    else
      pass "skill folder: ${skill} (directory)"
    fi
  else
    miss "skill folder: ${skill}" "copy or symlink skills/${skill}/ from the flight-deck repo into ${path} (see README Install)"
  fi
done
echo

# 2. Flight Deck activation block in ~/.claude/CLAUDE.md.
# Required. Matches either the packaged heading or the mission-control
# default-mode line, so a hand-adapted activation block still passes.
echo "-- Activation, required (~/.claude/CLAUDE.md) --"
if [ -f "$CLAUDE_MD" ] && grep -Eiq 'flight deck defaults|mission[-[:space:]]control.*default' "$CLAUDE_MD"; then
  pass "CLAUDE.md: Flight Deck activation block found"
else
  miss "CLAUDE.md: Flight Deck activation block" "append the block from CLAUDE-md-activation.md in the flight-deck repo to ${CLAUDE_MD}"
fi
echo

# 3. Hook scripts present and executable.
# Optional. The README and SKILL.md document all three hooks as optional:
# offered and asked about during install, never copied on their own.
echo "-- Hooks, optional (~/.claude/hooks/) --"
for hook in fable5-fanout-guard.sh verify-reminder.sh flight-deck-update-check.sh; do
  path="${HOOKS_DIR}/${hook}"
  if [ -x "$path" ]; then
    if [ -L "$path" ]; then
      pass "hook script: ${hook} (symlink, executable)"
    else
      pass "hook script: ${hook} (executable)"
    fi
  else
    optional_miss "hook script: ${hook}" "copy hooks/${hook} into ${HOOKS_DIR}/ and chmod +x it, if you want this hook (see hooks/HOOKS.md)"
  fi
done
echo

# 3b. Hook registration in ~/.claude/settings.json.
# Optional, same as the hooks themselves. fable5-fanout-guard.sh and
# verify-reminder.sh belong under PreToolUse; flight-deck-update-check.sh
# belongs under SessionStart. jq is needed to read settings.json here; if
# jq is missing, these checks are reported as skipped, not failed.
echo "-- Hook registration, optional (~/.claude/settings.json) --"
if command -v jq >/dev/null 2>&1; then
  if [ -f "$SETTINGS_FILE" ]; then
    pretooluse_cmds="$(jq -r '.hooks.PreToolUse[]?.hooks[]?.command // empty' "$SETTINGS_FILE" 2>/dev/null)"
    sessionstart_cmds="$(jq -r '.hooks.SessionStart[]?.hooks[]?.command // empty' "$SETTINGS_FILE" 2>/dev/null)"

    for hook in fable5-fanout-guard.sh verify-reminder.sh; do
      if printf '%s\n' "$pretooluse_cmds" | grep -Fq -- "$hook"; then
        pass "settings.json: ${hook} registered under PreToolUse"
      else
        optional_miss "settings.json: ${hook} registered under PreToolUse" "register ${hook} under hooks.PreToolUse in ${SETTINGS_FILE}, if you want this hook (see hooks/HOOKS.md for the exact JSON)"
      fi
    done

    if printf '%s\n' "$sessionstart_cmds" | grep -Fq -- "flight-deck-update-check.sh"; then
      pass "settings.json: flight-deck-update-check.sh registered under SessionStart"
    else
      optional_miss "settings.json: flight-deck-update-check.sh registered under SessionStart" "register flight-deck-update-check.sh under hooks.SessionStart in ${SETTINGS_FILE}, if you want this hook (see hooks/HOOKS.md for the exact JSON)"
    fi
  else
    for hook in fable5-fanout-guard.sh verify-reminder.sh flight-deck-update-check.sh; do
      optional_miss "settings.json: ${hook} registration" "create ${SETTINGS_FILE} and register the hooks you want (see hooks/HOOKS.md)"
    done
  fi
else
  for hook in fable5-fanout-guard.sh verify-reminder.sh flight-deck-update-check.sh; do
    skip_check "settings.json: ${hook} registration" "install jq, then re-run this doctor check, if you want to verify hook registration"
  done
fi
echo

# 4. jq and curl on PATH.
# Optional. jq is needed only to verify the hook registrations above and by
# the hooks themselves at runtime; curl is needed only by
# flight-deck-update-check.sh. Neither is required by the skill folders or
# the CLAUDE.md activation block.
echo "-- Tooling, optional (needed only by the hooks) --"
if command -v jq >/dev/null 2>&1; then
  pass "jq on PATH ($(command -v jq))"
else
  optional_miss "jq on PATH" "install jq, e.g. 'brew install jq' on macOS, if you want the hooks to work; without it, this doctor also cannot verify hook registrations above"
fi

if command -v curl >/dev/null 2>&1; then
  pass "curl on PATH ($(command -v curl))"
else
  optional_miss "curl on PATH" "install curl, if you want flight-deck-update-check.sh to work"
fi
echo

# 5. mission-control VERSION file, readable.
# Required: this file ships inside the mission-control skill folder itself,
# so a miss here means that required folder was copied incompletely, not
# that an optional feature was declined.
echo "-- Version, required (part of the mission-control skill folder) --"
version_file="${SKILLS_DIR}/mission-control/VERSION"
if [ -r "$version_file" ]; then
  version="$(tr -d '[:space:]' < "$version_file" 2>/dev/null)"
  if [ -n "$version" ]; then
    pass "mission-control VERSION: ${version}"
  else
    miss "mission-control VERSION" "the VERSION file at ${version_file} is empty; reinstall or check the skill folder"
  fi
else
  miss "mission-control VERSION" "check that ${version_file} exists and is readable (part of the mission-control skill folder)"
fi
echo

# 6. Optional Concise output style.
echo "-- Output style, optional (~/.claude/output-styles/) --"
concise_file="${OUTPUT_STYLES_DIR}/concise.md"
if [ -f "$concise_file" ]; then
  pass "output style: concise.md present (stays off until you run /output-style Concise)"
else
  optional_miss "output style: concise.md" "copy output-styles/concise.md from the flight-deck repo into ${OUTPUT_STYLES_DIR}/, if you want it (stays off until /output-style Concise)"
fi
echo

echo "----------------------------------------"
if [ "$required_issues" -eq 0 ] && [ "$optional_missing" -eq 0 ] && [ "$skipped" -eq 0 ]; then
  echo "All good: ${checks}/${checks} checks passed."
  exit 0
fi

if [ "$required_issues" -eq 0 ]; then
  summary="All required items present."
  if [ "$optional_missing" -gt 0 ]; then
    summary="${summary} ${optional_missing} optional item(s) not installed (fine)."
  fi
  if [ "$skipped" -gt 0 ]; then
    summary="${summary} ${skipped} optional check(s) skipped, jq missing (fine)."
  fi
  echo "$summary"
  exit 0
fi

summary="${required_issues} required item(s) missing, out of ${checks} checks."
if [ "$optional_missing" -gt 0 ]; then
  summary="${summary} Also ${optional_missing} optional item(s) not installed."
fi
if [ "$skipped" -gt 0 ]; then
  summary="${summary} ${skipped} optional check(s) skipped (jq missing)."
fi
echo "$summary"
exit 1
