#!/bin/bash
set -e

WORKSPACE_BASE="/workspace"

if [[ ! -z "${CODESPACES}" ]]; then
  WORKSPACE_BASE="/workspaces"
fi

ENV_VARS_FILE="$WORKSPACE_BASE/cloudIdeStarterEnvVars.sh"

if [[ ! -f "$ENV_VARS_FILE" ]]; then
  # Prompt for Secret/Payload with asterisks (supports \n in input)
  echo "Enter Secret/Payload (format: secret.payload):"
  echo "(Press Ctrl+D when done, or Enter twice for single line input)"
  
  secret_payload=""
  stty -echo
  
  line_count=0
  last_line=""
  
  # Read all input, handling both real newlines and \n literals
  while IFS= read -r line || [[ -n "$line" ]]; do
    # Show asterisks for visual feedback
    if [[ $line_count -gt 0 ]]; then
      echo
    fi
    printf '%*s' "${#line}" '' | tr ' ' '*'
    
    # Check for double Enter (empty line after content)
    if [[ -z "$line" && -n "$last_line" ]]; then
      break
    fi
    
    if [[ -n "$secret_payload" ]]; then
      secret_payload+=$'\n'
    fi
    secret_payload+="$line"
    last_line="$line"
    line_count=$((line_count + 1))
  done
  
  stty echo
  echo
  echo

  # Remove all newlines, literal \n, and whitespace
  secret_payload=$(echo "$secret_payload" | tr -d '\n\r' | sed 's/\\n//g' | tr -d '[:space:]')

  # Split secret and payload by the first dot
  secret="${secret_payload%%.*}"
  payload="${secret_payload#*.}"

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
