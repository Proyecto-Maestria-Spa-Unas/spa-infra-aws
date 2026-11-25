#!/usr/bin/env bash

set -euo pipefail
set +x

export AWS_PAGER=""
export AWS_CLI_AUTO_PROMPT=off
export MSYS_NO_PATHCONV=1

BASE_PROFILE="spa-qa-base"
SESSION_PROFILE="spa-qa"
REGION="us-east-1"
DURATION=43200

unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY
unset AWS_SESSION_TOKEN AWS_SECURITY_TOKEN
unset AWS_PROFILE AWS_DEFAULT_PROFILE

echo "========================================"
echo " SPA UNAS - Autenticacion MFA para QA"
echo "========================================"

if ! command -v aws >/dev/null 2>&1; then
    echo "ERROR: AWS CLI no esta instalado." >&2
    exit 1
fi

if ! aws --version 2>&1 | grep -q "aws-cli/2"; then
    echo "ERROR: Se requiere AWS CLI v2." >&2
    exit 1
fi

if ! aws configure list-profiles | grep -Fxq "$BASE_PROFILE"; then
    echo "ERROR: El perfil $BASE_PROFILE no existe." >&2
    echo "Ejecute: aws configure --profile $BASE_PROFILE"
    exit 1
fi

IDENTITY=$(aws sts get-caller-identity \
    --profile "$BASE_PROFILE" \
    --query Arn \
    --output text)

if [[ ! "$IDENTITY" =~ ^arn:aws:iam::[0-9]{12}:user/spa-qa-jhon$ ]]; then
    echo "ERROR: El perfil base no corresponde al usuario QA." >&2
    exit 1
fi

ACCOUNT_ID=$(cut -d: -f5 <<< "$IDENTITY")
MFA_ARN="arn:aws:iam::${ACCOUNT_ID}:mfa/spa-qa-jhon"

echo "Usuario: spa-qa-jhon"
echo "Perfil base: $BASE_PROFILE"
echo "Perfil temporal: $SESSION_PROFILE"
echo "Duracion solicitada: 12 horas"

read -r -s -p "Ingrese el codigo MFA de 6 digitos: " MFA_CODE
echo

if [[ ! "$MFA_CODE" =~ ^[0-9]{6}$ ]]; then
    unset MFA_CODE
    echo "ERROR: Codigo MFA invalido." >&2
    exit 1
fi

trap 'unset MFA_CODE SESSION_DATA ACCESS_KEY SECRET_KEY SESSION_TOKEN EXPIRATION' EXIT

if ! SESSION_DATA=$(aws sts get-session-token \
    --profile "$BASE_PROFILE" \
    --region "$REGION" \
    --serial-number "$MFA_ARN" \
    --token-code "$MFA_CODE" \
    --duration-seconds "$DURATION" \
    --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken,Expiration]' \
    --output text); then

    echo "ERROR: No fue posible obtener la sesion MFA." >&2
    exit 1
fi

unset MFA_CODE

IFS=$'\t' read -r ACCESS_KEY SECRET_KEY SESSION_TOKEN EXPIRATION <<< "$SESSION_DATA"

unset SESSION_DATA

if [[ -z "$ACCESS_KEY" || -z "$SECRET_KEY" || -z "$SESSION_TOKEN" || -z "$EXPIRATION" ]]; then
    echo "ERROR: Credenciales temporales incompletas." >&2
    exit 1
fi

aws configure set aws_access_key_id "$ACCESS_KEY" \
    --profile "$SESSION_PROFILE"

aws configure set aws_secret_access_key "$SECRET_KEY" \
    --profile "$SESSION_PROFILE"

aws configure set aws_session_token "$SESSION_TOKEN" \
    --profile "$SESSION_PROFILE"

aws configure set region "$REGION" \
    --profile "$SESSION_PROFILE"

aws configure set output json \
    --profile "$SESSION_PROFILE"

unset ACCESS_KEY SECRET_KEY SESSION_TOKEN

echo "Validando identidad de la sesion temporal..."

aws sts get-caller-identity \
    --profile "$SESSION_PROFILE" \
    --query Arn \
    --output text

echo "========================================"
echo " SESION MFA CONFIGURADA"
echo " Perfil: $SESSION_PROFILE"
echo " Expiracion UTC: $EXPIRATION"
echo "========================================"

echo "Para renovar la sesion:"
echo "bash scripts/qa-mfa.sh"
