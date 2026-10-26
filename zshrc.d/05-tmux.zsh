# 05-tmux —— Terminal 打开即进 tmux
# exec 替换当前 shell：detach 或退出时 Terminal 窗口直接关闭，不留一层
# 裸壳（否则 detach 后掉回 zsh，永远分不清在不在 tmux 里）
# 每个终端窗口 = 一个全新独立会话（各自切窗口，互不镜像；同名由 tmux
# 自动编号）。destroy-unattached：该窗口关闭/detach 即销毁自己的会话，
# 零残留；手动 tmux new -s 建的项目会话不带此标记，不受影响仍然持久
# 三重防护：tmux 内不嵌套（$TMUX）/ 非交互不触发（脚本、IDE 终端、工具
# 调用）/ 未装 tmux 跳过（brew bundle 未跑的新机器首启不报错）
# -c "$HOME"：tmux 1.9 起无 -c 的 new-session 默认取客户端 cwd（即终端
# 模拟器的开场目录，WeCom/IDE 常在项目深处）作会话工作目录，首窗格随之；
# 钉死 HOME。会话内新窗/分屏由 tmux.conf 的 pane_current_path 绑定跟随；
# 手动 tmux new -s 不经本钩子，仍在发起目录建，不受影响
if [[ -o interactive && -z "${TMUX:-}" ]] && command -v tmux &>/dev/null; then
    exec tmux new -c "$HOME" \; set-option destroy-unattached on
fi
