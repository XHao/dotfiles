# 06-title —— tmux 内 pane 标题跟随当前目录
# tmux 建窗格时默认把标题填成主机名（LZ-L250066.local）；每个提示符前
# 发 OSC 2 覆盖为 %~（home 记作 ~），外层终端标题（含 #T）即显示目录。
# 只在 tmux 内生效，裸 shell 不动终端标题。
# 窗格里跑着的程序（vim、claude 等）可自行接管标题；退出后下个提示符恢复目录。
if [[ -n "${TMUX:-}" ]]; then
    _pane_title_update() { print -Pn '\e]2;%~\e\\' }
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd _pane_title_update
fi
