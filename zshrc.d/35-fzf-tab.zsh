# 35-fzf-tab —— fzf 集成 + Tab 补全 fzf 化
# 加载顺序是硬约束：fzf --zsh（键位+补全，绑定 ^I）必须先于 fzf-tab，否则会
# 反向覆盖 fzf-tab 的 Tab；fzf-tab 又必须先于会包装 widget 的 zsh-autosuggestions
# （40-enhance），故本模块整体卡在 30-omz（compinit）与 40 之间。
# fzf-tab 不做补全，只把 compsys 补全系统的结果交给 fzf 渲染——一切补全场景
# 与既有 zstyle 均生效。安装: fzf 由 Brewfile 安装；fzf-tab 由 bootstrap 步骤 5
# 克隆到 ~/.zsh/fzf-tab（brew 无 formula）。交互: 模糊过滤 / Ctrl-Space 多选 / <> 切分组
command -v fzf &>/dev/null && source <(fzf --zsh)
if [ -f "$HOME/.zsh/fzf-tab/fzf-tab.plugin.zsh" ]; then
    source "$HOME/.zsh/fzf-tab/fzf-tab.plugin.zsh"

    # 无歧义前缀也进 fzf（禁用 zsh 原生菜单）
    zstyle ':completion:*' menu no
    # 分组标题格式（fzf-tab 靠它识别分组；不要用 %F 等颜色转义）
    zstyle ':completion:*:descriptions' format '[%d]'
    # git checkout 补全不排序（保留分支描述可读性）
    zstyle ':completion:*:git-checkout:*' sort false
    # cd 时右侧预览目录内容（BSD ls 无 --color，-A 含隐藏文件）
    zstyle ':fzf-tab:complete:cd:*' fzf-preview 'ls -1A $realpath'
    # < > 在补全分组间切换
    zstyle ':fzf-tab:*' switch-group '<' '>'
fi
