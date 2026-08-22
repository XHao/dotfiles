# 40-enhance —— 历史调优 + 历史建议 + fzf 键位
# ---- 历史记录调优（omz 已含 share_history / 相邻去重，此处加强）----
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_ALL_DUPS   # 全量去重，删旧留新
setopt HIST_FIND_NO_DUPS      # 历史搜索跳过重复
setopt HIST_REDUCE_BLANKS     # 入史时压缩多余空白

# ---- brew 安装的 zsh 增强（Brewfile 管理，见 ~/dotfiles）----
# 历史建议：灰色显示匹配的历史命令，→ 采纳
[ -f /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] && \
    source /opt/homebrew/share/zsh-autosuggestions/zsh-autosuggestions.zsh
# fzf 集成: Ctrl-R 模糊历史 / Ctrl-T 模糊文件名 / Alt-C 模糊跳目录
command -v fzf &>/dev/null && source <(fzf --zsh)
