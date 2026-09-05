#!/bin/bash
set -e

RESUME=0
SESSION_ID=""
PROMPT=""

process_arguments() {
  while [[ "$#" -gt "0" ]]; do
    case "$1" in
    "--resume" | "-r")
      RESUME=1
      ;;
    "--session" | "-s")
      if [[ -z "$2" ]]; then
        echo "Session id is empty" >$2
        exit 1
      fi
      SESSION_ID="$2"
      shift
      ;;
    *)
      echo "$*"
      PROMPT="$*"
      break
      ;;
    esac
    shift
  done
}
write_stderr() {
  echo "$0: $*" 1>&2
  exit 1
}
process_arguments "$@"

if [[ -z $PROMPT ]]; then
	write_stderr "Prompt is not set."
fi;

if [[ $RESUME = 1 && -z $SESSION_ID ]]; then
  echo "resume last"
	codex exec resume --skip-git-repo-check --last "${PROMPT}";
elif [[ ! -z $SESSION_ID ]]; then
	echo "resume ${SESSION_ID}"
  codex exec resume --skip-git-repo-check "${SESSION_ID}" "${PROMPT}";
else
  echo "new session"
	codex exec \
		--skip-git-repo-check \
		"${PROMPT}";
fi;