# 00-path —— PATH 基础与 Homebrew
export PATH=$HOME/bin:$HOME/.local/bin:/usr/local/bin:$PATH

# Homebrew 优先于系统自带工具（如 vim）
eval "$(/opt/homebrew/bin/brew shellenv)"
