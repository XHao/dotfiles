# 56-aiwin —— AI 对话窗口（tmux 前缀+A）
# 与 55-nlwin（前缀+a，NL→命令）同管道的纯问答弹窗：多轮对话、上下文自累积。
# 零工具纯文本调用: claude -p --bare --tools ''，无会话落盘无工具无权限系统，
# 行为即裸 LLM 调用；后端跟随 ai 切换器（server 环境继承，见 50-ai.zsh）。
# 上下文不走服务端会话而是整段拼进 prompt（无状态、无 agent 痕迹），
# 代价是长对话 token 递增——快速问答场景刻意如此。
# 输入行为与 nlwin 同款: vared 全编辑 + ↑/↓ 历史(~/.cache/aiwin/input_history)；
# q 退出；回答超 30 行自动进 less 滚动阅读（popup 无回滚缓冲）。

aiwin_cachedir() { print -r -- "${XDG_CACHE_HOME:-$HOME/.cache}/aiwin" }

# 调 claude 问答; 成功 stdout=回答 退出 0, 失败 stdout=原因 退出 1
aiwin_ask() {
    local out errf
    errf=$(mktemp)
    out=$(print -r -- "$1" | claude -p --bare --tools '' 2>"$errf") || {
        printf 'claude 调用失败: %.200s' "$(head -c 200 "$errf")"
        rm -f "$errf"
        return 1
    }
    rm -f "$errf"
    printf '%s' "$out"
}

# 读一行输入: 同 nlwin_readline 机制（vared 的 zle 历史在本上下文失效，自管数组）
aiwin_readline() {
    local d h ro
    d=$(aiwin_cachedir); mkdir -p "$d"
    h="$d/input_history"; ro="$d/reply"; touch "$h"
    : > "$ro"
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
vared -p "ai> " reply
printf %s "$reply" > "$REPLYF"' 2>/dev/null
    print -r -- "$(<"$ro")"
}

# popup 主循环: 多轮对话，transcript 整段随每次提问重发
aiwin() {
    local input out transcript='' full
    local -a lines
    local preamble='你是终端里的快速问答助手。回答准确、简洁，默认中文，代码放代码块。'
    while true; do
        input=$(aiwin_readline)
        [[ "$input" == q ]] && return 0
        [[ -n "$input" ]] || continue
        print -r -- "$input" >>"$(aiwin_cachedir)/input_history"
        printf '\033[2m思考中…\033[0m\n'
        full="$preamble"$'\n\n'"${transcript}用户: $input"
        if ! out=$(aiwin_ask "$full"); then
            printf '\033[31m回答失败:\033[0m %s\n' "$out"
            continue
        fi
        transcript="$full"$'\n'"助手: $out"$'\n\n'
        lines=("${(f)out}")
        if (( ${#lines[@]} > 30 )); then
            print -r -- "$out" | less -R
        else
            printf '%s\n' "$out"
        fi
        printf '\033[2m—— 继续提问，q 退出 ——\033[0m\n'
    done
}

# 脚本模式: popup 里被 `zsh 本文件` 直调（toplevel）；.zshrc source 时只定义函数
[[ "$ZSH_EVAL_CONTEXT" == toplevel ]] && aiwin "$@"
