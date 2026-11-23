# 61-checkup —— 启动体检：dotfiles 仓的 omz 式启动问句（脏区 / 落后 origin）
# 动因：双机流转两端会漂移——push 侧忘提交、pull 侧忘 dfm u。每个新 shell 的
# 首个提示符前体检一次（precmd 触发后自注销），命中才问、答完才出提示符：
#   1) 脏工作区：status 概览 + diff 进 less 看货 → [c]提交（add -A 后开编辑器
#      写信息，新文件一并收）[d]放弃跟踪改动（reset --hard，未跟踪不动）[回车]跳过
#   2) 落后 origin：问「升级? (y/N)」→ y 前台跑全量 dfm u；脏区未了结时附注
#      dfm u 会拒绝——所以脏区问句在前
#   3) 本地领先 origin：只提醒不代 push（不自动 push 硬约束）
# 节流（防每窗格轰炸）：
#   - fetch 每天最多一次（ssh ConnectTimeout=5 + BatchMode，失败静默——记号照写，
#     网络挂时不每窗格白付 5s 连接超时）
#   - 同一状态只问一次：落后:领先:(porcelain+diff 指纹) 记入 ~/.dfm/checkup.state，
#     记号先写后问（Ctrl-C 中断 ≈ 跳过，同样只打扰一次）
# 非交互 shell 不触发（-o interactive 守卫；nlwin/aiwin popup 的 zsh -f 天然
# 不加载本模块）。范围仅 ~/dotfiles 仓；本地检查毫秒级。
# 测试（同 dfm helper 惯例）：checkup_run 接仓路径参数；状态文件可经
# CHECKUP_STATEFILE 注入；dfm 可被同名函数桩替换。

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
    local today today_mark last_fetch last_state reply
    today=$(date +%Y%m%d)
    today_mark="last_fetch=$today"
    last_fetch=$(grep -m1 '^last_fetch=' "$statef" 2>/dev/null)
    last_state=$(grep -m1 '^last_state=' "$statef" 2>/dev/null)

    # ---- 远端检查：fetch 日节流，失败静默 ----
    # 记号无条件先写（含状态未变的早退路径——否则同状态日复一日每窗格都重付
    # fetch；且先写后 fetch，fetch 中途 Ctrl-C / 网络挂都不再重试）；重写时
    # 保留 last_state，否则「同状态只问一次」被每日重置
    if [[ "$last_fetch" != "$today_mark" ]]; then
        mkdir -p "${statef:h}" 2>/dev/null
        { print -r -- "$today_mark" > "$statef"
          [[ -n "$last_state" ]] && print -r -- "$last_state" >> "$statef"; } 2>/dev/null
        GIT_SSH_COMMAND='ssh -o ConnectTimeout=5 -o BatchMode=yes' \
            git -C "$dir" fetch --quiet 2>/dev/null
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
    { print -r -- "$today_mark" > "$statef"; print -r -- "$state_line" >> "$statef"; } 2>/dev/null

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
