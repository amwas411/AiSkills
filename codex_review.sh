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
    *)
      show_usage
      exit 1
      ;;
    esac
    shift
  done
}

show_usage() {
  echo "Usage: $0 -p <project> -w <workitem>
  Reviews work item.
  -p (--project):               Project name
  -w (--workitem):               Azure DevOps work item number."
}

if [[ -z $TFS_BASE_URL ]]; then
  echo "[ERROR]: The environment variable \"TFS_BASE_URL\" is not set. Example of the value: \"https://tfs.company.com/DefaultCollection\""
  exit 1;
fi;

process_arguments $@

if [[ -z $PROJECT || -z $WORK_ITEM ]]; then
  show_usage;
  exit 1;
fi;

PROJECT_URL="${TFS_BASE_URL%/}/${PROJECT}"
PROMPT="
Preface:
1. For this task you shall use only curl, Azure DevOps API and TFS_PAT environment variable for Basic authentication. 
2. When you are required to post a comment, the last line of it shall be your current session ID.

Task:
The task is to review a software development work item \"${WORK_ITEM}\" at \"${PROJECT_URL}\".

1. You need to check if the work item has any changesets. If there are none, then post a comment on russian language stating this fact. If there are changesets, then you should focus on fulfillment of the work item's description based on its changesets. 
2. The second priority is to review code in the work item's changesets: see for possible bugs, security vulnerabilities, grammar.

If you have found any issues:
1. Post a comment on russian languge for the owner of work item with your objections;
2. Move the work item to \"Active\" state and in \"Remaining Work\" field set a value in hours that you think is required to fix the issues.

If none of the issues have been found, then post a LGTM comment on russian language."

codex exec \
  --skip-git-repo-check \
  "${PROMPT}";
