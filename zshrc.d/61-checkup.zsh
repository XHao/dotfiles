# 61-checkup —— 启动体检：dotfiles 仓的 omz 式启动问句（脏区 / 落后 origin）
# 动因：双机流转两端会漂移——push 侧忘提交、pull 侧忘 dfm u。每个新 shell 的
# 首个提示符前体检一次（precmd 触发后自注销），命中才问、答完才出提示符：
#   1) 脏工作区：status 概览 + diff 进 less 看货 → [c]提交（add -A 后开编辑器
#      写信息，新文件一并收）[d]放弃跟踪改动（reset --hard，未跟踪不动）[回车]跳过
#   2) 落后 origin：问「升级? (y/N)」→ y 前台跑全量 dfm u；脏区未了结时附注
#      dfm u 会拒绝——所以脏区问句在前
#   3) 本地领先 origin：只提醒不代 push（不自动 push 硬约束）
# 节流（防每窗格轰炸）：
#   - 远端检查按间隔后台 fetch：CHECKUP_FETCH_INTERVAL 小时数（默认 24，0=禁用
#     远端检查）。fetch 走 ( … &! ) 孤儿后台——不阻塞提示符、窗格关掉也跑完、
#     交互 shell 不刷 [1] PID 作业行；记号（epoch 秒）同步先写，后台在飞时后续
#     窗格凭新记号不再发；失败静默（ssh ConnectTimeout=5 + BatchMode），下个
#     间隔才重试。代价：落后判定滞后一个 shell（本窗格读的是上次 fetch 的 refs，
#     远端新提交下一窗格才问）
#   - 同一状态只问一次：落后:领先:(porcelain+diff 指纹) 记入 ~/.dfm/checkup.state，
#     记号先写后问（Ctrl-C 中断 ≈ 跳过，同样只打扰一次）
# 非交互 shell 不触发（-o interactive 守卫；nlwin/aiwin popup 的 zsh -f 天然
# 不加载本模块）。范围仅 ~/dotfiles 仓；本地检查毫秒级。
# 测试（同 dfm helper 惯例）：checkup_run 接仓路径参数；状态文件可经
# CHECKUP_STATEFILE 注入；间隔经 CHECKUP_FETCH_INTERVAL 注入；dfm/git 均可被
# 同名函数桩替换（后台 fetch 计数须走日志文件——子进程改不了父 shell 变量）。

# ---- 单键应答：tty 下 read -k 即敲即答（read -k 只认终端）；stdin 非 tty
#      （重定向/管道，如自动化测试、`zsh -i < file`）回落行读，答案语义不变 ----
checkup_readkey() {
    local r
    if [[ -t 0 ]]; then
        read -rk1 r
    else
        read -r r
    fi
    print -r -- "$r"
}

