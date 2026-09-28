# 00-path —— PATH 基础与 Homebrew
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Homebrew 优先于系统自带工具（如 vim）
eval "$(/opt/homebrew/bin/brew shellenv)"

# auto_updates 类 cask（google-chrome）交给应用自更新，brew 升级不碰它们：
# dl.google.com 在本网络会被重置（curl 56），brew 7 起默认连这类 cask 一起升，
# dfm u 每次都败在这一步；真要手动升（需代理）：brew upgrade --greedy --cask google-chrome
export HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS=1
