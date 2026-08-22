#!/bin/bash
# =========================================================================
# bootstrap.sh — macOS 新机器开发环境一键初始化
#
# 用法（两种方式任选）:
#   1. bash -c "$(curl -fsSL https://raw.githubusercontent.com/XHao/dotfiles/main/bootstrap.sh)"
#   2. git clone git@github.com:XHao/dotfiles.git ~/dotfiles && bash ~/dotfiles/bootstrap.sh
#      （HTTPS 不通的网络用这种方式，前提是 SSH 密钥已添加到 GitHub）
# =========================================================================
set -euo pipefail

DOTFILES_REPO_SSH="git@github.com:XHao/dotfiles.git"
DOTFILES_REPO_HTTPS="https://github.com/XHao/dotfiles.git"
DOTFILES_DIR="$HOME/dotfiles"

# ---------- 颜色输出 ----------
info()    { printf "\033[1;34m[INFO]\033[0m %s\n" "$*"; }
success() { printf "\033[1;32m[ OK ]\033[0m %s\n" "$*"; }
error()   { printf "\033[1;31m[FAIL]\033[0m %s\n" "$*" >&2; }

# 需要符号链接的配置（相对 $HOME 的路径）
# 注意: vim 配置独立管理（~/.vim/.vimrc + vim-plug），不在本仓库
LINK_PATHS=(
    ".zshrc"
    ".gitconfig"
    ".config/git"
    ".config/htop"
    ".claude/settings.json"
)

# ---------- 1. Xcode Command Line Tools ----------
if ! xcode-select -p &>/dev/null; then
    info "安装 Xcode Command Line Tools..."
    xcode-select --install
    echo "请在弹窗中点击「安装」，完成后按回车继续..."
    read -r
fi
success "Xcode CLT 已就绪"

# ---------- 2. Homebrew ----------
if ! command -v brew &>/dev/null; then
    info "安装 Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi
# Apple Silicon 下 brew 装在 /opt/homebrew，确保本脚本内可用
if [ -x /opt/homebrew/bin/brew ]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi
success "Homebrew 已就绪: $(brew --version | head -1)"

# ---------- 3. 克隆 / 更新 dotfiles 仓库 ----------
if [ ! -d "$DOTFILES_DIR/.git" ]; then
    info "克隆 dotfiles 仓库..."
    # SSH 优先（本机网络 HTTPS 常不通），失败则回退 HTTPS（公开仓库无需认证）
    if ! git clone "$DOTFILES_REPO_SSH" "$DOTFILES_DIR" 2>/dev/null; then
        git clone "$DOTFILES_REPO_HTTPS" "$DOTFILES_DIR"
    fi
else
    info "更新 dotfiles 仓库..."
    git -C "$DOTFILES_DIR" pull --ff-only || info "跳过更新（无网络或本地有改动）"
fi
# 本仓库对外公开，提交身份固定为 GitHub noreply 地址。
# 仓库级配置存在 .git/config 里不随克隆分发，所以每台机器都要重设——
# 否则在本仓库提交会用全局真实邮箱，经提交历史泄露进公开仓库
git -C "$DOTFILES_DIR" config user.name "XHao"
git -C "$DOTFILES_DIR" config user.email "XHao@users.noreply.github.com"
success "dotfiles 已就绪: $DOTFILES_DIR"

# ---------- 4. 安装 Brewfile 中的软件 ----------
info "安装 Brewfile 中的软件（耗时取决于网络）..."
brew bundle --file="$DOTFILES_DIR/Brewfile"
success "所有软件安装完成"

# npm 全局工具（Brewfile 不支持 npm 条目，单独安装；重复执行幂等）
# 清单与 ~/.vim 的 60-coding.sh npm 部分保持一致 + claude-code + pnpm；
# instant-markdown-d 是 vim-instant-markdown 插件（markdown 实时预览）的后端
# npm registry 不可达时不应中断整体初始化——降级为告警
info "安装 npm 全局工具（pyright / prettier / instant-markdown-d / pnpm / claude-code）..."
if ! npm install -g pyright prettier instant-markdown-d pnpm @anthropic-ai/claude-code; then
    error "npm 全局安装失败（网络？），稍后手动执行:"
    error "  npm install -g pyright prettier instant-markdown-d pnpm @anthropic-ai/claude-code"
else
    success "npm 全局工具已就绪"
fi

# ---------- 5. Oh My Zsh（.zshrc 依赖它） ----------
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    info "安装 Oh My Zsh（unattended，不改动 .zshrc）..."
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
fi
success "Oh My Zsh 已就绪"

# 默认 shell 改为 zsh（现代 macOS 默认即是，老机器可能不是）
if [ "$SHELL" != "/bin/zsh" ] && [ "$SHELL" != "/usr/bin/zsh" ]; then
    info "将默认 shell 切换为 zsh（需要输入密码）..."
    chsh -s /bin/zsh
fi

