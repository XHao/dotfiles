# 30-omz —— Oh My Zsh 核心（主题/插件/加载）
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="agnoster"

plugins=(
    git
    z                    # 目录跳转: z <关键词> 直达高频目录（frecency）
    sudo                 # 双击 ESC 给当前命令补 sudo
    extract              # x <压缩包> 通吃所有格式
    colored-man-pages
    macos                # flushdns / ofd 等 Mac 便利命令
    kubectl              # k8s 别名: k=kubectl, kgpo=get pods...
    bgnotify             # 长命令结束弹系统通知（mvn/gradle/brew bundle）
)

source $ZSH/oh-my-zsh.sh
