#!/bin/bash
set -e

WORKSPACE_BASE="/workspace"

if [[ ! -z "${CODESPACES}" ]]; then
  WORKSPACE_BASE="/workspaces"
fi

ENV_VARS_FILE="$WORKSPACE_BASE/cloudIdeStarterEnvVars.sh"

if [[ ! -f "$ENV_VARS_FILE" ]]; then
  while [[ ! -f "/tmp/payload.txt" ]]; do
    echo "File /tmp/payload.txt not found."
    echo "Create /tmp/payload.txt with content in format: secret.payload"
    echo "When ready, press Enter to continue..."
    IFS= read -r
  done

  while [[ ! -s "/tmp/payload.txt" ]]; do
    echo "File /tmp/payload.txt exists, but it is empty."
    echo "Fill the file and press Enter to continue..."
    IFS= read -r
  done

  echo "Reading secret/payload from /tmp/payload.txt..."
  secret_payload=$(tr -d '\r\n[:space:]' < /tmp/payload.txt)

  # Split secret and payload by the first dot
  if [[ "$secret_payload" != *"."* ]]; then
    echo "ERROR: Input does not contain a dot separator. Expected format: secret.payload"
    return 1 2>/dev/null || exit 1
  fi

  secret="${secret_payload%%.*}"
  payload="${secret_payload#*.}"

  # while [[ -n "$payload" && "${payload: -1}" != "=" ]]; do
  #   echo "Payload does not end with '=' yet. Paste the continuation and press Enter (or type END to cancel):"
  #   IFS= read -r payload_more
  #   if [[ "$payload_more" == "END" ]]; then
  #     echo "ERROR: payload must end with '='."
  #     return 1 2>/dev/null || exit 1
  #   fi
  #   payload+=$(printf '%s' "$payload_more" | tr -d '\r\n[:space:]')
  # done

  echo "Secret and payload received. Processing..."
  echo "Payload length: ${#payload}"

  # Remove line breaks from pasted input.
  #payload_clean=$(printf '%s' "$payload" | tr -d '\r\n')
  payload_clean=$payload

  # Decrypt: base64 -d (outer layer) | openssl -d -a (inner base64 layer + AES decrypt)
  # This mirrors the encrypt: openssl -a (AES encrypt + base64) | base64 (outer layer)
  if ! printf '%s' "$payload_clean" | base64 -d | base64 -d | openssl enc -aes-256-cbc -d -pbkdf2 -pass pass:"$secret" > /tmp/decrypted.json 2>/tmp/openssl_decrypt.err; then
    echo "Error decrypting payload:"
    cat /tmp/openssl_decrypt.err
    echo "Tip: ensure the full value is present in /tmp/payload.txt."
    return 1 2>/dev/null || exit 1
  fi

  decrypted_json=$(cat /tmp/decrypted.json)

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
