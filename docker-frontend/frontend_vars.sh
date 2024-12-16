#!/bin/bash

# Check if ENV_FILE is provided
if [ -z "$1" ]; then
  echo "Usage: $0 <env_file>"
  exit 1
fi

ENV_FILE=$1

# Read the .env file into a variable
if [ ! -f "$ENV_FILE" ]; then
  echo "File $ENV_FILE not found!"
  exit 1
fi

# Filter REACT_APP_ variables and update Dockerfile using sed
while IFS='=' read -r key value
do
  if [[ $key == REACT_APP_* ]]; then
    sed -i "s|${key}=.*|${key}=${value}|" Dockerfile
  fi
done < "$ENV_FILE"

echo "Dockerfile has been updated with frontend-specific environment variables."

