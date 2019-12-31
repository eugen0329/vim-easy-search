#!/bin/sh

csv_line_contains() {
  local csv_line
  local field
  csv_line="$1"
  field="$2"

  echo "$csv_line" | grep -E "(^|,)$field(,|$)" 1>/dev/null 2>&1
}

crossplatform_realpath() {
    [ "$1" = '/*' ] && \ echo "$1" || echo "$PWD/${1#./}"
}

log_choosen_options() {
  [ "$2" = '1' ] && echo "INSTALLING $1 locally"
  [ "$3" = '1' ] && echo "INSTALLING $1 globally"
  [ "$2" = '' ] && [ "$3" = '' ] && echo "IGNORING $1: No options for installation provided" && return 1
  return 0
}

log_unsupported() {
  echo "WARNING: $1 is unsupported"
}

install_vim() {
  install_local=$(csv_line_contains $INSTALL 'vim-local' && echo 1)
  install_global=$(csv_line_contains $INSTALL 'vim-global' && echo 1)
  log_choosen_options 'vim' "$install_local" "$install_global" || return 0
  [ "$install_local" = '1' ] && log_unsupported 'vim-local'

  (
  set -eux
  if [ "$PACKAGE_MANAGER" = apt-get ] ; then
    $SUDO add-apt-repository ppa:jonathonf/vim -y
    $SUDO apt update -y
    $SUDO apt-get install -y "$APT_GET_INSTALL_LESS" vim-gtk
  elif [ "$PACKAGE_MANAGER" = apk ] ; then
    apk add "$APK_INSTALL_LESS" gvim
  fi
  )
}

install_ack() {
  install_local=$(csv_line_contains $INSTALL 'ack-local' && echo 1)
  install_global=$(csv_line_contains $INSTALL 'ack-global' && echo 1)
  log_choosen_options 'ack' "$install_local" "$install_global" || return 0
  [ "$install_local" = '1' ] && log_unsupported 'ack-local'

  (
  set -eux
  if [ "$PACKAGE_MANAGER" = apt-get ] ; then
    $SUDO apt-get install -y "$APT_GET_INSTALL_LESS" ack-grep
    $SUDO dpkg-divert --local --divert /usr/bin/ack --rename --add /usr/bin/ack-grep
  elif [ "$PACKAGE_MANAGER" = apk ] ; then
    apk add "$APK_INSTALL_LESS" ack
  fi
  )
}

install_ag() {
  install_local=$(csv_line_contains $INSTALL  'ag-local' && echo 1)
  install_global=$(csv_line_contains $INSTALL 'ag-global' && echo 1)
  log_choosen_options 'ag' "$install_local" "$install_global" || return 0
  [ "$install_local" = '1' ] && log_unsupported 'ag-local'

  (
  set -eux
  if [ "$PACKAGE_MANAGER" = apt-get ] ; then
    command -v ag || $SUDO apt-get install -y "$APT_GET_INSTALL_LESS" silversearcher-ag
  elif [ "$PACKAGE_MANAGER" = apk ] ; then
    apk add "$APK_INSTALL_LESS" the_silver_searcher
  fi
  )
}

install_rg() {
  rgversion=${1:-'11.0.2'}
  install_local=$(csv_line_contains $INSTALL 'rg-local' && echo 1)
  install_global=$(csv_line_contains $INSTALL 'rg-global' && echo 1)
  log_choosen_options 'rg' "$install_local" "$install_global" || return 0

  (
    set -eux
    mkdir -p "/tmp/rg-$rgversion" &&
    cd "/tmp/rg-$rgversion" &&
    wget -N "https://github.com/BurntSushi/ripgrep/releases/download/$rgversion/ripgrep-$rgversion-x86_64-unknown-linux-musl.tar.gz" &&
    tar xvfz "ripgrep-$rgversion-x86_64-unknown-linux-musl.tar.gz" &&
    cp "ripgrep-$rgversion-x86_64-unknown-linux-musl/rg" "$bin_directory/rg-$rgversion" &&
    ([ "$install_global" = '1' ] && $SUDO cp "ripgrep-$rgversion-x86_64-unknown-linux-musl/rg" "/usr/local/bin/rg" || true)
  )
  rm -rvf "/tmp/rg-$rgversion"
}

install_pt() {
  ptversion=${1:-'2.2.0'}
  install_local=$(csv_line_contains $INSTALL 'pt-local' && echo 1)
  install_global=$(csv_line_contains $INSTALL 'pt-global' && echo 1)
  log_choosen_options 'pt' "$install_local" "$install_global" || return 0

  (
    set -eux
    mkdir -p "/tmp/pt-$ptversion" &&
    cd "/tmp/pt-$ptversion" &&
    wget -N "https://github.com/monochromegane/the_platinum_searcher/releases/download/v$ptversion/pt_linux_amd64.tar.gz" &&
    tar xvfz pt_linux_amd64.tar.gz &&
    cp pt_linux_amd64/pt "$bin_directory/pt-$ptversion" &&
    ([ "$install_global" = 1 ] && $SUDO cp pt_linux_amd64/pt /usr/local/bin/pt || true)
  )
  rm -rvf "/tmp/pt-$ptversion"
}

install_neovim() {
  install_local=$(csv_line_contains $INSTALL 'neovim-local' && echo 1)
  install_global=$(csv_line_contains $INSTALL 'neovim-global' && echo 1)
  log_choosen_options 'neovim' "$install_local" "$install_global" || return 0

  (
    set -eux
    cd "$bin_directory" &&
    wget -N https://github.com/neovim/neovim/releases/download/v0.4.3/nvim.appimage &&
    chmod +x "nvim.appimage" &&
    (./nvim.appimage --appimage-extract 1>/dev/null 2>&1 || true)
  )
  rm $bin_directory/nvim.appimage
  pip3 install "$PIP3_INSTALL_LESS" neovim-remote
}

bin_directory="${1:-"$(dirname "$(crossplatform_realpath "$0")")"}"; mkdir -p "$bin_directory"

if [ "${ALLOW_SUDO:-1}" = '1' ] ; then
  SUDO=sudo
else
  SUDO=
fi

APT_GET_INSTALL_LESS='--no-install-recommends'
APK_INSTALL_LESS='--no-cache'
PIP3_INSTALL_LESS='--no-cache'

if command -v apt-get ; then
  PACKAGE_MANAGER=apt-get
else
  PACKAGE_MANAGER=apk
fi
INSTALL=${INSTALL:-'vim-global,neovim-local,ack-global,ag-global,rg-local,pt-local'}

echo $INSTALL

install_vim
install_neovim
install_ack
install_ag
install_rg
install_pt

# vim --version
# "$bin_directory/squashfs-root/usr/bin/nvim" --version
# "$bin_directory/squashfs-root/usr/bin/nvim" --headless -c 'set nomore' -c "echo api_info()" -c qall
# "$bin_directory/squashfs-root/usr/bin/nvim" --headless -c 'echo [&shell, &shellcmdflag]' -c qall
# "$bin_directory/squashfs-root/usr/bin/nvim" --headless -c 'echo ["jobstart",exists("*jobstart"), "jobclose", exists("*jobclose"), "jobstop ", exists("*jobstop"), "jobwait ", exists("*jobwait")]' -c qall
# ack --version
# ag --version
# git --version
# grep --version
# pt --version
# rg --version

# # # command -v xterm && xterm -help
