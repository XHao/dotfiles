# 60-dfm —— dotfiles 包管理器（安装即登记，防清单漂移）
#   dfm i [--cask] <包名>...   安装并自动分组登记进 Brewfile（自动 git 提交）
#   dfm rm [--cask] <包名>...  卸载并从 Brewfile 移除（自动 git 提交）
#   dfm s                      按 Brewfile 同步（新机器 / git pull 后）
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
    elif [[ "$s" == *fuzzy* || "$s" == *ripgrep* ]]; then echo "CLI 增强"
    elif [[ "$s" == *pdf* ]]; then echo "工具"
    fi
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
        *)
            echo "dfm —— dotfiles 包管理器"
            echo "  dfm i [--cask] <包名>...   安装并自动分组登记（自动提交）"
            echo "  dfm rm [--cask] <包名>...  卸载并从 Brewfile 移除（自动提交）"
            echo "  dfm s                      按 Brewfile 同步"
            echo "  （初始化/重建机器: bash ~/dotfiles/bootstrap.sh）"
            ;;
    esac
}
