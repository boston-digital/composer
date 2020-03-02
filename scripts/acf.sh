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

  if [ -d "$dir" ]; then
    return 0
  else
    return 1
  fi
}

file_exists ()
{
  local file="$1"

  if [ -f "$file" ]; then
    return 0
  else
    return 1
  fi
}

setup_git_repo ()
{
  if ! dir_exists "$GIT_TARGET_DIR"; then
    echo "Cloning $GIT_URL into $GIT_TARGET_DIR..."
    git clone "$GIT_URL" "$GIT_TARGET_DIR" --quiet
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
    --silent \
    "https://api.github.com/repos/${GIT_NAME}/releases"
}

git_tag_exists ()
{
  local tag="$1"
  if [ $( cd "$GIT_TARGET_DIR" && git tag -l "$tag" ) ]; then
    return 0
  else
    return 1
  fi
}

mirror ()
{
  local wp_endpoint="https://api.wordpress.org/plugins/info/1.0/advanced-custom-fields.json"
  echo "Retrieving latest ACF version from WordPress API..."
  local version="$( curl "$wp_endpoint" --silent | jq '.version' --raw-output )"
  local acf_endpoint="https://connect.advancedcustomfields.com/index.php?a=download&p=pro&k=${ACF_PRO_KEY}&t=${version}"
  local acf_filepath="${FILES_DIR}/advanced-custom-fields-pro.${version}.zip"
  local acf_unzip_dir="${FILES_DIR}/advanced-custom-fields-pro"

  if git_tag_exists "v${version}"; then
    echo "Version already exists - nothing to do."
    exit
  fi

  exit

  if ! file_exists "$acf_filepath"; then
    echo "Downloading ACF version $version..."
    curl --output "$acf_filepath" "$acf_endpoint" --silent
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
  git add . && git commit -m "v${version}" && git tag "v${version}" && git push --follow-tags -u origin master
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
