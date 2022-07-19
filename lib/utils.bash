#!/usr/bin/env bash

set -euo pipefail

# TODO: Ensure this is the correct GitHub homepage where releases can be downloaded for chromedriver.
GH_REPO="https://chromedriver.chromium.org/"
TOOL_NAME="chromedriver"
TOOL_TEST="chromedriver --version"
DL_PREFIX="https://chromedriver.storage.googleapis.com/"

fail() {
  echo -e "asdf-$TOOL_NAME: $*"
  exit 1
}

curl_opts=(-fsSL)

sort_versions() {
  sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
    LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
  git ls-remote --tags --refs "$GH_REPO" |
    grep -o 'refs/tags/.*' | cut -d/ -f3- |
    sed 's/^v//' # NOTE: You might want to adapt this sed to remove non-version strings from tags
}

list_all_versions() {
  local chrome_app version
  case "$OSTYPE" in
  darwin*) chrome_app="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" ;;
  linux*) chrome_app=google-chrome ;;
  *) fail "Unsupported platform" ;;
  esac

  version=$("$chrome_app" --version | cut -f 3 -d ' ' | cut -d '.' -f 1)

  curl "${curl_opts[@]}" "$DL_PREFIX" |
    sed -e 's/<Key>/\n&/g' -e 's/<\/Key>/&\n/g' |
    sed -n "s/[^<]*<Key>\($version\.[0-9]*\.[0-9]*\.[0-9]*\).*<\/Key>/\1/gp" |
    uniq
}

download_release() {
  local version filename url
  version="$1"
  filename="$2"

  local platform
  case "$OSTYPE" in
  darwin*) platform="mac" ;;
  linux*) platform="linux" ;;
  *) fail "Unsupported platform" ;;
  esac

  local architecture
  if [ "$platform" == "mac" ]; then
    case "$(uname -m)" in
    x86_64) architecture="64" ;;
    arm64) architecture="64_m1" ;;
    *) fail "Unsupported architecture" ;;
    esac
  else
    case "$(uname -m)" in
    x86_64) architecture="64" ;;
    *) fail "Unsupported architecture" ;;
    esac
  fi

  url="${DL_PREFIX}${version}/${TOOL_NAME}_${platform}${architecture}.zip"

  echo "* Downloading $TOOL_NAME release $version..."
  curl "${curl_opts[@]}" -o "$filename" -C - "$url" || fail "Could not download $url"
}

install_version() {
  local install_type="$1"
  local version="$2"
  local install_path="${3%/bin}/bin"

  if [ "$install_type" != "version" ]; then
    fail "asdf-$TOOL_NAME supports release installs only"
  fi

  (
    mkdir -p "$install_path"
    cp -r "$ASDF_DOWNLOAD_PATH"/* "$install_path"

    local tool_cmd
    tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
    test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

    echo "$TOOL_NAME $version installation was successful!"
  ) || (
    rm -rf "$install_path"
    fail "An error ocurred while installing $TOOL_NAME $version."
  )
}
