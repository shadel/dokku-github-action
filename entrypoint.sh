#!/bin/sh
set -e

echo "Setting up SSH directory"
SSH_PATH="$HOME/.ssh"
mkdir -p "$SSH_PATH"
chmod 700 "$SSH_PATH"

echo "Saving SSH key"
echo "$PRIVATE_KEY" > "$SSH_PATH/deploy_key"
chmod 600 "$SSH_PATH/deploy_key"

GIT_COMMAND="git push dokku@$HOST:$PROJECT"

echo "Detect the project default branch: master or main"
DEFAULT_BRANCH="$(git config --global --add safe.directory /github/workspace)"
DEFAULT_BRANCH="$(git remote show origin | awk '/HEAD branch/ {print $NF}')"

if [ -z "$DEFAULT_BRANCH" ]
then
    DEFAULT_BRANCH="master"
fi

echo "Default is $DEFAULT_BRANCH"

if [ -n "$BRANCH" ]; then
    GIT_COMMAND="$GIT_COMMAND $BRANCH:$DEFAULT_BRANCH"
else
    GIT_COMMAND="$GIT_COMMAND HEAD:$DEFAULT_BRANCH"
fi

if [ -n "$FORCE_DEPLOY" ]; then
    echo "Enabling force deploy"
    GIT_COMMAND="$GIT_COMMAND --force"
fi

GIT_SSH_COMMAND="ssh -p ${PORT-22} -i $SSH_PATH/deploy_key"
if [ -n "$HOST_KEY" ]; then
    echo "Adding hosts key to known_hosts"
    echo "$HOST_KEY" >> "$SSH_PATH/known_hosts"
    chmod 600 "$SSH_PATH/known_hosts"
else
    echo "Disabling host key checking"
    GIT_SSH_COMMAND="$GIT_SSH_COMMAND -o StrictHostKeyChecking=no"
fi

if [ -n "$APP_CONFIG" ]; then
    echo "Setting app config"
    $GIT_SSH_COMMAND dokku@$HOST config:set --no-restart $PROJECT $APP_CONFIG 2>&1 > /dev/null
fi

if [ -n "$DOCKERFILE_LOCATION" ]; then
    echo "Setting Dockerfile localtion"
    $GIT_SSH_COMMAND dokku@$HOST builder-dockerfile:set $PROJECT $DOCKERFILE_LOCATION 2>&1 > /dev/null
fi

echo "The deploy is starting"

GIT_SSH_COMMAND="$GIT_SSH_COMMAND" $GIT_COMMAND
