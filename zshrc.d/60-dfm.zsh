# 60-dfm —— dotfiles 包管理器（安装即登记，防清单漂移）
#   dfm i [--cask] <包名>...   安装并自动分组登记进 Brewfile（自动 git 提交）
#   dfm rm [--cask] <包名>...  卸载并从 Brewfile 移除（自动 git 提交）
#   dfm d                      比对本机已装 vs Brewfile，fzf 挑漏登记的归组登记
#   dfm s                      按 Brewfile 同步（新机器 / git pull 后）
#   dfm u [-v|-b]              升级全家桶：pull 仓库 → 补齐 → brew → npm → omz
#                                默认安静模式（日志 ~/.dfm/upgrade.log）；
#                                -v 全量透传；-b 丢 tmux 后台窗口跑
#   dfm h                      本帮助（无参/未知命令同样显示）
# 初始化/重建机器不在此列——那是 bootstrap.sh 的职责（全新机器上 dfm 尚不存在，
# .zshrc 来自本仓库；重跑初始化 = bash ~/dotfiles/bootstrap.sh，幂等）

# dfm_classify —— 自动分组规则：包名+描述 → Brewfile 分组名
# 无匹配返回空（dfm 会落进待归组）。只放高精度关键词，宁缺勿错；
# Brewfile 新增/改名分组后，这里同步补/改规则（分组名必须与标题行完全一致）
dfm_classify() {
    local name="$1" desc="$2" s
    s="${(L)name} ${(L)desc}"                       # 全部小写化后拼接匹配
    if [[ "$s" == *font* ]]; then echo "字体"
    elif [[ "$s" == *kube* || "$s" == *k8s* || "$s" == *helm* || "$s" == *docker* || "$s" == *container* || "$s" == *podman* ]]; then echo "k8s & 容器"
    elif [[ "$s" == *java* || "$s" == *jdk* || "$s" == *jvm* || "$s" == *maven* || "$s" == *gradle* || "$s" == *kotlin* ]]; then echo "Java 开发"
    elif [[ "$s" == *golang* || "$s" == *go\ language* || "$name" == go ]]; then echo "Go 开发"
    elif [[ "$s" == *clang* || "$s" == *llvm* || "$s" == *cmake* || "$s" == *gcc* || "$s" == *ninja* || "$s" == *c++* ]]; then echo "C/C++ 开发"
    elif [[ "$s" == *python* || "$s" == *pypi* ]]; then echo "Python 开发"
    elif [[ "$s" == *zsh* ]]; then echo "Shell 增强"
    elif [[ "$s" == *fuzzy* || "$s" == *ripgrep* || "$s" == *tmux* ]]; then echo "CLI 增强"
    elif [[ "$s" == *pdf* ]]; then echo "工具"
    fi
}

# dfm_register —— 登记单个包进 Brewfile：dfm_classify 自动归组，无匹配落「待归组」；
# 已登记则跳过（返回 1）。$1 kind(brew/cask) $2 规范名 $3 描述（供分类）
# 依赖调用方 dfm() 的动态作用域局部变量 bf（与 dfm_step 同款机制）
dfm_register() {
    local kind="$1" canon="$2" desc="$3" target tmp
    if grep -qF "${kind} \"${canon}\"" "$bf"; then
        echo "  已登记，跳过: ${kind} \"${canon}\""
        return 1
    fi
    target="$(dfm_classify "$canon" "$desc")"
    tmp="$(mktemp)"
    if [[ -n "$target" ]] && grep -qF "# ---- ${target} ----" "$bf"; then
        awk -v hdr="# ---- ${target} ----" -v entry="${kind} \"${canon}\"" \
            '{ print } $0 == hdr { print entry }' "$bf" > "$tmp" && mv "$tmp" "$bf"
        echo "  归组: ${kind} \"${canon}\" → ${target}"
    else
        if ! grep -q '^# ---- dfm 登记' "$bf"; then
            printf '\n# ---- dfm 登记（待人工归组）----\n# dfm i / dfm d 自动追加到这里，定期人工挪进上面合适分组\n' >> "$bf"
        fi
        printf '%s "%s"\n' "$kind" "$canon" >> "$bf"
        echo "  归组: ${kind} \"${canon}\" → 待归组（无匹配规则）"
    fi
}

