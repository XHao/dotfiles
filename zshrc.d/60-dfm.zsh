# 60-dfm —— dotfiles 包管理器（安装即登记，防清单漂移）
#   dfm i [--cask] <包名>...   安装并自动分组登记进 Brewfile（自动 git 提交）
#   dfm rm [--cask] <包名>...  卸载并从 Brewfile 移除（自动 git 提交）
#   dfm d                      比对本机已装 vs Brewfile，fzf 挑漏登记的归组登记
#   dfm dr                     环境体检：软链/克隆资产/清单漂移/工作区清洁度（✗ 时退出码非 0）
#   dfm s                      按 Brewfile 同步（新机器 / git pull 后）
#   dfm u [-v]                 升级全家桶：pull 仓库 → 机器侧安装(软链/克隆/tmux) → 补齐 → brew → npm → omz
#                                默认安静模式（日志 ~/.dfm/upgrade.log，✓/✗ 落档）；
#                                -v 全量透传不落盘
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

# dfm_brew_sets —— 构建 Brewfile 登记侧（regB/regC）与本机安装侧（instF/instC）
# 双向集合，dfm d 与 dfm dr 共用（口径单一，防双份漂移）。依赖调用方 dfm()
# 动态作用域的局部变量 bf，回填调用方已 local 声明的四个关联数组（与
# dfm_register 借用 bf 同款机制；assoc 下标精确匹配，免得 python@3.14 这类
# 名字里的 . 被 zsh 下标当通配符）
dfm_brew_sets() {
    local p
    # [[ -n ]] 守卫：zsh 的 ${(f)""} 产出单个空串元素而非空数组，不滤会种出 "" 假键
    for p in "${(f)$(grep -E '^brew "' "$bf" | sed -E 's/^brew "([^"]+)".*/\1/')}"; do [[ -n "$p" ]] && regB[$p]=1; done
    for p in "${(f)$(grep -E '^cask "' "$bf" | sed -E 's/^cask "([^"]+)".*/\1/')}"; do [[ -n "$p" ]] && regC[$p]=1; done
    for p in "${(f)$(brew list --formula 2>/dev/null)}"; do [[ -n "$p" ]] && instF[$p]=1; done
    for p in "${(f)$(brew list --cask 2>/dev/null)}"; do [[ -n "$p" ]] && instC[$p]=1; done
}

# dfm_help —— 帮助文本（h/help 与无参/未知命令共用）
dfm_help() {
    echo "dfm —— dotfiles 包管理器"
    echo "  dfm i [--cask] <包名>...   安装并自动分组登记（自动提交）"
    echo "  dfm rm [--cask] <包名>...  卸载并从 Brewfile 移除（自动提交）"
    echo "  dfm d                      比对漏登记的，fzf 挑选归组登记（自动提交）"
    echo "  dfm dr                     环境体检：软链/克隆资产/清单漂移/工作区清洁度，只报告不改动"
    echo "  dfm s                      按 Brewfile 同步"
    echo "  dfm u [-v]                 升级全家桶：pull 仓库 → 机器侧安装(软链/克隆/tmux) → 补齐 → brew → npm → omz"
    echo "                              默认安静：✓/✗ 逐步 + 失败带出日志尾部；"
    echo "                              全量日志 ~/.dfm/upgrade.log（tail -f 围观）"
    echo "                              -v 全量透传不落盘"
    echo "  dfm h                      本帮助"
    echo "  （初始化/重建机器: bash ~/dotfiles/bootstrap.sh）"
}

# dfm_step —— 升级流程单步执行器（依赖调用方 dfm() 的动态作用域局部变量
# verbose / log）：安静模式全量输出进日志、✓/✗ 判定屏显且落档（历史运行可
# 凭日志判读成败）、失败自动带出日志尾部 20 行；-v 模式全量透传不落盘
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
        echo "  ✓ ${name}" >> "$log"
    else
        rc=$?
        echo "  ✗ ${name}" >> "$log"
        echo "  ✗ ${name}（尾部如下，全量见 ${log}）" >&2
        tail -20 "$log" >&2
        return $rc
    fi
}

