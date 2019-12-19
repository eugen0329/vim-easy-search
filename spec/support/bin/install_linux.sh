#!/bin/sh

# NOTE every which is intentionally kept without redirection output to /dev/null

# sudo apt-get remove -y -f vim
# sudo apt-get remove -y -f vim-common
# sudo apt-get remove -y -f vim-gui-common
# sudo apt-get remove -y -f vim-runtime 

# sudo add-apt-repository ppa:jonathonf/vim -y
sudo apt update -y
sudo apt-get install -y vim-gtk

# install ack
if ! which ack; then
  sudo apt-get install -y ack-grep
  sudo dpkg-divert --local --divert /usr/bin/ack --rename --add /usr/bin/ack-grep
fi

# install ag
which ag || sudo apt-get install -y silversearcher-ag

# install rg
if ! which rg; then
  wget https://github.com/BurntSushi/ripgrep/releases/download/0.7.1/ripgrep-0.7.1-x86_64-unknown-linux-musl.tar.gz
  tar xvfz ripgrep-0.7.1-x86_64-unknown-linux-musl.tar.gz
  sudo mv ripgrep-0.7.1-x86_64-unknown-linux-musl/rg /usr/local/bin/rg
fi

# install pt
if ! which pt; then
  wget https://github.com/monochromegane/the_platinum_searcher/releases/download/v2.1.5/pt_linux_amd64.tar.gz
  tar xvfz pt_linux_amd64.tar.gz
  sudo mv pt_linux_amd64/pt /usr/local/bin/pt
fi