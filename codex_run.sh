#!/bin/bash
set -ex
PROMPT=$1
RESUME=$2
SESSION_ID=$3
if [[ -z $PROMPT ]]; then
	exit 0
fi;
if [[ $RESUME = "-r" && ! -z $SESSION_ID ]]; then
	codex exec resume \
		--skip-git-repo-check \
		"$SESSION_ID" \
		"${PROMPT}";
else
	codex exec \
		--skip-git-repo-check \
		"${PROMPT}";
fi;