# dfm_help —— 帮助文本（h/help 与无参/未知命令共用）
dfm_help() {
    echo "dfm —— dotfiles 包管理器"
    echo "  dfm i [--cask] <包名>...   安装并自动分组登记（自动提交）"
    echo "  dfm rm [--cask] <包名>...  卸载并从 Brewfile 移除（自动提交）"
    echo "  dfm d                      比对漏登记的，fzf 挑选归组登记（自动提交）"
    echo "  dfm s                      按 Brewfile 同步"
    echo "  dfm u [-v|-b]              升级全家桶：pull 仓库 → 补齐 → brew → npm → omz"
    echo "                              默认安静：✓/✗ 逐步 + 失败带出日志尾部；"
    echo "                              全量日志 ~/.dfm/upgrade.log（tail -f 围观）"
    echo "                              -v 全量透传；-b 丢 tmux 后台窗口"
    echo "  dfm h                      本帮助"
    echo "  （初始化/重建机器: bash ~/dotfiles/bootstrap.sh）"
}

# dfm_step —— 升级流程单步执行器（依赖调用方 dfm() 的动态作用域局部变量
# verbose / log）：安静模式全量输出进日志、成功屏显一行 ✓、失败自动带出日志
# 尾部 20 行；-v 模式全量透传不落盘
dfm_step() {
    local name="$1" rc=0
    shift
    if (( verbose )); then
        echo "== ${name} =="
        "$@"
        return $?
    fi
    echo "===== [$(date '+%F %T')] ${name} =====" >> "$log"
    if "$@" >> "$log" 2>&1; then
        echo "  ✓ ${name}"
    else
        rc=$?
        echo "  ✗ ${name}（尾部如下，全量见 ${log}）" >&2
        tail -20 "$log" >&2
        return $rc
    fi
}

