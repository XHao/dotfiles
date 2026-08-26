# =========================================================================
# .zshrc —— 模块化入口
# 按文件名序加载 ~/dotfiles/zshrc.d/ 下的 *.zsh，数字前缀即加载顺序：
#   00-path        PATH 基础 + Homebrew
#   05-tmux        Terminal 打开即进 tmux（attach 优先，exec 替换）
#   10-java        JAVA_HOME + jdk 多版本切换
#   20-go          ~/go/bin（vim-go 工具链）+ GOPROXY 模块代理
#   30-omz         Oh My Zsh（主题 + 8 插件）
#   40-enhance     历史调优 + 自动建议 + fzf 键位
#   50-ai          Claude Code 环境与 mcc/claude_ext
#   60-dfm         dfm 包管理器
#   90-highlight   语法高亮（必须最后，故前缀 90）
# 新增功能 = 在 zshrc.d/ 加一个新模块文件，无需改动本文件
# =========================================================================

for _mod in "$HOME"/dotfiles/zshrc.d/*.zsh(N); do
    source "$_mod"
done
unset _mod

# 本机私有配置（不入库）：临时密钥、公司内网代理等机器相关内容放这里
[ -f "$HOME/.zshrc.local" ] && source "$HOME/.zshrc.local"