# dfm_omz_update —— 无重启版 omz 更新
# 等价官方 _omz::update 的「跑 upgrade.sh + 写 LAST_EPOCH + 清 update.lock」，
# 刻意省略其末尾的 exec 重启 shell：函数在 dfm_step 的 >> log 2>&1 之下执行，
# exec 会带着被重定向的 stdout/stderr 替换进程，fd 再无恢复机会（2026-10-07
# 事故根因）；新版 omz 由后续新开的 shell 自然加载
dfm_omz_update() {
    local zsh_dir="$HOME/.oh-my-zsh"
    [[ -d "$zsh_dir/.git" ]] || { echo "✗ $zsh_dir 不是 git 目录" >&2; return 1; }
    ZSH="$zsh_dir" command zsh -f "$zsh_dir/tools/upgrade.sh" || return $?
    local cache_dir="${ZSH_CACHE_DIR:-$zsh_dir/cache}"
    mkdir -p "$cache_dir"
    echo "LAST_EPOCH=$(( $(date +%s) / 86400 ))" > "$cache_dir/.zsh-update"
    command rm -rf "$zsh_dir/log/update.lock"
}

# dfm_apply —— 机器侧安装（幂等、秒级、非交互）：建软链 + 补克隆 + 刷 tmux。
# dr 只探测、这里开药；与 bootstrap 步骤 5/6 同清单同口径（clones.txt /
# link-paths.txt），由 dfm u 在 pull 后调用——pull 到货 ≠ 装进系统，
# 「仓库有、机器无」的缺口全靠这一步收口（2026-10-01 状态栏事故的教训）
dfm_apply() {
    local dir="$HOME/dotfiles" p src dst cpath curl fail=0 n=0
    # ---- 软链（语义同 bootstrap 步骤 6：已链跳过，原文件备份让位）----
    if [[ -f "$dir/link-paths.txt" ]]; then
        while IFS= read -r p; do
            [[ "$p" == '#'* || -z "${p//[[:space:]]/}" ]] && continue
            src="$dir/$p"; dst="$HOME/$p"
            if [[ ! -e "$src" ]]; then
                echo "  ✗ 软链 $p：仓库中缺失，跳过" >&2
                continue
            fi
            [[ "$(readlink "$dst" 2>/dev/null)" == "$src" ]] && continue
            if [[ -e "$dst" && ! -L "$dst" ]]; then
                mv "$dst" "${dst}.bak.$(date +%Y%m%d%H%M%S)"
                echo "  ⚠ ~/$p 原文件已备份让位"
            fi
            mkdir -p "$(dirname "$dst")"
            ln -sfn "$src" "$dst"
            echo "  + 软链 ~/$p"
            (( n+=1 ))
        done < "$dir/link-paths.txt"
    fi
    # ---- 克隆（只装不更：已存在跳过；SSH 优先、失败回退 HTTPS——同 bootstrap 步骤 5）----
    if [[ -f "$dir/clones.txt" ]]; then
        while read -r cpath curl; do
            [[ "$cpath" == '#'* || -z "${cpath//[[:space:]]/}" ]] && continue
            [[ -n "$curl" ]] || { echo "  ✗ 克隆 $cpath：清单行缺 URL，跳过" >&2; continue; }
            [[ -d "$HOME/$cpath/.git" ]] && continue
            echo "  + 克隆 ~/$cpath ..."
            mkdir -p "$(dirname "$HOME/$cpath")"
            if ! git clone --depth=1 "git@github.com:${curl#https://github.com/}" "$HOME/$cpath" 2>/dev/null; then
                git clone --depth=1 "$curl" "$HOME/$cpath" || {
                    echo "  ✗ 克隆 ~/$cpath 失败，稍后手动: git clone $curl ~/$cpath" >&2
                    fail=1
                    continue
                }
            fi
            (( n+=1 ))
        done < "$dir/clones.txt"
    fi
    # ---- tmux 刷新（在 tmux 内才刷；不在则新服务器启动时自然读取）----
    if [[ -n "${TMUX:-}" && -f "$HOME/.tmux.conf" ]]; then
        tmux source-file "$HOME/.tmux.conf" 2>/dev/null \
            && { echo "  + tmux 配置已刷新（状态栏即刻生效）"; (( n+=1 )); }
    fi
    (( fail )) && return 1
    (( n == 0 )) && echo "  = 机器侧已就绪，无需变更"
    return 0
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
            # 双向集合：dfm_brew_sets 单一实现（与 dfm dr 共用，防口径漂移）
            # 漏登记判定用 leaves——只含顶层主动安装（与 dump 同口径，依赖不上榜）；
            # 反向判定用全量列表——openjdk 这类被依赖藏进 leaves 盲区的属正常态（见其 Brewfile 注）
            dfm_brew_sets
            for p in "${(f)$(brew leaves 2>/dev/null)}"; do [[ -n "${regB[$p]}" ]] || unreg_brew+=("$p"); done
            for p in "${(@k)instC}"; do [[ -n "${regC[$p]}" ]] || unreg_cask+=("$p"); done
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
        dr|doctor)
            # 环境体检（非交互、只报告不改动）：软链完整 / 克隆资产 / myvim 链 /
            # Brewfile 与 npm 双向漂移 / 工作区清洁度。有 ✗ 时退出码非 0（可挂
            # 脚本）；修复动作各自指向 dfm u（软链/克隆自动补装）/ dfm d（漏
            # 登记）/ dfm s（漏装）
            local -a missing=() unreg_brew=() unreg_cask=() unreg_all=() npm_missing=() npm_extra=()
            local -A regB regC regN instF instC instN
            local p fails=0 warns=0
            # ---- 软链完整（清单与 bootstrap 共享 link-paths.txt，防双份漂移）----
            if [[ -f "$dir/link-paths.txt" ]]; then
                while IFS= read -r p; do
                    # 语法与 bootstrap 步骤 6 完全同口径：# 顶格注释、空行/纯空白行跳过
                    [[ "$p" == '#'* || -z "${p//[[:space:]]/}" ]] && continue
                    if [[ ! -e "$dir/$p" ]]; then
                        echo "✗ 软链 $p：仓库中缺失"
                        (( fails+=1 ))
                    elif [[ "$(readlink "$HOME/$p" 2>/dev/null)" == "$dir/$p" ]]; then
                        echo "✓ 软链 $p"
                    elif [[ -e "$HOME/$p" || -L "$HOME/$p" ]]; then
                        echo "⚠ 软链 $p：目标存在但非本仓链接（本机私有文件？bootstrap 会备份后替换）"
                        (( warns+=1 ))
                    else
                        echo "✗ 软链 $p：缺失 → dfm u 自动补装（或 bash ~/dotfiles/bootstrap.sh）"
                        (( fails+=1 ))
                    fi
                done < "$dir/link-paths.txt"
            else
                echo "✗ link-paths.txt 缺失（仓库不完整？）"
                (( fails+=1 ))
            fi
            # ---- 外部克隆资产（清单与 bootstrap 步骤 5 / dfm u 共享 clones.txt）----
            if [[ -f "$dir/clones.txt" ]]; then
                while read -r cpath curl; do
                    [[ "$cpath" == '#'* || -z "${cpath//[[:space:]]/}" ]] && continue
                    if [[ -d "$HOME/$cpath/.git" ]]; then
                        echo "✓ 克隆 $cpath"
                    else
                        echo "✗ 克隆 $cpath：缺失 → git clone $curl ~/$cpath（dfm u 自动补装）"
                        (( fails+=1 ))
                    fi
                done < "$dir/clones.txt"
            else
                echo "✗ clones.txt 缺失（仓库不完整？）"
                (( fails+=1 ))
            fi
            # ---- myvim 的 ~/.vimrc 链（归 myvim 管，不在 link-paths.txt）----
            if [[ -d "$HOME/.vim/.git" ]]; then
                if [[ "$(readlink "$HOME/.vimrc" 2>/dev/null)" == "$HOME/.vim/.vimrc" ]]; then
                    echo "✓ ~/.vimrc → myvim"
                else
                    echo "✗ ~/.vimrc 软链缺失 → make -C ~/.vim vimrc"
                    (( fails+=1 ))
                fi
            fi
            # ---- Brewfile 双向漂移（集合构建与 dfm d 共用 dfm_brew_sets，口径单一）----
            if command -v brew &>/dev/null; then
                dfm_brew_sets
                # 漏装：已登记未装（全量口径——依赖藏进 leaves 盲区的属正常，见 dfm d 注）
                for p in "${(@k)regB}"; do [[ -n "${instF[$p]}" ]] || missing+=("brew $p"); done
                for p in "${(@k)regC}"; do [[ -n "${instC[$p]}" ]] || missing+=("cask $p"); done
                if (( ${#missing} )); then
                    echo "✗ Brewfile 漏装 ${#missing} 个: ${missing[*]}（dfm s 补齐）"
                    (( fails+=1 ))
                else
                    echo "✓ Brewfile 无漏装"
                fi
                # 漏登记：leaves/cask 已装未登记（dfm d 的非交互预告）
                for p in "${(f)$(brew leaves 2>/dev/null)}"; do [[ -n "${regB[$p]}" ]] || unreg_brew+=("$p"); done
                for p in "${(@k)instC}"; do [[ -n "${regC[$p]}" ]] || unreg_cask+=("$p"); done
                if (( ! ${#unreg_brew} && ! ${#unreg_cask} )); then
                    echo "✓ Brewfile 无漏登记"
                else
                    # 两数组无缝拼接会让 brew 尾项与 cask 首项黏连，合并后再输出
                    unreg_all=(${unreg_brew[@]} ${unreg_cask[@]})
                    echo "⚠ Brewfile 漏登记: ${unreg_all[*]}（dfm d 交互归组登记）"
                    (( warns+=1 ))
                fi
            else
                echo "⚠ brew 缺失，跳过 Brewfile 检查"
                (( warns+=1 ))
            fi
            # ---- npm 清单双向漂移（空清单即 ✗，与 dfm u 同口径——清单是事实来源）----
            if command -v npm &>/dev/null; then
                # [[ -n ]] 守卫防 ${(f)""} 的空串假键（清单缺失时 grep 输出为空）
                for p in "${(f)$(grep -vE '^[[:space:]]*(#|$)' "$dir/npm-globals.txt" 2>/dev/null)}"; do [[ -n "$p" ]] && regN[$p]=1; done
                if (( ! ${#regN} )); then
                    echo "✗ npm 清单缺失或为空（npm-globals.txt）"
                    (( fails+=1 ))
                else
                    # --parseable 首行是 node_modules 根目录本身，跳过；npm/corepack 是
                    # node 自带系统件，非用户全局工具，从「漏登记」判定中排除；
                    # scoped 包路径末两段才是完整名（@scope/pkg），$NF 会截掉 scope
                    for p in "${(f)$(npm ls -g --depth=0 --parseable 2>/dev/null | awk -F/ 'NR>1 && $NF!="npm" && $NF!="corepack" { if ($(NF-1) ~ /^@/) print $(NF-1) "/" $NF; else print $NF }')}"; do instN[$p]=1; done
                    for p in "${(@k)regN}"; do [[ -n "${instN[$p]}" ]] || npm_missing+=("$p"); done
                    for p in "${(@k)instN}"; do [[ -n "${regN[$p]}" ]] || npm_extra+=("$p"); done
                    if (( ${#npm_missing} )); then
                        echo "✗ npm 漏装: ${npm_missing[*]}（dfm s 同款重装命令: npm install -g <名>）"
                        (( fails+=1 ))
                    else
                        echo "✓ npm 无漏装"
                    fi
                    if (( ${#npm_extra} )); then
                        echo "⚠ npm 漏登记: ${npm_extra[*]}（有意保留就忽略，或登记进 npm-globals.txt）"
                        (( warns+=1 ))
                    else
                        echo "✓ npm 无漏登记"
                    fi
                fi
            else
                echo "⚠ npm 缺失，跳过 npm 检查"
                (( warns+=1 ))
            fi
            # ---- 工作区清洁度（claude settings 的写入也自然被覆盖）----
            if [[ -n "$(git -C "$dir" status --porcelain 2>/dev/null)" ]]; then
                echo "⚠ dotfiles 有未提交变更（cd ~/dotfiles && git add -A && git commit）"
                (( warns+=1 ))
            else
                echo "✓ dotfiles 工作区干净"
            fi
            echo "—— 体检: ✗ ${fails} / ⚠ ${warns} ——"
            (( fails == 0 ))
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
                    *) echo "未知选项 $1（-v 全量透传）" >&2; return 1 ;;
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
            # pull 后立即装机（软链/克隆/tmux 刷新，幂等秒级）——收口「仓库有、
            # 机器无」缺口；即使 pull 无新提交也跑，兜住历史欠账
            dfm_step "机器侧安装" dfm_apply && ok+=(apply) || fail+=(apply)
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
            # omz 直跑 upgrade.sh 而非 omz update：官方 _omz::update 拉到新提交后
            # 会 exec 重启当前 shell，在 dfm_step 的 >> log 2>&1 重定向下等于把
            # 新 shell 的输出永久钉进日志（fd 恢复随进程替换失效；2026-10-07
            # 事故：屏幕冻结 12h、命令盲跑、日志被灌到 5GB），见 dfm_omz_update
            dfm_step "omz" dfm_omz_update && ok+=(omz) || fail+=(omz)
            local summary="升级完成: ✓ ${ok[*]:-无}  ✗ ${fail[*]:-无}"
            echo "$summary"
            (( verbose )) || echo "$summary" >> "$log"
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
