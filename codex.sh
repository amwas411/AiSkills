#!/bin/bash
set -e
PROJECT=""
WORK_ITEM=""
PROMPT=""
SESSION_ID=""

FLAG=0
# Flag map:
# | DIAG | REVIEW |

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
    "--session" | "-s")
      if [[ -z "$2" ]]; then
        show_usage
        exit 1
      fi
      SESSION_ID="$2"
      shift
      ;;
    "--review")
      FLAG=$((FLAG + 2**0))
      ;;
    "--diag" | "-d")
      FLAG=$((FLAG + 2**1))
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
    echo "Usage: $0 -p <project> -w <workitem> [--diag] [--session <session_id>] [--review] [<prompt>]
    -p, --project:               Project name
    -w, --workitem:              Azure DevOps work item number
    -d, --diag:                  Diagnostic mode: prints command without calling AI
    -s, --session:               Resume session
    --cd:                        Set working directory
    --review:                    Perform review of the work item"
}

write_stderr() {
  echo "$0: $*" 1>&2
  exit 1;
}

run_codex() {
  if [[ $((FLAG >> 1)) -eq 1 ]]; then
    if [[ ! -z $SESSION_ID ]]; then 
      echo "codex exec resume ${SESSION_ID} 
        -c sandbox_mode=workspace-write 
        -c sandbox_workspace_write.network_access=true
        --skip-git-repo-check
         "$*"";
    else
      echo "echo ${CONTEXT} | codex exec
        -c sandbox_mode=workspace-write 
        -c sandbox_workspace_write.network_access=true
        --skip-git-repo-check
        "$*"";
    fi;
  else
    if [[ ! -z $SESSION_ID ]]; then 
      codex exec resume \
          -c sandbox_mode=workspace-write \
          -c sandbox_workspace_write.network_access=true \
          --skip-git-repo-check "${SESSION_ID}" "$*";
    else
      echo ${CONTEXT} | codex exec \
        -c sandbox_mode=workspace-write \
        -c sandbox_workspace_write.network_access=true \
        --skip-git-repo-check "$*";
    fi;
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
3. There two types of Azure DevOps comments that must be posted in the target work item:
  3.1. Before proceding to the task you must post a comment about work in progress in the target Azure DevOps work item. The term for this type of comment is \"Starting comment\";
  3.2. Your last message must be post as a comment in the target Azure DevOps work item. The term for this type of comment is \"Result comment\";
4. When you are posting a comment to Azure DevOps or setting work item's \"Description\" field you must follow the rules:
  4.1. Translate a comment to russian language before posting;
  4.2. Format it to HTML;
  4.3. The last paragraph of a comment should be in format: \"Session ID: {your current session ID}\""

# Notes for Windows:
# 1. Using powershell command "Invoke-WebRequest" inside codex results in SEC_E_NO_CREDENTIALS error. That is a bug, see https://github.com/openai/codex/issues/17459. Workaround is to require an agent to use python for making any API requests.
# 2. Powershell pipeline output converts UTF8 characters to question marks. To solve this an agent should run "$OutputEncoding = [System.Text.Encoding]::UTF8" every time when crefting a new powershell command.
if [[ $OS = "Windows_NT" ]]; then
  CONTEXT=$CONTEXT";
Tool usage requirements:
  1. Every time crafting a powershell command you must place \"\$OutputEncoding = [System.Text.Encoding]::UTF8;\" line as its first line.
  2. Use only python for making any API requests. If python is not available then stop processing."
fi;

if [[ $((FLAG % 2)) -eq 1 ]]; then
  PROMPT="
The task is to review the target software development work item.

Steps:
1. Check if the work item has any changesets. If there are none, then consider your task complete. If there are changesets, then you should focus on fulfillment of the work item's description based on its changesets.
2. Review code in the work item's changesets.

If you have found any issues, post a result comment for the owner of work item with your objections;

If changesets exist and none of the issues have been found, then post the LGTM result comment and consider your task complete."

fi;

if [[ -z $PROMPT ]]; then
  write_stderr "Prompt is empty."
fi;

run_codex "$PROMPT"