#!/bin/bash
set -e
PROJECT=""
WORK_ITEM=""
PROMPT=""

FLAG=0
# Flag map:
# | DIAG | REVIEW | PUBLISH |

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
    "--publish")
      FLAG=$((FLAG + 2**0))
      ;;
    "--review")
      FLAG=$((FLAG + 2**1))
      ;;
    "--diag" | "-d")
      FLAG=$((FLAG + 2**2))
      ;;
    *)
      PROMPT="$*"
      break
      ;;
    esac
    shift
  done
}

show_usage() {
    echo "Usage: $0 -p <project> -w <workitem> [--review] [--publish] [--diag]] [<prompt>]
    -p, --project:               Project name
    -w, --workitem:              Azure DevOps work item number
    -d, --diag:                  Diagnostic mode: prints command without calling AI
    --review:                    Perform review of the work item
    --publish:                   Publish result as a comment"
}

write_stderr() {
  echo "$0: $*" 1>&2
  exit 1;
}

run_codex() {
  if [[ $((FLAG >> 2)) -eq 1 ]]; then
    echo "echo ${CONTEXT} | codex exec --skip-git-repo-check -o output.txt "$*""
  else
    echo ${CONTEXT} | codex exec --skip-git-repo-check -o output.txt "$*"
  fi;
}

if [[ -z $TFS_BASE_URL ]]; then
  write_stderr "The environment variable \"TFS_BASE_URL\" is not set. Example of the value: \"https://tfs.company.com/DefaultCollection\""
fi;
if [[ -z $TFS_PAT ]]; then
  write_stderr "The environment variable \"TFS_PAT\" is not set."
fi;

process_arguments "$@"

if [[ -z $PROJECT || -z $WORK_ITEM ]]; then
  show_usage;
  exit 1;
fi;

PROJECT_URL="${TFS_BASE_URL%/}/${PROJECT}"

CONTEXT="
Preface:
1. For this task you should use only Azure DevOps API and TFS_PAT environment variable for Basic authentication. Version control system is TFVC.
2. Target work item has ID \"${WORK_ITEM}\" and is located at \"${PROJECT_URL}\";
3. Before proceding to the task you must post a comment about work in progress;
4. Summary on any task completion must be posted as a comment in the target work item;
5. When you are required to post a comment to Azure DevOps or set work item's \"Description\" field:
  5.1. Translate it to russian language before posting;
  5.2. Format it to HTML;
  5.3. The last paragraph of a new comment should be in format: \"Session ID: {your current session ID}\";
6. If you are required to write code then you must post it as a part of the summary comment."

# These instructions are not needed right now, they are unstable also.
# When you are required to write a code:
#   1. The work item's \"State\" field must be set to \"${ACTIVE_STATE_NAME}\", and the comment about work in progress should be posted;
#   2. When your code is ready, a new changeset must be pushed with its description translated to russian language. The changeset must be bound to the work item;
#   3. The work item's \"State\" field must be set to \"${RESOLVED_STATE_NAME}\"

# Notes for Windows:
# 1. Using powershell command "Invoke-WebRequest" inside codex results in SEC_E_NO_CREDENTIALS error. That is a bug, see https://github.com/openai/codex/issues/17459. Workaround is to require an agent to use python for making any API requests.
# 2. Powershell pipeline output converts UTF8 characters to question marks. To solve this an agent should run "$OutputEncoding = [System.Text.Encoding]::UTF8" every time when crefting a new powershell command.
if [[ $OS = "Windows_NT" ]]; then
  CONTEXT=$CONTEXT";
Tool usage requirements:
  a. Every time crafting a powershell command you must place \"\$OutputEncoding = [System.Text.Encoding]::UTF8;\" line as its first line.
  b. Use only python for making any API requests. If python is not available then raise an error and stop processing."
fi;

if [[ $((FLAG >> 1)) -eq 1 ]]; then
  PROMPT="
The task is to review the target software development work item.

Steps:
1. Check if the work item has any changesets. If there are none, then post a comment stating this fact and consider your task complete. If there are changesets, then you should focus on fulfillment of the work item's description based on its changesets. 
2. The second priority is to review code in the work item's changesets.

If you have found any issues:
1. Move the work item to \"Active\" state and in \"Remaining Work\" field set a value in hours that you think is required to fix the issues.
2. Post a comment for the owner of work item with your objections;

If none of the issues have been found, then post the LGTM comment."
fi;

if [[ -z $PROMPT ]]; then
  write_stderr "Prompt is empty."
fi;

run_codex "$PROMPT"