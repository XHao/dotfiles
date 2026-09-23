# 05-tmux —— Terminal 打开即进 tmux
# exec 替换当前 shell：detach 或退出时 Terminal 窗口直接关闭，不留一层
# 裸壳（否则 detach 后掉回 zsh，永远分不清在不在 tmux 里）
# 每个终端窗口 = 一个全新独立会话（各自切窗口，互不镜像；同名由 tmux
# 自动编号）。destroy-unattached：该窗口关闭/detach 即销毁自己的会话，
# 零残留；手动 tmux new -s 建的项目会话不带此标记，不受影响仍然持久
# 三重防护：tmux 内不嵌套（$TMUX）/ 非交互不触发（脚本、IDE 终端、工具
# 调用）/ 未装 tmux 跳过（brew bundle 未跑的新机器首启不报错）
if [[ -o interactive && -z "${TMUX:-}" ]] && command -v tmux &>/dev/null; then
    exec tmux new \; set-option destroy-unattached on
fi
