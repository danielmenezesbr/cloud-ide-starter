#!/bin/bash
set -e

WORKSPACE_BASE="/workspace"

if [[ ! -z "${CODESPACES}" ]]; then
  WORKSPACE_BASE="/workspaces"
fi

ENV_VARS_FILE="$WORKSPACE_BASE/cloudIdeStarterEnvVars.sh"

if [[ ! -f "$ENV_VARS_FILE" ]]; then
  # Prompt for Secret with asterisks
  echo -n "Enter Secret: "
  secret=""
  stty -echo
  while IFS= read -r -n1 char; do
    if [[ $char == "" || $char == $'\n' ]]; then
      break
    fi
    echo -n "*"
    secret+="$char"
  done
  stty echo
  echo

  # Prompt for Payload with asterisks
  echo -n "Enter Payload: "
  payload=""
  stty -echo
  while IFS= read -r -n1 char; do
    if [[ $char == "" || $char == $'\n' ]]; then
      break
    fi
    echo -n "*"
    payload+="$char"
  done
  stty echo
  echo

  if [[ "${payload: -1}" != "=" ]]; then
    payload="${payload}="
  fi

  decoded_payload=$(echo -n "$payload" | base64 -d)

  decrypted_json=$(echo -n "$decoded_payload" | openssl enc -aes-256-cbc -d -a -pbkdf2 -pass pass:"$secret")

  # echo "Decrypted JSON:"
  # echo "$decrypted_json"

  # Check if the environment variables file exists
  if [[ ! -f "$ENV_VARS_FILE" ]]; then
    echo "Environment variables file not found. Creating $ENV_VARS_FILE."
    source ~/.bashrc
    echo "# Environment variables generated from decrypted JSON" > "$ENV_VARS_FILE"
    echo "$decrypted_json" | jq -r '.envvars | to_entries[] | "export \(.key)=\"\(.value)\""' >> "$ENV_VARS_FILE"
  fi

  for SHELL_RC in "$HOME/.bashrc" "$HOME/.zshrc" "$HOME/.config/fish/config.fish"; do
    if [[ -f "$SHELL_RC" ]] && ! grep -q "source $ENV_VARS_FILE" "$SHELL_RC"; then
      echo "source $ENV_VARS_FILE" >> "$SHELL_RC"
      echo "Added sourcing of $ENV_VARS_FILE to $SHELL_RC."
    fi
  done

  source ~/.bashrc
  source $ENV_VARS_FILE

  cd $WORKSPACE_BASE
  pwd
  git clone https://${GITHUB_USERNAME}:${GITHUB_TOKEN}@${CLOUD_IDE_STARTER_INITIAL_REPO#https://}
fi

cd $WORKSPACE_BASE
pwd
REPO_NAME=$(basename -s .git "$CLOUD_IDE_STARTER_INITIAL_REPO")
cd "$REPO_NAME"
$CLOUD_IDE_STARTER_INITAL_SCRIPT
