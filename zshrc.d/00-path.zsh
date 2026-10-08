# 00-path —— PATH 基础与 Homebrew
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Homebrew 优先于系统自带工具（如 vim）
eval "$(/opt/homebrew/bin/brew shellenv)"

# auto_updates 类 cask（google-chrome）交给应用自更新，brew 升级不碰它们：
# dl.google.com 在本网络会被重置（curl 56），brew 7 起默认连这类 cask 一起升，
# dfm u 每次都败在这一步；真要手动升（需代理）：brew upgrade --greedy --cask google-chrome
export HOMEBREW_NO_UPGRADE_AUTO_UPDATES_CASKS=1

# bottle 走 USTC 镜像：ghcr.io 的 blob 经 307 跳到 GitHub CDN（cdn-*.github.com），
# 在本网络限速 ~10KB/s 且长连接会被掐（curl 92 HTTP/2 PROTOCOL_ERROR），dfm u 曾
# 因此在 Brewfile 补齐一步爬 40+ 分钟且 podman 反复失败；镜像仅换下载源，内容仍过
# brew 的 sha256+bottle 元数据 JWS 签名双层校验，无法被镜像篡改（2026-10-08 实测）
export HOMEBREW_BOTTLE_DOMAIN=https://mirrors.ustc.edu.cn/homebrew-bottles

# brew update 走 SSH：它要 git fetch brew 仓库自身，默认 origin 是
# https://github.com/Homebrew/brew——本网络 github.com HTTPS 直连被 RST（curl 56），
# dfm u 曾死在这一步。brew update 看到该变量会自动把 origin 重写为 SSH 再 fetch
# （brew 7 官方行为，无需手动 set-url）；core tap 当前未克隆，一并设上作防御，
# 与「git 远程操作一律 SSH」的既有约定一致（2026-10-08 实测）
export HOMEBREW_BREW_GIT_REMOTE="git@github.com:Homebrew/brew.git"
export HOMEBREW_CORE_GIT_REMOTE="git@github.com:Homebrew/homebrew-core.git"
