#!/bin/bash
set -e

echo -n "Enter Secret: "
read -s secret
echo

echo -n "Enter Payload: "
read payload

decoded_payload=$(echo -n "$payload" | base64 -d)


decrypted_json=$(echo -n "$decoded_payload" | openssl enc -aes-256-cbc -d -a -pbkdf2 -pass pass:"$secret")

# echo "Decrypted JSON:"
# echo "$decrypted_json"

WORKSPACE_BASE="/workspace"
ENV_VARS_FILE="$WORKSPACE_BASE/cloudIdeStarterEnvVars.sh"

# Check if the environment variables file exists
if [[ ! -f "$ENV_VARS_FILE" ]]; then
  echo "Environment variables file not found. Creating $ENV_VARS_FILE."
  source ~/.bashrc
  echo "# Environment variables generated from decrypted JSON" > "$ENV_VARS_FILE"
  echo "$decrypted_json" | jq -r '.envvars | to_entries[] | "export \(.key)=\(.value)"' >> "$ENV_VARS_FILE"
fi

if ! grep -q "source $ENV_VARS_FILE" "$HOME/.bashrc"; then
  echo "source $ENV_VARS_FILE" >> "$HOME/.bashrc"
  echo "Added sourcing of $ENV_VARS_FILE to $HOME/.bashrc."
fi

source ~/.bashrc
source $ENV_VARS_FILE

cd $WORKSPACE_BASE
git clone $CLOUD_IDE_STARTER_INITIAL_REPO
REPO_NAME=$(basename -s .git "$CLOUD_IDE_STARTER_INITIAL_REPO")
cd "$REPO_NAME"
pwd