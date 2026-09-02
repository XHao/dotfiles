# 60-dfm —— dotfiles 包管理器（安装即登记，防清单漂移）
#   dfm i [--cask] <包名>...   安装并自动分组登记进 Brewfile（自动 git 提交）
#   dfm rm [--cask] <包名>...  卸载并从 Brewfile 移除（自动 git 提交）
#   dfm s                      按 Brewfile 同步（新机器 / git pull 后）
#   dfm u                      升级全家桶：pull 仓库 → 补齐 → brew → npm → omz
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

# dfm_help —— 帮助文本（h/help 与无参/未知命令共用）
dfm_help() {
    echo "dfm —— dotfiles 包管理器"
    echo "  dfm i [--cask] <包名>...   安装并自动分组登记（自动提交）"
    echo "  dfm rm [--cask] <包名>...  卸载并从 Brewfile 移除（自动提交）"
    echo "  dfm s                      按 Brewfile 同步"
    echo "  dfm u                      升级全家桶：pull 仓库 → 补齐 → brew → npm → omz"
    echo "  dfm h                      本帮助"
    echo "  （初始化/重建机器: bash ~/dotfiles/bootstrap.sh）"
}

dfm() {
    local dir="$HOME/dotfiles" bf="$HOME/dotfiles/Brewfile"
    local cmd="${1:-}"
    [[ -f "$bf" ]] || { echo "未找到 $bf" >&2; return 1; }
    case "$cmd" in
        i|install)
            shift
            local kind=brew flag=() lflag=() p canon added=()
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
                if grep -qF "${kind} \"${canon}\"" "$bf"; then
                    echo "  已登记，跳过: ${kind} \"${canon}\""
                    continue
                fi
                # 自动分组：规则匹配 → 插到分组标题下第一行；无匹配 → 待归组
                local desc target tmp
                desc="$(brew info --json=v2 "$p" 2>/dev/null | jq -r \
                    'if (.formulae|length)>0 then .formulae[0].desc else .casks[0].description // "" end' 2>/dev/null)"
                target="$(dfm_classify "$canon" "$desc")"
                tmp="$(mktemp)"
                if [[ -n "$target" ]] && grep -qF "# ---- ${target} ----" "$bf"; then
                    awk -v hdr="# ---- ${target} ----" -v entry="${kind} \"${canon}\"" \
                        '{ print } $0 == hdr { print entry }' "$bf" > "$tmp" && mv "$tmp" "$bf"
                    echo "  归组: ${kind} \"${canon}\" → ${target}"
                else
                    if ! grep -q '^# ---- dfm 登记' "$bf"; then
                        printf '\n# ---- dfm 登记（待人工归组）----\n# dfm i 自动追加到这里，定期人工挪进上面合适分组\n' >> "$bf"
                    fi
                    printf '%s "%s"\n' "$kind" "$canon" >> "$bf"
                    echo "  归组: ${kind} \"${canon}\" → 待归组（无匹配规则）"
                fi
                added+=("${kind} \"${canon}\"")
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
        s|sync)
            brew bundle --file="$bf"
            ;;
        u|up)
            local ok=() fail=() ahead npkgs
            # 1. dotfiles 仓库：脏工作区直接终止（历史干净比不断流重要）；
            #    ff-only 防意外合并提交；不自动 push（对外动作保持手动）
            if ! git -C "$dir" diff --quiet || ! git -C "$dir" diff --cached --quiet; then
                echo "✗ dotfiles 有未提交变更，先 commit / stash 后再升级:" >&2
                git -C "$dir" status --short >&2
                return 1
            fi
            echo "== dotfiles 仓库 =="
            if git -C "$dir" pull --ff-only; then ok+=("pull"); else fail+=("pull"); fi
            ahead="$(git -C "$dir" rev-list --count '@{upstream}..HEAD' 2>/dev/null)"
            (( ${ahead:-0} > 0 )) && echo "  提示: 本地领先 origin ${ahead} 个提交（如 dfm i 的自动提交），记得 push"
            # 2. 按 Brewfile 补齐（pull 带来的新条目先装上）
            echo "== Brewfile 补齐 =="
            if brew bundle --file="$bf"; then ok+=("sync"); else fail+=("sync"); fi
            # 3. brew 升级（upgrade 含 cask；bundle cleanup 删包是破坏性动作，不自动化）
            echo "== brew 升级 =="
            if brew update && brew upgrade; then ok+=("brew"); else fail+=("brew"); fi
            # 4. npm 全局工具（清单在 npm-globals.txt，与 bootstrap.sh 共享；重跑 install 即升级）
            echo "== npm 全局工具 =="
            npkgs=("${(f)$(grep -vE '^[[:space:]]*(#|$)' "$dir/npm-globals.txt" 2>/dev/null)}")
            npkgs=(${npkgs[@]:#})   # 滤掉空元素
            if (( ${#npkgs} )) && npm install -g "${npkgs[@]}"; then
                ok+=("npm")
            else
                echo "  失败（清单缺失或网络问题）" >&2
                fail+=("npm")
            fi
            # 5. omz（omz update 非交互直接更新，启动时的周期提示基本不会再遇到）
            echo "== Oh My Zsh =="
            if (( $+functions[omz] )) && omz update; then ok+=("omz"); else fail+=("omz"); fi
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
