#!/usr/bin/env bash

set -euo pipefail

export AWS_PAGER=""
export AWS_CLI_AUTO_PROMPT=off
export MSYS_NO_PATHCONV=1
export PYTHONIOENCODING=utf-8

PROJECT="spa-qa-remoto"
PROFILE="spa-qa"
REGION="us-east-1"
POLL_SECONDS=5

usage() {
    echo "Usage: bash scripts/qa-remoto.sh <repo> <ref> <suite>"
    echo ""
    echo "Repositories:"
    echo "  spa-backend-api"
    echo "  spa-frontend-web"
    echo "  spa-database"
    echo ""
    echo "Suites:"
    echo "  unitarias | integracion | todo"
    exit 1
}

[[ $# -eq 3 ]] || usage

REPO="$1"
REF="$2"
SUITE="$3"

case "$REPO:$SUITE" in
    spa-backend-api:unitarias|\
    spa-backend-api:integracion|\
    spa-backend-api:todo|\
    spa-frontend-web:unitarias|\
    spa-frontend-web:todo|\
    spa-database:integracion|\
    spa-database:todo)
        ;;
    *)
        echo "ERROR: Unsupported repository or suite"
        usage
        ;;
esac

if [[ "$REF" =~ ^[0-9a-fA-F]{40}$ ]]; then
    :
elif [[ "$REF" =~ ^pull/[1-9][0-9]*/head$ ]]; then
    :
elif [[ "$REF" =~ ^[a-zA-Z0-9][a-zA-Z0-9._/-]*$ ]] &&
     git check-ref-format "refs/heads/$REF"; then
    :
else
    echo "ERROR: Invalid Git reference"
    exit 1
fi

command -v aws >/dev/null 2>&1 || {
    echo "ERROR: AWS CLI is required"
    exit 1
}

AWS_VERSION="$(aws --version 2>&1)"

if [[ "$AWS_VERSION" != aws-cli/2.* ]]; then
    echo "ERROR: AWS CLI v2 is required"
    exit 1
fi

if py -3.12 -c "import json" >/dev/null 2>&1; then
    PYTHON=(py -3.12)
elif python3 -c "import json" >/dev/null 2>&1; then
    PYTHON=(python3)
elif python -c "import json; import sys; assert sys.version_info.major == 3" >/dev/null 2>&1; then
    PYTHON=(python)
else
    echo "ERROR: Python 3 is required"
    exit 1
fi

aws_cmd() {
    aws --profile "$PROFILE" --region "$REGION" "$@"
}

echo "========================================"
echo "SPA UNAS - REMOTE QA"
echo "========================================"
echo "Project:    $PROJECT"
echo "Repository: $REPO"
echo "Reference:  $REF"
echo "Suite:      $SUITE"
echo "Region:     $REGION"
echo "Profile:    $PROFILE"
echo "========================================"

echo "Validating AWS session..."

aws_cmd sts get-caller-identity >/dev/null

echo "Starting CodeBuild execution..."

BUILD_ID="$(aws_cmd codebuild start-build \
    --project-name "$PROJECT" \
    --environment-variables-override \
        "name=REPO,value=$REPO,type=PLAINTEXT" \
        "name=REF,value=$REF,type=PLAINTEXT" \
        "name=SUITE,value=$SUITE,type=PLAINTEXT" \
    --query 'build.id' \
    --output text)"

if [[ -z "$BUILD_ID" || "$BUILD_ID" == "None" ]]; then
    echo "ERROR: CodeBuild did not return a build ID"
    exit 1
fi

echo "Build ID: $BUILD_ID"

cancel_build() {
    trap - INT TERM

    echo ""
    echo "Requesting build cancellation..."

    if aws_cmd codebuild stop-build \
        --id "$BUILD_ID" >/dev/null; then
        echo "Cancellation requested"
    else
        echo "WARNING: Cancellation could not be confirmed"
        echo "Build ID: $BUILD_ID"
    fi

    exit 130
}

trap cancel_build INT TERM

NEXT_TOKEN=""
LOG_GROUP=""
LOG_STREAM=""
LOG_WARNING=false

read_logs() {
    local response
    local new_token
    local page

    [[ -n "$LOG_GROUP" && -n "$LOG_STREAM" ]] || return 0

    for ((page=0; page<20; page++)); do

        local args=(
            logs get-log-events
            --log-group-name "$LOG_GROUP"
            --log-stream-name "$LOG_STREAM"
            --start-from-head
            --no-paginate
            --output json
        )

        if [[ -n "$NEXT_TOKEN" ]]; then
            args+=(--next-token "$NEXT_TOKEN")
        fi

        if ! response="$(aws_cmd "${args[@]}")"; then
            echo "WARNING: Unable to retrieve logs" >&2
            LOG_WARNING=true
            return 0
        fi

        new_token="$(
            printf '%s' "$response" |
            "${PYTHON[@]}" -c '
import json
import sys

data = json.load(sys.stdin)
print(data.get("nextForwardToken", ""))
'
        )"

        printf '%s' "$response" |
        "${PYTHON[@]}" -c '
import json
import sys

data = json.load(sys.stdin)

for event in data.get("events", []):
    message = event.get("message", "")
    sys.stdout.write(message)
    if not message.endswith("\n"):
        sys.stdout.write("\n")
'

        LOG_WARNING=false

        if [[ -z "$new_token" ||
              "$new_token" == "$NEXT_TOKEN" ]]; then
            break
        fi

        NEXT_TOKEN="$new_token"

    done
}

LAST_STATUS=""

while true; do

    if ! BUILD_INFO="$(aws_cmd codebuild batch-get-builds \
        --ids "$BUILD_ID" \
        --query 'builds[0].[buildStatus,logs.groupName,logs.streamName]' \
        --output text)"; then

        echo "ERROR: Unable to retrieve build status"
        echo "Build may still be running"
        echo "Build ID: $BUILD_ID"
        exit 1
    fi

    IFS=$'\t' read -r STATUS LOG_GROUP LOG_STREAM <<< "$BUILD_INFO"

    [[ "$LOG_GROUP" == "None" ]] && LOG_GROUP=""
    [[ "$LOG_STREAM" == "None" ]] && LOG_STREAM=""

    if [[ "$STATUS" != "$LAST_STATUS" ]]; then
        echo "Build status: $STATUS"
        LAST_STATUS="$STATUS"
    fi

    read_logs

    case "$STATUS" in

        SUCCEEDED|FAILED|FAULT|TIMED_OUT|STOPPED)

            for attempt in 1 2 3; do
                sleep 3
                read_logs
            done

            break
            ;;

        IN_PROGRESS)
            sleep "$POLL_SECONDS"
            ;;

        *)
            echo "ERROR: Unexpected build status: $STATUS"
            echo "Build ID: $BUILD_ID"
            exit 1
            ;;

    esac

done

trap - INT TERM

echo ""
echo "========================================"
echo "REMOTE QA RESULT: $STATUS"
echo "Build ID: $BUILD_ID"
echo "========================================"

if [[ "$LOG_WARNING" == "true" ||
      -z "$LOG_STREAM" ]]; then
    echo "WARNING: CloudWatch logs may be incomplete"
fi

if [[ "$STATUS" == "SUCCEEDED" ]]; then
    exit 0
fi

exit 1
