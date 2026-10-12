#!/bin/sh
# Tells ClaudeBuddy that an AI agent needs you. Installed to ~/.claude-buddy/notify.sh.
#
#   notify.sh <agent> <event> [json]   agent: claude | codex | any name
#                                      event: done | waiting | permission | dismiss
#   notify.sh codex '{"type":"agent-turn-complete",...}'   Codex legacy `notify = [...]`
#   notify.sh done|waiting|dismiss                         original form (= claude)
#
# Hook JSON is read from stdin when no json argument is given. Prints nothing.
dir="$HOME/.claude-buddy"

case "$1" in
  done|waiting|permission|dismiss) agent=claude; event=$1; payload=$2 ;;
  *) agent=${1:-agent}; event=$2; payload=$3 ;;
esac
case "$event" in
  "{"*) payload=$event; event=auto ;;   # JSON passed where the event goes (Codex notify)
esac
event=${event:-auto}

read_payload() {
  if [ -n "$payload" ]; then printf '%s' "$payload"
  elif [ ! -t 0 ]; then cat
  fi
}

# The GUI app this session runs in (Claude.app, Terminal.app, VS Code…): the topmost .app among our ancestors.
host_app() {
  pid=$PPID
  while [ -n "$pid" ] && [ "$pid" -gt 1 ]; do
    parent=$(ps -o ppid= -p "$pid" | tr -d ' ')
    if [ "$parent" = 1 ]; then
      comm=$(ps -o comm= -p "$pid")
      case "$comm" in *.app/*) echo "${comm%%.app/*}.app" ;; esac
      return
    fi
    pid=$parent
  done
}

if [ "$event" = "dismiss" ] && [ ! -f "$dir/active" ]; then
  read_payload >/dev/null   # nothing is waiting; skip the work
  exit 0
fi

mkdir -p "$dir/inbox"
f="$dir/inbox/$(date +%s)-$$"
{
  echo "$agent $event"
  if [ "$event" != "dismiss" ]; then
    host=$(host_app)
    [ -n "$host" ] && echo "@host $host"
  fi
  read_payload
} > "$f.tmp" && mv "$f.tmp" "$f.evt"

if [ "$event" != "dismiss" ]; then
  pgrep -xq ClaudeBuddy || open -g -b com.pooria.claudebuddy >/dev/null 2>&1
fi
exit 0
