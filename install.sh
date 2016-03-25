#!/usr/bin/env bash

# This is a direct clone of the NVM install script
# modified to work with juju
# MIT licensed by Tim Caswell
# the original can be found at https://github.com/creationix/nvm

{ # this ensures the entire script is downloaded #

juju_has() {
  type "$1" > /dev/null 2>&1
}

if [ -z "$JUJU_DIR" ]; then
  JUJU_DIR="$HOME/.juju.jl"
fi

juju_latest_version() {
  echo "v0.0.1"
}

#
# Outputs the location to JUJU depending on:
# * The availability of $JUJU_SOURCE
# * The method used ("script" or "git" in the script, defaults to "git")
# JUJU_SOURCE always takes precedence unless the method is "script-juju-exec"
#
juju_source() {
  local JUJU_METHOD
  JUJU_METHOD="$1"
  local JUJU_SOURCE_URL
  JUJU_SOURCE_URL="$JUJU_SOURCE"
  if [ "_$JUJU_METHOD" = "_script-juju-exec" ]; then
    JUJU_SOURCE_URL="https://raw.githubusercontent.com/biojulia/juju/$(juju_latest_version)/juju-exec"
  elif [ -z "$JUJU_SOURCE_URL" ]; then
    if [ "_$JUJU_METHOD" = "_script" ]; then
      JUJU_SOURCE_URL="https://raw.githubusercontent.com/biojulia/juju/$(juju_latest_version)/juju.sh"
    elif [ "_$JUJU_METHOD" = "_git" ] || [ -z "$JUJU_METHOD" ]; then
      JUJU_SOURCE_URL="https://github.com/biojulia/juju.git"
    else
      echo >&2 "Unexpected value \"$JUJU_METHOD\" for \$JUJU_METHOD"
      return 1
    fi
  fi
  echo "$JUJU_SOURCE_URL"
}

juju_download() {
  if juju_has "curl"; then
    curl -q $*
  elif juju_has "wget"; then
    # Emulate curl with wget
    ARGS=$(echo "$*" | command sed -e 's/--progress-bar /--progress=bar /' \
                           -e 's/-L //' \
                           -e 's/-I /--server-response /' \
                           -e 's/-s /-q /' \
                           -e 's/-o /-O /' \
                           -e 's/-C - /-c /')
    wget $ARGS
  fi
}

install_juju_from_git() {
  if [ -d "$JUJU_DIR/.git" ]; then
    echo "=> juju is already installed in $JUJU_DIR, trying to update using git"
    printf "\r=> "
    cd "$JUJU_DIR" && (command git fetch 2> /dev/null || {
      echo >&2 "Failed to update juju, run 'git fetch' in $JUJU_DIR yourself." && exit 1
    })
  else
    # Cloning to $JUJU_DIR
    echo "=> Downloading juju from git to '$JUJU_DIR'"
    printf "\r=> "
    mkdir -p "$JUJU_DIR"
    command git clone "$(juju_source git)" "$JUJU_DIR"
  fi
  cd "$JUJU_DIR" && command git checkout --quiet "$(juju_latest_version)"
  if [ ! -z "$(cd "$JUJU_DIR" && git show-ref refs/heads/master)" ]; then
    if git branch --quiet 2>/dev/null; then
      cd "$JUJU_DIR" && command git branch --quiet -D master >/dev/null 2>&1
    else
      echo >&2 "Your version of git is out of date. Please update it!"
      cd "$JUJU_DIR" && command git branch -D master >/dev/null 2>&1
    fi
  fi
  return
}

install_juju_as_script() {
  local JUJU_SOURCE_LOCAL
  JUJU_SOURCE_LOCAL=$(juju_source script)
  local JUJU_EXEC_SOURCE
  JUJU_EXEC_SOURCE=$(juju_source script-juju-exec)

  # Downloading to $JUJU_DIR
  mkdir -p "$JUJU_DIR"
  if [ -f "$JUJU_DIR/juju.sh" ]; then
    echo "=> juju is already installed in $JUJU_DIR, trying to update the script"
  else
    echo "=> Downloading juju as script to '$JUJU_DIR'"
  fi
  juju_download -s "$JUJU_SOURCE_LOCAL" -o "$JUJU_DIR/juju.sh" || {
    echo >&2 "Failed to download '$JUJU_SOURCE_LOCAL'"
    return 1
  }
  juju_download -s "$JUJU_EXEC_SOURCE" -o "$JUJU_DIR/juju-exec" || {
    echo >&2 "Failed to download '$JUJU_EXEC_SOURCE'"
    return 2
  }
  chmod a+x "$JUJU_DIR/juju-exec" || {
    echo >&2 "Failed to mark '$JUJU_DIR/juju-exec' as executable"
    return 3
  }
}

#
# Detect profile file if not specified as environment variable
# (eg: PROFILE=~/.myprofile)
# The echo'ed path is guaranteed to be an existing file
# Otherwise, an empty string is returned
#
juju_detect_profile() {
  if [ -n "$PROFILE" -a -f "$PROFILE" ]; then
    echo "$PROFILE"
    return
  fi

  local DETECTED_PROFILE
  DETECTED_PROFILE=''
  local SHELLTYPE
  SHELLTYPE="$(basename "/$SHELL")"

  if [ "$SHELLTYPE" = "bash" ]; then
    if [ -f "$HOME/.bashrc" ]; then
      DETECTED_PROFILE="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
      DETECTED_PROFILE="$HOME/.bash_profile"
    fi
  elif [ "$SHELLTYPE" = "zsh" ]; then
    DETECTED_PROFILE="$HOME/.zshrc"
  fi

  if [ -z "$DETECTED_PROFILE" ]; then
    if [ -f "$HOME/.profile" ]; then
      DETECTED_PROFILE="$HOME/.profile"
    elif [ -f "$HOME/.bashrc" ]; then
      DETECTED_PROFILE="$HOME/.bashrc"
    elif [ -f "$HOME/.bash_profile" ]; then
      DETECTED_PROFILE="$HOME/.bash_profile"
    elif [ -f "$HOME/.zshrc" ]; then
      DETECTED_PROFILE="$HOME/.zshrc"
    fi
  fi

  if [ ! -z "$DETECTED_PROFILE" ]; then
    echo "$DETECTED_PROFILE"
  fi
}

juju_do_install() {
  if [ -z "$METHOD" ]; then
    # Autodetect install method
    if juju_has "git"; then
      install_juju_from_git
    elif juju_has "juju_download"; then
      install_juju_as_script
    else
      echo >&2 "You need git, curl, or wget to install juju"
      exit 1
    fi
  elif [ "~$METHOD" = "~git" ]; then
    if ! juju_has "git"; then
      echo >&2 "You need git to install juju"
      exit 1
    fi
    install_juju_from_git
  elif [ "~$METHOD" = "~script" ]; then
    if ! juju_has "juju_download"; then
      echo >&2 "You need curl or wget to install juju"
      exit 1
    fi
    install_juju_as_script
  fi

  echo

  local JUJU_PROFILE
  JUJU_PROFILE=$(juju_detect_profile)

  SOURCE_STR="\nexport JUJU_DIR=\"$JUJU_DIR\"\n[ -s \"\$JUJU_DIR/juju.sh\" ] && . \"\$JUJU_DIR/juju.sh\"  # This loads juju"

  if [ -z "$JUJU_PROFILE" ] ; then
    echo "=> Profile not found. Tried $JUJU_PROFILE (as defined in \$PROFILE), ~/.bashrc, ~/.bash_profile, ~/.zshrc, and ~/.profile."
    echo "=> Create one of them and run this script again"
    echo "=> Create it (touch $JUJU_PROFILE) and run this script again"
    echo "   OR"
    echo "=> Append the following lines to the correct file yourself:"
    printf "$SOURCE_STR"
    echo
  else
    if ! command grep -qc '/juju.sh' "$JUJU_PROFILE"; then
      echo "=> Appending source string to $JUJU_PROFILE"
      printf "$SOURCE_STR\n" >> "$JUJU_PROFILE"
    else
      echo "=> Source string already in $JUJU_PROFILE"
    fi
  fi

  juju_check_global_modules

  echo "=> Close and reopen your terminal to start using juju"
  juju_reset
}

#
# Unsets the various functions defined
# during the execution of the install script
#
juju_reset() {
  unset -f juju_reset juju_has juju_latest_version \
    juju_source juju_download install_juju_as_script install_juju_from_git \
    juju_detect_profile juju_check_global_modules juju_do_install
}

[ "_$JUJU_ENV" = "_testing" ] || juju_do_install

} # this ensures the entire script is downloaded #