# ---- 主流程：$1 = 仓路径（默认 ~/dotfiles） ----
checkup_run() {
    local dir="${1:-$HOME/dotfiles}"
    [[ -d "$dir/.git" ]] || return 0
    local statef="${CHECKUP_STATEFILE:-$HOME/.dfm/checkup.state}"
    local mark_line last_fetch last_state reply
    last_fetch=$(grep -m1 '^last_fetch=' "$statef" 2>/dev/null)
    last_state=$(grep -m1 '^last_state=' "$statef" 2>/dev/null)
    mark_line="$last_fetch"   # 状态变化重写时原样保留；fetch 时更新为本次时间戳

    # ---- 远端检查：间隔节流 + 孤儿后台 fetch ----
    # CHECKUP_FETCH_INTERVAL：间隔小时数，默认 24；0 = 禁用（纯本地检查）。
    # 记号（epoch 秒）同步先写：后台在飞时后续窗格凭新记号不再发；失败静默，
    # 下个间隔才重试。旧 8 位 YYYYMMDD 记号视为过期，首个 shell 刷新为 epoch。
    local interval="${CHECKUP_FETCH_INTERVAL:-24}" lf_val last_ep=0 now
    interval=${interval//[!0-9]/}
    interval=$(( 10#${interval:-24} ))
    lf_val="${last_fetch#last_fetch=}"
    [[ "$lf_val" =~ '^[0-9]{10}$' ]] && last_ep="$lf_val"
    now=$(date +%s)
    if (( interval > 0 && now - last_ep >= interval * 3600 )); then
        mark_line="last_fetch=$now"
        mkdir -p "${statef:h}" 2>/dev/null
        { print -r -- "$mark_line"
          [[ -n "$last_state" ]] && print -r -- "$last_state"; } > "$statef" 2>/dev/null
        ( GIT_SSH_COMMAND='ssh -o ConnectTimeout=5 -o BatchMode=yes' \
            git -C "$dir" fetch --quiet >/dev/null 2>&1 </dev/null &! )
    fi

    # ---- 三态采集（毫秒级本地 git）----
    local behind=0 ahead=0 st fp state_line
    behind=$(git -C "$dir" rev-list --count 'HEAD..@{upstream}' 2>/dev/null)
    behind=${behind:-0}
    ahead=$(git -C "$dir" rev-list --count '@{upstream}..HEAD' 2>/dev/null)
    ahead=${ahead:-0}
    st=$(git -C "$dir" status --porcelain -uall 2>/dev/null)
    if [[ -n "$st" ]]; then
        # 指纹含 diff 内容：同一文件继续改出新内容 = 新状态，会再问
        fp=$({ print -r -- "$st"; git -C "$dir" diff HEAD 2>/dev/null; } | shasum | cut -c1-12)
    else
        fp="clean"
    fi
    state_line="last_state=${behind}:${ahead}:${fp}"

    # ---- 同状态静默；记号先写后问 ----
    [[ "$last_state" == "$state_line" ]] && return 0
    mkdir -p "${statef:h}" 2>/dev/null
    # 重写保留原 fetch 记号：未到点/禁用时不得谎盖章（否则顺延下个间隔）
    { [[ -n "$mark_line" ]] && print -r -- "$mark_line"
      print -r -- "$state_line"; } > "$statef" 2>/dev/null

    # ---- 1) 脏工作区：先看货再决策 ----
    if [[ -n "$st" ]]; then
        local untracked
        untracked=$(print -r -- "$st" | grep -c '^??' || true)
        printf '\033[33m⚠ dotfiles 有未提交改动:\033[0m\n'
        git -C "$dir" status --short
        if ! git -C "$dir" diff --quiet HEAD 2>/dev/null; then
            printf '\033[2m（diff 如下，less 里 q 退出翻页）\033[0m\n'
            git -C "$dir" diff HEAD
        fi
        printf '\033[33m如何处理?\033[0m [c]提交(进编辑器写信息) [d]放弃跟踪改动 [回车]跳过 '
        reply=$(checkup_readkey)
        (( $#reply )) && print ""
        case "$reply" in
            c|C)
                git -C "$dir" add -A
                if git -C "$dir" commit 2>/dev/null; then
                    printf '\033[32m✓ 已提交 %s\033[0m\n' \
                        "$(git -C "$dir" log -1 --format='%h %s')"
                else
                    printf '\033[33m提交未完成（空信息?），改动仍在\033[0m\n'
                fi
                ;;
            d|D)
                # reset --hard 而非 checkout -- .：staged 改动一并放弃（checkout -- .
                # 只还原工作区，暂存区残留）；未跟踪/忽略文件 reset 天然不动
                git -C "$dir" reset --hard HEAD --quiet
                printf '\033[32m✓ 已放弃跟踪改动\033[0m'
                (( untracked > 0 )) && printf '（未跟踪 %d 个新文件未动）' "$untracked"
                print ""
                ;;
        esac
    fi

    # ---- 2) 落后 origin：y → 全量 dfm u 前台 ----
    if (( behind > 0 )); then
        st=$(git -C "$dir" status --porcelain -uall 2>/dev/null)   # c/d 可能已了结脏区
        [[ -n "$st" ]] && printf '\033[2m（脏区未了结，dfm u 会拒绝）\033[0m\n'
        printf '\033[33m⚠ dotfiles 落后 origin %d 个提交，升级? (y/N)\033[0m ' "$behind"
        reply=$(checkup_readkey)
        (( $#reply )) && print ""
        [[ "$reply" == y || "$reply" == Y ]] && dfm u
    fi

    # ---- 3) 领先未 push：只提醒（c 提交后重算）----
    ahead=$(git -C "$dir" rev-list --count '@{upstream}..HEAD' 2>/dev/null)
    ahead=${ahead:-0}
    (( ahead > 0 )) && \
        printf '\033[33m⚠ dotfiles 本地领先 origin %d 个提交，记得 push\033[0m\n' "$ahead"
}

# ---- precmd 入口：一次性，先自注销再干活 ----
checkup_boot() {
    add-zsh-hook -d precmd checkup_boot
    checkup_run "$HOME/dotfiles"
}

# 交互 shell 才注册（脚本/管道/popup 的 zsh -f 均不触发）
if [[ -o interactive ]]; then
    autoload -Uz add-zsh-hook
    add-zsh-hook precmd checkup_boot
fi
