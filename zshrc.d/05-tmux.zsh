# 05-tmux —— Terminal 打开即进 tmux
# exec 替换当前 shell：detach 或退出时 Terminal 窗口直接关闭，不留一层
# 裸壳（否则 detach 后掉回 zsh，永远分不清在不在 tmux 里）
# 三重防护：tmux 内不嵌套（$TMUX）/ 非交互不触发（脚本、IDE 终端、工具
# 调用）/ 未装 tmux 跳过（brew bundle 未跑的新机器首启不报错）
# if [[ -o interactive && -z "${TMUX:-}" ]] && command -v tmux &>/dev/null; then
#     exec tmux new -A -s main
# fi