# ---------- 6. 创建符号链接 ----------
info "创建配置文件符号链接..."
for path in "${LINK_PATHS[@]}"; do
    src="$DOTFILES_DIR/$path"
    dst="$HOME/$path"

    if [ ! -e "$src" ]; then
        error "仓库中缺少 $path，跳过"
        continue
    fi

    # 目标已存在且不是本仓库的链接 → 备份后替换
    if [ -e "$dst" ] && [ ! -L "$dst" ]; then
        mv "$dst" "${dst}.bak.$(date +%Y%m%d%H%M%S)"
        info "已备份原有文件"
    fi

    mkdir -p "$(dirname "$dst")"
    ln -sfn "$src" "$dst"
    success "已链接 ~/$path"
done

# ---------- 7. Git 身份（写入 ~/.gitconfig.local，不入库） ----------
if [ ! -f "$HOME/.gitconfig.local" ]; then
    info "配置 Git 身份（保存在 ~/.gitconfig.local，不进仓库）..."
    read -rp "输入 Git 用户名: " git_name
    read -rp "输入 Git 邮箱:   " git_email
    if [ -z "$git_name" ] || [ -z "$git_email" ]; then
        error "用户名和邮箱不能为空，稍后请手动执行:"
        error "  git config --file ~/.gitconfig.local user.name  <名字>"
        error "  git config --file ~/.gitconfig.local user.email <邮箱>"
    else
        git config --file "$HOME/.gitconfig.local" user.name "$git_name"
        git config --file "$HOME/.gitconfig.local" user.email "$git_email"
        success "Git 身份已配置: $git_name <$git_email>"
    fi
else
    # 注意用不带 --global 的读取（git config --global <key> 不跟随 include 展开），
    # 且固定 -C $HOME：避免在仓库目录内发起时被仓库级身份遮蔽（如本仓库的 noreply）
    success "Git 身份已存在: $(git -C "$HOME" config user.name) <$(git -C "$HOME" config user.email)>"
fi

# ---------- 8. SSH 密钥 ----------
if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
    info "生成 SSH 密钥（ed25519，无口令）..."
    mkdir -p "$HOME/.ssh" && chmod 700 "$HOME/.ssh"
    ssh-keygen -t ed25519 -C "$(git -C "$HOME" config user.email || echo "$USER@$(hostname)")" \
        -f "$HOME/.ssh/id_ed25519" -N ""
    echo ""
    info "请将以下公钥添加到 GitHub（粘贴整行）:"
    cat "$HOME/.ssh/id_ed25519.pub"
    echo ""
    info "打开: https://github.com/settings/ssh/new"
else
    success "SSH 密钥已存在"
fi

# 后续的 pull/push 走 SSH（公开仓库 HTTPS clone 无需认证，但推送需要）
if git -C "$DOTFILES_DIR" remote get-url origin &>/dev/null; then
    git -C "$DOTFILES_DIR" remote set-url origin "$DOTFILES_REPO_SSH"
fi

# ---------- 9. Claude Code 插件恢复 ----------
# enabledPlugins 随 settings.json 分发，但 marketplace 注册表
# (~/.claude/plugins/known_marketplaces.json) 是机器态（含绝对路径），
# 需重注册后安装。插件清单从 settings.json 动态推导，不在此硬编码
if command -v claude &>/dev/null; then
    info "恢复 Claude Code 插件..."
    # claude-spells 是个人开发用 marketplace，不参与自动恢复；
    # 需要的机器手动执行: claude plugin marketplace add https://github.com/XHao/claude-spells.git
    claude plugin marketplace add forrestchang/andrej-karpathy-skills || true
    while IFS= read -r plugin; do
        claude plugin install "$plugin" || true
    done < <(jq -r '.enabledPlugins | to_entries[] | select(.value) | .key' \
        "$HOME/.claude/settings.json" 2>/dev/null)
    success "Claude Code 插件恢复完成（个别失败重跑即可）"
fi

# ---------- 完成 ----------
echo ""
success "========================================="
success "  环境初始化完成！"
success "========================================="
echo ""
info "后续步骤:"
echo "  1. 重启终端，或执行: source ~/.zshrc"
echo "  2. 终端偏好设置里选用 Hack Nerd Font（agnoster/airline/NERDTree 图标依赖）"
echo "  3. vim 配置（~/.vim/）独立于本仓库，需自行同步并执行 :PlugInstall"
echo "  4. Claude Code 的 API token 存在 macOS 钥匙串中，需手动设置:"
# shellcheck disable=SC2016  # $USER 需原样展示给用户复制执行，不能展开
echo '       security add-generic-password -a "$USER" -s "claude_code_token" -w "<DeepSeek API Key>"'
# shellcheck disable=SC2016  # 同上
echo '       security add-generic-password -a "$USER" -s "glm_token" -w "<智谱 API Key>"'
echo "  5. .ssh/config 未入库（含主机信息），如需请手动同步"
