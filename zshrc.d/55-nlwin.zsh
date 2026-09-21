# 55-nlwin —— 自然语言命令窗口
# 入口: tmux 前缀+a（.tmux.conf 调起；目标窗格经 NLWIN_TARGET 环境变量传入）
#       或 shell 里 nlwin [pane] [cwd]（函数模式，用法调试用）
# 输入行为 vared 全编辑(方向键)；↑/↓ 浏览历史(~/.cache/nlwin/input_history)；
# 相同 NL 命中翻译缓存(~/.cache/nlwin/cache, 500 条滚动)则跳过 claude 调用；q 退出。
# 翻译是零工具纯文本变换: prompt 走 stdin, claude -p --bare --tools ''，
# --disallowedTools/--tools 均为 variadic 会吞位置参数，故 prompt 只能走 stdin；
# "" 即禁用全部工具，模型上下文里没有任何工具，权限模式无意义；
# tmux 3.7c 的 display-popup 对参数不做 #{} 格式展开、popup 内 TMUX_PANE/{last}
# 均不可用，故由绑定先 run-shell 把触发窗格 %id 暂存进 server 环境变量
# NLWIN_TARGET，popup 进程（server 派生）继承之；显式 %id 目标无上下文也可解析。
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

# 缓存目录（懒创建）
nlwin_cachedir() { print -r -- "${XDG_CACHE_HOME:-$HOME/.cache}/nlwin" }

# 读一行输入: vared 子壳=全 zle 编辑(←/→/Home/End), ↑/↓ 为自管历史 widget
# 结果经文件传递, 与 zle 的 tty 绘制流解耦; vared 中断(如 Ctrl-C)读到空文件安全回落
nlwin_readline() {
    local d h ro
    d=$(nlwin_cachedir); mkdir -p "$d"
    h="$d/input_history"; ro="$d/reply"; touch "$h"
    : > "$ro"
    # vared 的 zle 历史机制在本上下文实测不召回(fc -R/fc -p 均失效), 改自管数组:
    # nlhist 末位=最新, nli=0 表示"当前新输入"; ↑ 向旧走, ↓ 向新走, 到头清空回新输入
    NLHIST="$h" REPLYF="$ro" zsh -f -i -c '
typeset -a nlhist
typeset -i nli=0
nlhist=("${(@f)$(<"$NLHIST")}")
nl-up() { if (( nli < $#nlhist )); then ((nli++)); BUFFER=${nlhist[-nli]}; CURSOR=$#BUFFER; fi }
nl-down() { if (( nli > 1 )); then ((nli--)); BUFFER=${nlhist[-nli]}; CURSOR=$#BUFFER; else nli=0; BUFFER=""; fi }
zle -N nl-up
zle -N nl-down
bindkey "\e[A" nl-up
bindkey "\e[B" nl-down
reply=""
vared -p "nl> " reply
printf %s "$reply" > "$REPLYF"' 2>/dev/null
    print -r -- "$(<"$ro")"
}

# 翻译缓存: NL 精确命中(首字段 awk 比对, 无正则陷阱)
# FS 经 printf '\037' 注入真实 0x1f 字节: 本机 BWK awk 不解析 -F 的 \x/\0 转义
nlwin_cache_get() {
    local f v
    f="$(nlwin_cachedir)/cache"
    [[ -r "$f" ]] || return 1
    v=$(awk -F "$(printf '\037')" -v k="$1" '$1==k {print $2; exit}' "$f")
    [[ -n "$v" ]] || return 1
    print -r -- "$v"
}

nlwin_cache_put() {
    # $1=NL $2=cmd; 多行命令不缓存(发送不受影响)
    [[ "$2" == *$'\n'* ]] && return 0
    local d f; d=$(nlwin_cachedir); mkdir -p "$d"; f="$d/cache"; touch "$f"
    awk -F "$(printf '\037')" -v k="$1" '$1!=k' "$f" >"$f.tmp" && mv "$f.tmp" "$f"
    print -r -- "$1"$'\x1f'"$2" >>"$f"
    tail -n 500 "$f" >"$f.tmp" && mv "$f.tmp" "$f"
}

# popup 主循环
nlwin() {
    if (( $# > 2 )); then
        echo "用法: nlwin [目标pane] [cwd]（tmux 前缀+a 调起时目标取 NLWIN_TARGET）" >&2
        return 1
    fi
    local target="$1" cwd="$2" input cmd resp edited
    [[ -n "$target" ]] || target="${NLWIN_TARGET:-}"
    if [[ -z "$cwd" ]]; then
        cwd=$(tmux display -p -t "$target" '#{pane_current_path}' 2>/dev/null)
    fi
    if [[ ! -d "$cwd" ]]; then
        printf '\033[33m目录不存在: %s，已回退 $HOME\033[0m\n' "${cwd:-<查询失败>}"
        cwd=$HOME
    fi
    while true; do
        input=$(nlwin_readline)
        [[ -n "$input" ]] || continue
        [[ "$input" == q ]] && return 0
        print -r -- "$input" >>"$(nlwin_cachedir)/input_history"
        local cached
        if cached=$(nlwin_cache_get "$input"); then
            cmd="$cached"
            printf '\033[2m(缓存)\033[0m\n'
        else
            printf '\033[2m翻译中…\033[0m\n'
            cmd=$(nlwin_translate "$cwd" "$input")
            if (( $? != 0 )); then
                printf '\033[31m翻译失败:\033[0m %s\n' "$cmd"
                continue
            fi
            nlwin_cache_put "$input" "$cmd"
        fi
        printf '\033[32m→ %s\033[0m\n' "$cmd"
        printf '[Enter]发送  [e]编辑  [其他键]取消 '
        read -rk1 resp
        case "$resp" in
            $'\n') nlwin_send "$target" "$cmd"; return 0 ;;
            e)  printf '\n'
                edited=$(reply="$cmd" zsh -f -i -c 'vared -p "编辑(回车保留): " reply; print -r -- "$reply"' 2>/dev/null)
                [[ -n "$edited" ]] && cmd="$edited"
                nlwin_send "$target" "$cmd"; return 0 ;;
            *)  return 0 ;;
        esac
    done
}

# 脚本模式: popup 里被 `zsh 本文件 <pane> <cwd>` 直调;
# 被 .zshrc source 时无参数,只定义上面的函数
(( $# )) && nlwin "$@"
