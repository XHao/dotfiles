# 55-nlwin —— 自然语言命令窗口
# 入口: tmux 前缀+a（.tmux.conf 调起，脚本模式直跑本文件）
#       或 shell 里 nlwin <目标pane> <cwd>（函数模式，用法调试用）
# 翻译是零工具纯文本变换: prompt 走 stdin, claude -p --bare --tools ''，
# --disallowedTools/--tools 均为 variadic 会吞位置参数，故 prompt 只能走 stdin；
# "" 即禁用全部工具，模型上下文里没有任何工具，权限模式无意义；
# 后端跟随 ai 切换器（server 环境同步见 50-ai.zsh）。

# 清洗 claude 输出: 首尾 trim / 整体围栏剥壳 / 去行首 "$ "
nlwin_clean() {
    local s="$1" first
    s="${s#"${s%%[![:space:]]*}"}"
    s="${s%"${s##*[![:space:]]}"}"
    if [[ "$s" == '```'* && "$s" == *'```' ]]; then
        first="${s%%$'\n'*}"
        s="${s#"$first"$'\n'}"
        s=${s%$'\n''```'}
        s="${s#"${s%%[![:space:]]*}"}"
        s="${s%"${s##*[![:space:]]}"}"
    fi
    [[ "$s" == '$ '* ]] && s="${s#'$ '}"
    printf '%s' "$s"
}

# 调 claude 翻译; 成功 stdout=命令 退出 0, 失败 stdout=原因 退出 1
nlwin_translate() {
    local out cmd errf
    errf=$(mktemp)
    out=$(cd "$1" && print -r -- "你在 macOS 的 zsh 环境里。当前工作目录: $1。把下面的自然语言翻译成一条可以直接在 zsh 执行的命令。只输出命令本身,不要解释,不要 markdown 代码块。无法翻译成命令时,只输出一行 ERROR: 原因。自然语言: $2" | claude -p --bare --tools '' 2>"$errf") || {
        printf 'claude 调用失败: %.200s' "$(head -c 200 "$errf")"
        rm -f "$errf"
        return 1
    }
    rm -f "$errf"
    cmd=$(nlwin_clean "$out")
    if [[ -z "$cmd" || "$cmd" == ERROR:* ]]; then
        printf '%s' "${cmd:-claude 空输出}"
        return 1
    fi
    printf '%s' "$cmd"
}

# 发送: 目标窗格空闲(zsh/bash)则字面量发送+回车, 否则进剪贴板绝不盲发
nlwin_send() {
    local target="$1" cmd="$2" cur
    if ! cur=$(tmux display -p -t "$target" '#{pane_current_command}' 2>/dev/null) || [[ -z "$cur" ]]; then
        printf '\033[33m目标窗格已不存在，按任意键关闭\033[0m\n'
        read -rk1 '?'
        return 1
    fi
    if [[ "$cur" == zsh || "$cur" == bash ]]; then
        tmux send-keys -t "$target" C-u
        tmux send-keys -t "$target" -l -- "$cmd"
        tmux send-keys -t "$target" Enter
    else
        printf '%s' "$cmd" | pbcopy
        printf '\033[33m目标窗格正在跑 %s(非 shell),命令已进剪贴板\033[0m\n' "$cur"
        read -rk1 '?按任意键关闭'
    fi
}

# popup 主循环
nlwin() {
    if (( $# != 2 )); then
        echo "用法: nlwin <目标pane_id> <cwd>（通常由 tmux 前缀+a 调起）" >&2
        return 1
    fi
    local target="$1" cwd="$2" input cmd resp edited
    if [[ ! -d "$cwd" ]]; then
        printf '\033[33m目录不存在: %s，已回退 $HOME\033[0m\n' "$cwd"
        cwd=$HOME
    fi
    while true; do
        printf '\033[1mnl>\033[0m '
        read -r input || return 0          # Ctrl-D 直接退出
        [[ -n "$input" ]] || continue
        printf '\033[2m翻译中…\033[0m\n'
        cmd=$(nlwin_translate "$cwd" "$input")
        if (( $? != 0 )); then
            printf '\033[31m翻译失败:\033[0m %s\n' "$cmd"
            continue
        fi
        printf '\033[32m→ %s\033[0m\n' "$cmd"
        printf '[Enter]发送  [e]编辑  [其他键]取消 '
        read -rk1 resp
        case "$resp" in
            $'\n') nlwin_send "$target" "$cmd"; return 0 ;;
            e)  printf '\n编辑(回车保留原命令): '
                read -re edited
                [[ -n "$edited" ]] && cmd="$edited"
                nlwin_send "$target" "$cmd"; return 0 ;;
            *)  return 0 ;;
        esac
    done
}

# 脚本模式: popup 里被 `zsh 本文件 <pane> <cwd>` 直调;
# 被 .zshrc source 时无参数,只定义上面的函数
(( $# )) && nlwin "$@"
