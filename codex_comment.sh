#!/bin/bash
set -e
PROJECT=""
WORK_ITEM=""

process_arguments() {
  while [[ "$#" -gt "0" ]]; do
    case "$1" in
    "--project" | "-p")
      if [[ -z "$2" ]]; then
        show_usage
        exit 1
      fi
      PROJECT="$2"
      shift
      ;;
    "--workitem" | "-w")
      if [[ -z "$2" ]]; then
        show_usage
        exit 1
      fi
      WORK_ITEM="$2"
      shift
      ;;
    esac
    shift
  done
}

show_usage() {
  echo "Usage: $0 -p <project> -w <workitem> <prompt>
  -p (--project):               Project name
  -w (--workitem):               Azure DevOps work item number."
}

if [[ -z $TFS_BASE_URL ]]; then
  echo "[ERROR]: The environment variable \"TFS_BASE_URL\" is not set. Example of the value: \"https://tfs.company.com/DefaultCollection\""
  exit 1;
fi;

process_arguments $@
PROMPT=${!#}

if [[ -z $PROJECT || -z $WORK_ITEM || $PROMPT = $WORK_ITEM || $PROMPT = $PROJECT ]]; then
  show_usage;
  exit 1;
fi;

PROJECT_URL="${TFS_BASE_URL%/}/${PROJECT}"
CONTEXT="
Preface:
1. For this task you shall use only curl, Azure DevOps API and TFS_PAT environment variable for Basic authentication. 
2. When you are required to post a comment:
2.1. Translate it to russian language before posting;
2.2. Comment should be in HTML format;
2.3. The last line of a comment should be your current session ID;
3. Project URL is ${PROJECT_URL}, Work item ID is ${WORK_ITEM}.
"

echo ${CONTEXT} | codex exec \
  --skip-git-repo-check \
  "${PROMPT}"
