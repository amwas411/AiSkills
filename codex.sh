#!/bin/bash
set -e
PROJECT=""
WORK_ITEM=""
MODE=0
MODE_REVIEW=1
REQUIRE_COMMENT=1
PROMPT=""

# Flag map:
# | REVIEW | PUBLISH |
FLAG=0

process_arguments() {
  echo $#
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
    "--review")
      FLAG=$(($FLAG + 2**1))
      ;;
    "--publish")
      FLAG=$(($FLAG + 2**0))
      ;;
    *)
      PROMPT="$1"
      ;;
    esac
    shift
  done
}

show_usage() {
    echo "Usage: $0 -p <project> -w <workitem>  [--review] [--publish] [<prompt>]
    -p (--project):               Project name
    -w (--workitem):              Azure DevOps work item number
    --review:                     Perform review of the work item
    --publish:                    Publish result as a comment"
}

run_codex() {
  echo "echo ${CONTEXT} | codex exec --skip-git-repo-check "$*""
}

if [[ -z $TFS_BASE_URL ]]; then
  echo "[ERROR]: The environment variable \"TFS_BASE_URL\" is not set. Example of the value: \"https://tfs.company.com/DefaultCollection\""
  exit 1;
fi;

process_arguments "$@"

if [[ -z $PROJECT || -z $WORK_ITEM ]]; then
  show_usage;
  exit 1;
fi;

PROJECT_URL="${TFS_BASE_URL%/}/${PROJECT}"
CONTEXT="
Preface:
1. For this task you should use only curl, Azure DevOps API and TFS_PAT environment variable for Basic authentication. 
2. When you are required to post a comment to Azure DevOps:
2.1. Translate it to russian language before posting;
2.2. Comment should be in HTML format;
2.3. The last paragraph of a new comment should be in a format: \"Session ID: {your session ID}\";
3. Target work item has ID ${WORK_ITEM} located at ${PROJECT_URL}."

if [[ $MODE = $MODE_REVIEW ]]; then
  PROMPT="
The task is to review the target software development work item.

Steps:
1. Check if the work item has any changesets. If there are none, then post a comment stating this fact and consider your task complete. If there are changesets, then you should focus on fulfillment of the work item's description based on its changesets. 
2. The second priority is to review code in the work item's changesets. See for possible bugs, security vulnerabilities, grammar.

If you have found any issues:
1. Post a comment for the owner of work item with your objections;
2. Move the work item to \"Active\" state and in \"Remaining Work\" field set a value in hours that you think is required to fix the issues.

If none of the issues have been found, then post the LGTM comment."
fi;

if [[ -z $PROMPT ]]; then
  echo [ERROR] Prompt is empty.
  exit 1;
fi;

run_codex $PROMPT