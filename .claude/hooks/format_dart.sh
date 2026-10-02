#!/usr/bin/env bash
# PostToolUse: format the edited file if it is Dart. Reads hook JSON from stdin.
# No jq on Windows Git Bash, so pull file_path out with grep/sed (JSON "\\" -> /).
f=$(grep -o '"file_path": *"[^"]*"' | head -1 | sed 's/^"file_path": *"//; s/"$//; s#\\\\#/#g')
case "$f" in
  *.dart) dart format "$f" >/dev/null 2>&1 ;;
esac
exit 0
