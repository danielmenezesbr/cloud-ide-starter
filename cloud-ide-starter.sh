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

  while [[ -n "$payload" && "${payload: -1}" != "=" ]]; do
    echo "Payload does not end with '=' yet. Paste the continuation and press Enter (or type END to cancel):"
    IFS= read -r payload_more
    if [[ "$payload_more" == "END" ]]; then
      echo "ERROR: payload must end with '='."
      return 1 2>/dev/null || exit 1
    fi
    payload+=$(printf '%s' "$payload_more" | tr -d '\r\n[:space:]')
  done

  echo "Secret and payload received. Processing..."
  echo "Payload length: ${#payload}"

  # if [[ "${payload: -1}" != "=" ]]; then
  #   payload="${payload}="
  # fi

  #decoded_payload=$(echo -n "$payload" | base64 -d)

  # echo "Decoded payload (daniel): $decoded_payload"

  # Remove line breaks from pasted input.
  payload_clean=$(printf '%s' "$payload" | tr -d '\r\n')

  if ! printf '%s' "$payload_clean" | base64 -d > /tmp/first_decode.bin 2>/tmp/first_decode.err; then
    echo "Error in 1st base64 decode:"
    cat /tmp/first_decode.err
    return 1 2>/dev/null || exit 1
  fi

  if ! base64 -d < /tmp/first_decode.bin > /tmp/second_decode.bin 2>/tmp/second_decode.err; then
    echo "Error in 2nd base64 decode. Input is likely truncated/incomplete."
    cat /tmp/second_decode.err
    echo "Tip: provide the full value in /tmp/payload.txt."
    return 1 2>/dev/null || exit 1
  fi

  if ! openssl enc -aes-256-cbc -d -pbkdf2 -pass pass:"$secret" < /tmp/second_decode.bin > /tmp/decrypted.json 2>/tmp/openssl_decrypt.err; then
    echo "Error in OpenSSL decrypt:"
    cat /tmp/openssl_decrypt.err
    return 1 2>/dev/null || exit 1
  fi

  decrypted_json=$(cat /tmp/decrypted.json)

  #decrypted_json=$(printf %s "$payload" | base64 -d | base64 -d)

  # echo $decrypted_json
  # echo "done"
  # return 0 2>/dev/null || exit 0

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
