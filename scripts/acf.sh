#!/usr/bin/env bash

DIR="$( cd "$( dirname "$( dirname "${BASH_SOURCE[0]}" )" )" >/dev/null 2>&1 && pwd )"
GIT_TARGET_DIR="${DIR}/advanced-custom-fields-pro/"
GIT_NAME="boston-digital/wp-advanced-custom-fields-pro"
GIT_URL="git@github.com:${GIT_NAME}.git"
ENV_FILEPATH="${DIR}/.env";
FILES_DIR="${DIR}/files"

command_exists ()
{
  local cmd="$1"

  if command -v "$cmd" >/dev/null 2>&1; then
    return 0
  else
    return 1
  fi
}

acf_key_check ()
{
  if [ -z "$ACF_PRO_KEY" ]; then
    echo '$ACF_PRO_KEY not defined or invalid'
    exit 1
  fi
}

github_credentials_check ()
{
  if [ -z "$GITHUB_TOKEN" ]; then
    echo '$GITHUB_TOKEN not defined'
    exit 1
  fi

  if [ -z "$GITHUB_USER" ]; then
    echo '$GITHUB_USER not defined'
    exit 1
  fi
}

git_check ()
{
  if ! command_exists git; then
    echo "git is required, but not installed"
    exit 1
  fi
}

os ()
{
  if [ "$( uname )" == "Darwin" ]; then
    echo "Mac"
  elif [ "$( expr substr $( uname -s ) 1 5 )" == "Linux" ]; then
    echo "Linux"
  elif [ "$( expr substr $( uname -s ) 1 10 )" == "MINGW32_NT" ]; then
    echo "Win32"
  elif [ "$( expr substr $( uname -s ) 1 10 )" == "MINGW64_NT" ]; then
    echo "Win64"
  fi
}

jq_check ()
{
  if ! command_exists jq; then
    echo "jq is required, but not installed > https://stedolan.github.io/jq/download/"
    exit 1
  fi
}

unzip_check ()
{
  if ! command_exists unzip; then
    local os="$( os )"
    echo "unzip is required, but not installed"
    if [ "$os" == "Mac" ]; then
      echo "brew install unzip"
    elif [ "$os" == "Linux" ]; then
      echo "sudo apt-get -y install unzip"
    fi
    exit 1
  fi
}

dir_exists ()
{
  local dir="$1"
  [ -d "$1" ] && return 0 || return 1
}

file_exists ()
{
  local file="$1"
  [ -f "$file" ] && return 0 || return 1
}

is_repo_dirty ()
{
  [ -z "$(git status -s)" ] && return 1 || return 0
}

setup_git_repo ()
{
  if ! dir_exists "$GIT_TARGET_DIR"; then
    echo "Cloning $GIT_URL into $GIT_TARGET_DIR..."
    git clone "$GIT_URL" "$GIT_TARGET_DIR" --quiet
  else
    pushd "$GIT_TARGET_DIR" >/dev/null

    if is_repo_dirty; then
      echo "$GIT_TARGET_DIR is dirty. Cleaning things up..."
      git reset --hard >/dev/null
      git clean -fd . >/dev/null
    fi

    echo "Pulling updates from origin..."
    # ensure tags are in sync with origin
    (git tag | xargs git tag -d && git fetch --tags) >/dev/null 2>&1
    ## pull any other changes
    git pull >/dev/null

    popd >/dev/null
  fi
}

write_composer_json ()
{
  local composer_path="${GIT_TARGET_DIR}/composer.json"
  local version="$1"
  cat <<EOT > "$composer_path"
{
  "name": "boston-digital/wp-advanced-custom-fields-pro",
  "description": "Mirror of Advanced Custom Fields Pro. This repository is managed by a bot.",
  "license": "proprietary",
  "version": "${version}",
  "type": "wordpress-plugin",
  "extra": {
    "installer-name": "advanced-custom-fields-pro"
  },
  "require": {
    "composer/installers": "^1.6.0"
  }
}
EOT
}

create_release ()
{
  local tag="v${1}"
  curl \
    -u ${GITHUB_USER}:${GITHUB_TOKEN} \
    -H "Content-Type: application/json" \
    --data '{"tag_name":"'${tag}'","target_commitish":"master","name":"'${tag}'","body":"'${tag}'","draft":false,"prerelease":false}' \
    --output /dev/null \
    --show-error \
    --fail \
    --silent \
    "https://api.github.com/repos/${GIT_NAME}/releases"
}

git_tag_exists ()
{
  local tag="$1"
  [ $( cd "$GIT_TARGET_DIR" && git tag -l "$tag" ) ] && return 0 || return 1
}

mirror ()
{
  local wp_endpoint="https://api.wordpress.org/plugins/info/1.0/advanced-custom-fields.json"
  echo "Retrieving latest ACF version from WordPress API..."
  local version="$( curl "$wp_endpoint" --silent | jq '.version' --raw-output )"
  local acf_endpoint="https://connect.advancedcustomfields.com/v2/plugins/download?p=pro&k=${ACF_PRO_KEY}&t=${version}"
  local acf_filepath="${FILES_DIR}/advanced-custom-fields-pro.${version}.zip"
  local acf_unzip_dir="${FILES_DIR}/advanced-custom-fields-pro"

  if git_tag_exists "v${version}"; then
    echo "Version already exists - nothing to do."
    exit
  fi

  if ! file_exists "$acf_filepath"; then
    echo "Downloading ACF version $version to $acf_filepath..."
    curl --output "$acf_filepath" --create-dirs --location --silent "$acf_endpoint"

    if ! file_exists "$acf_filepath"; then
      echo "An error occurred while downloading ACF :("
      exit 1
    fi
  fi

  echo "Extracting zip file..."
  unzip -qq "$acf_filepath" -d "$FILES_DIR"
  echo "Moving files..."
  rsync -r --delete --exclude=".git" "${acf_unzip_dir}/" "$GIT_TARGET_DIR"
  echo "Writing composer.json..."
  write_composer_json "$version"
  echo "Pushing to git..."
  pushd "$GIT_TARGET_DIR" >/dev/null
  echo "Creating release..."
  create_release "$version"
  (git add . && git commit -m "v${version}" && git tag "v${version}" && git push --follow-tags -u origin master) >/dev/null 2>&1
  popd >/dev/null
  echo "Cleaning up..."
  rm -rf "$acf_unzip_dir"
}

if file_exists "$ENV_FILEPATH"; then
  source "$ENV_FILEPATH"
fi

acf_key_check
github_credentials_check
jq_check
unzip_check
git_check

setup_git_repo
mirror
