# =========================================================================
# Brewfile — 软件清单，新机器由 bootstrap.sh 执行 brew bundle 安装
#
# 日常维护：装了新软件后在本机执行
#   cd ~/dotfiles && brew bundle dump --force
# 然后手工把新增条目归入下面的分组（dump 输出无注释无分组），再提交推送。
# =========================================================================

# ---- 开发基础 ----
brew "git"
brew "vim"
brew "node"

# ---- Java 开发 ----
# openjdk（滚动最新）是主动安装的，但 brew leaves 会因 jdtls/google-java-format
# 依赖它而隐藏，故显式声明；.zshrc 的 JAVA_HOME 默认指向它
# 多版本用 .zshrc 里的 jdk <版本号> 在会话内切换
brew "openjdk"
brew "openjdk@11"
brew "openjdk@17"
brew "openjdk@21"
brew "openjdk@25"
brew "google-java-format"
brew "jdtls"

# ---- Go 开发 ----
brew "go"
brew "gopls"           # Go LSP（vim-lsp / vim-go 依赖）
brew "golangci-lint"
brew "delve"           # 调试器 dlv，vim-go 的 :GoDebug（规范名 delve，dlv 是别名）

# ---- C/C++ 开发 ----（clangd 由 Xcode CLT 提供，无需安装）
brew "cmake"
brew "clang-format"
brew "ninja"           # 增量构建器：cmake -G Ninja
brew "ccache"
brew "pkgconf"
brew "universal-ctags" # gutentags / Tagbar 的正主依赖

# ---- Python 开发 ----
# python@3.14 显式声明（此前作为其他包的依赖被 brew leaves 隐藏）
brew "python@3.14"
brew "uv"              # 现代依赖/venv/多版本管理：uv venv / uv pip / uv python install
brew "black"

# ---- k8s & 容器 ----
brew "kubernetes-cli"  # kubectl（规范名 kubernetes-cli，kubectl 是别名）
brew "minikube"
brew "podman"
brew "container"       # Apple 轻量虚拟机容器方案

# ---- CLI 增强 ----
brew "fzf"
brew "ripgrep"
brew "htop"
brew "jq"
brew "shellcheck"      # bootstrap.sh 的静态检查（维护本仓库时用）

# ---- Shell 增强 ----
brew "zsh-autosuggestions"      # 历史建议：灰色提示，→ 采纳
brew "zsh-syntax-highlighting"  # 语法高亮（.zshrc 中必须最后 source）

# ---- 工具 ----
brew "poppler"         # PDF 处理: pdftotext / pdfinfo 等

# ---- 字体 ----
# Nerd Font = Powerline 符号超集 + 图标全集；agnoster/airline/NERDTree 的
# 箭头与图标靠它渲染。装完后需在终端偏好里手动选用该字体才生效
cask "font-hack-nerd-font"

# ---- dfm 登记（待人工归组）----
# dfm i 自动追加到这里，定期人工挪进上面合适分组