dfm() {
    local dir="$HOME/dotfiles" bf="$HOME/dotfiles/Brewfile"
    local cmd="${1:-}"
    [[ -f "$bf" ]] || { echo "未找到 $bf" >&2; return 1; }
    case "$cmd" in
        i|install)
            shift
            local kind=brew flag=() lflag=() p canon desc added=()
            [[ "${1:-}" == "--cask" ]] && { kind=cask; flag=(--cask); lflag=(--cask); shift; }
            if (( $# == 0 )); then
                echo "用法: dfm i [--cask] <包名>..." >&2
                return 1
            fi
            brew install "${flag[@]}" "$@" || return 1
            for p in "$@"; do
                # 解析规范名（dlv→delve、kubectl→kubernetes-cli），与 dump 输出一致
                canon="$(brew list "${lflag[@]}" --versions "$p" 2>/dev/null | awk '{print $1}')"
                canon="${canon:-$p}"
                desc="$(brew info --json=v2 "$p" 2>/dev/null | jq -r \
                    'if (.formulae|length)>0 then .formulae[0].desc else .casks[0].description // "" end' 2>/dev/null)"
                # 登记（dfm_register 内自动分组：规则匹配 → 分组标题下第一行；无匹配 → 待归组）
                dfm_register "$kind" "$canon" "$desc" && added+=("${kind} \"${canon}\"")
            done
            if (( ${#added} > 0 )); then
                git -C "$dir" add Brewfile
                git -C "$dir" commit -q -m "chore(brew): add ${added[*]}"
                echo "已提交: chore(brew): add ${added[*]}"
            fi
            ;;
        rm|remove)
            shift
            local kind=brew flag=() lflag=() p canon resolved=() removed=() tmp
            [[ "${1:-}" == "--cask" ]] && { kind=cask; flag=(--cask); lflag=(--cask); shift; }
            if (( $# == 0 )); then
                echo "用法: dfm rm [--cask] <包名>..." >&2
                return 1
            fi
            # 卸载前解析规范名（卸载后 brew list 就查不到了）
            for p in "$@"; do
                canon="$(brew list "${lflag[@]}" --versions "$p" 2>/dev/null | awk '{print $1}')"
                resolved+=("${canon:-$p}")
            done
            brew uninstall "${flag[@]}" "$@" || return 1
            tmp="$(mktemp)"
            for canon in "${resolved[@]}"; do
                if grep -qF "${kind} \"${canon}\"" "$bf"; then
                    grep -vF "${kind} \"${canon}\"" "$bf" > "$tmp" && mv "$tmp" "$bf"
                    removed+=("$canon")
                fi
            done
            if (( ${#removed} > 0 )); then
                git -C "$dir" add Brewfile
                git -C "$dir" commit -q -m "chore(brew): remove ${removed[*]}"
                echo "已提交: chore(brew): remove ${removed[*]}"
            fi
            ;;
        d|diff)
            # 比对本机已装 vs Brewfile 登记：漏登记的挑出来归组登记；反向漂移只提示
            local -a unreg_brew=() unreg_cask=() cand=() picked=() added=() missing=()
            local -A regB regC instF instC ddesc
            local p line kind rest
            command -v brew &>/dev/null || { echo "✗ 未找到 brew" >&2; return 1; }
            # 清单侧：解析 brew/cask 登记行 → 集合（assoc 下标是精确匹配，
            # 免得 python@3.14 这类名字里的 . 被 zsh 下标当通配符）
            for p in "${(f)$(grep -E '^brew "' "$bf" | sed -E 's/^brew "([^"]+)".*/\1/')}"; do regB[$p]=1; done
            for p in "${(f)$(grep -E '^cask "' "$bf" | sed -E 's/^cask "([^"]+)".*/\1/')}"; do regC[$p]=1; done
            # 本机侧：漏登记判定用 leaves——只含顶层主动安装（与 dump 同口径，依赖不上榜）；
            # 反向判定用全量列表——openjdk 这类被依赖藏进 leaves 盲区的属正常态（见其 Brewfile 注）
            for p in "${(f)$(brew leaves 2>/dev/null)}"; do [[ -n "${regB[$p]}" ]] || unreg_brew+=("$p"); done
            for p in "${(f)$(brew list --cask 2>/dev/null)}"; do [[ -n "${regC[$p]}" ]] || unreg_cask+=("$p"); done
            for p in "${(f)$(brew list --formula 2>/dev/null)}"; do instF[$p]=1; done
            for p in "${(f)$(brew list --cask 2>/dev/null)}"; do instC[$p]=1; done
            for p in "${(@k)regB}"; do [[ -n "${instF[$p]}" ]] || missing+=("brew $p"); done
            for p in "${(@k)regC}"; do [[ -n "${instC[$p]}" ]] || missing+=("cask $p"); done
            (( ${#missing} )) && echo "提示: 已登记但本机未装 ${#missing} 个: ${missing[*]}（dfm s 可补齐）"
            if (( ! ${#unreg_brew} && ! ${#unreg_cask} )); then
                echo "✓ 无漏登记（Brewfile 已覆盖本机全部 leaves 与 cask）"
                return 0
            fi
            # 批量取描述：挑选时的参考信息，也是 dfm_register 分类的输入
            if (( ${#unreg_brew} )); then
                while IFS=$'\t' read -r p line; do [[ -n "$p" ]] && ddesc[$p]="$line"; done < <(
                    brew info --json=v2 "${unreg_brew[@]}" 2>/dev/null |
                    jq -r '(.formulae // [])[] | [.name, (.desc // "")] | @tsv' 2>/dev/null)
            fi
            if (( ${#unreg_cask} )); then
                while IFS=$'\t' read -r p line; do [[ -n "$p" ]] && ddesc[$p]="$line"; done < <(
                    brew info --json=v2 --cask "${unreg_cask[@]}" 2>/dev/null |
                    jq -r '(.casks // [])[] | [.token, (.description // "")] | @tsv' 2>/dev/null)
            fi
            for p in "${unreg_brew[@]}"; do cand+=("brew"$'\t'"$p"$'\t'"${ddesc[$p]:-}"); done
            for p in "${unreg_cask[@]}"; do cand+=("cask"$'\t'"$p"$'\t'"${ddesc[$p]:-}"); done
            # 挑选：fzf Tab 多选（ESC 全放弃）；无 fzf 降级逐个 y/n；非交互终端只能列出作罢
            if command -v fzf &>/dev/null; then
                picked=("${(f)$(printf '%s\n' "${cand[@]}" |
                    fzf -m --prompt='登记> ' --header='Tab 选中要登记的 · 回车确认 · ESC 全部放弃' 2>/dev/null)}")
            elif [[ -t 0 ]]; then
                for line in "${cand[@]}"; do
                    echo "  ${line//$'\t'/ }"
                    read -q "REPLY?  登记它? (y/n) " && picked+=("$line")
                    echo
                done
            else
                echo "✗ 无 fzf 且非交互终端，无法挑选；待定项如下，之后逐个 dfm i 登记:" >&2
                printf '  %s\n' "${cand[@]//$'\t'/ }" >&2
                return 1
            fi
            picked=(${picked[@]:#})
            if (( ! ${#picked} )); then
                echo "未选中任何包，Brewfile 未改动"
                return 0
            fi
            for line in "${picked[@]}"; do
                kind="${line%%$'\t'*}"
                rest="${line#*$'\t'}"
                p="${rest%%$'\t'*}"
                dfm_register "$kind" "$p" "${ddesc[$p]:-}" && added+=("${kind} \"${p}\"")
            done
            if (( ${#added} )); then
                git -C "$dir" add Brewfile
                git -C "$dir" commit -q -m "chore(brew): add ${added[*]}"
                echo "已提交: chore(brew): add ${added[*]}"
            fi
            ;;
        s|sync)
            brew bundle --file="$bf"
            ;;
        u|up)
            shift
            local verbose=0 ok=() fail=() ahead npkgs
            while [[ "${1:-}" == -* ]]; do
                case "$1" in
                    -v) verbose=1 ;;
                    -b)
                        # tmux 后台窗口：tee 进日志（窗口内实时可见 + 留档），
                        # 跑完 display-message 提醒，回车前窗口保留摘要
                        command -v tmux &>/dev/null && [[ -n "${TMUX:-}" ]] || {
                            echo "✗ -b 需要在 tmux 会话内使用" >&2; return 1; }
                        mkdir -p "$HOME/.dfm"
                        tmux new-window -d -n "dfm升级" \
                            "dfm u -v 2>&1 | tee -a '$HOME/.dfm/upgrade.log'; tmux display-message 'dfm 升级完成（窗口保留摘要）'; echo; echo '── 回车关闭本窗口 ──'; read"
                        echo "已丢入 tmux 后台窗口「dfm升级」：前缀+n 切换围观，实时日志 tail -f ~/.dfm/upgrade.log"
                        return
                        ;;
                    *) echo "未知选项 $1（-v 全量透传 / -b 后台窗口）" >&2; return 1 ;;
                esac
                shift
            done
            # 脏工作区直接终止（历史干净比不断流重要）；ff-only 防意外合并提交；
            # 不自动 push（对外动作保持手动）
            if ! git -C "$dir" diff --quiet || ! git -C "$dir" diff --cached --quiet; then
                echo "✗ dotfiles 有未提交变更，先 commit / stash 后再升级:" >&2
                git -C "$dir" status --short >&2
                return 1
            fi
            local log="$HOME/.dfm/upgrade.log"
            (( verbose )) || { mkdir -p "$HOME/.dfm"; echo "===== dfm u $(date '+%F %T') =====" >> "$log"; }
            dfm_step "pull 仓库"    git -C "$dir" pull --ff-only && ok+=(pull) || fail+=(pull)
            ahead="$(git -C "$dir" rev-list --count '@{upstream}..HEAD' 2>/dev/null)"
            (( ${ahead:-0} > 0 )) && echo "  提示: 本地领先 origin ${ahead} 个提交（如 dfm i 的自动提交），记得 push"
            dfm_step "Brewfile 补齐" brew bundle --file="$bf" && ok+=(sync) || fail+=(sync)
            # upgrade 含 cask；bundle cleanup 删包是破坏性动作，不自动化
            dfm_step "brew update"  brew update && ok+=(update) || fail+=(update)
            dfm_step "brew upgrade" brew upgrade && ok+=(upgrade) || fail+=(upgrade)
            # npm 清单在 npm-globals.txt（与 bootstrap.sh 共享）；重跑 install 即升级
            npkgs=("${(f)$(grep -vE '^[[:space:]]*(#|$)' "$dir/npm-globals.txt" 2>/dev/null)}")
            npkgs=(${npkgs[@]:#})   # 滤掉空元素
            if (( ${#npkgs} )); then
                dfm_step "npm 全局" npm install -g "${npkgs[@]}" && ok+=(npm) || fail+=(npm)
            else
                echo "  ✗ npm 全局（清单缺失或为空）" >&2
                fail+=(npm)
            fi
            # omz update 非交互直接更新，启动时的周期提示基本不会再遇到
            if (( $+functions[omz] )); then
                dfm_step "omz" omz update && ok+=(omz) || fail+=(omz)
            else
                echo "  ✗ omz（函数未加载——不在交互 shell？）" >&2
                fail+=(omz)
            fi
            echo "升级完成: ✓ ${ok[*]:-无}  ✗ ${fail[*]:-无}"
            (( ${#fail} == 0 ))
            ;;
        h|help)
            dfm_help
            ;;
        *)
            dfm_help
            ;;
    esac
}
