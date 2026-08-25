# dotfiles

macOS 开发环境一键恢复。新机器上跑一条命令，装回全部软件和配置。

## 新机器使用

**方式一**（一条命令，需要 HTTPS 可访问 GitHub）:

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/XHao/dotfiles/main/bootstrap.sh)"
```

**方式二**（HTTPS 不通的网络，先把 SSH 密钥加到 GitHub 后）:

```bash
git clone git@github.com:XHao/dotfiles.git ~/dotfiles
bash ~/dotfiles/bootstrap.sh
```

脚本依次完成：Xcode CLT → Homebrew → 克隆本仓库 → `brew bundle` 装软件 →
npm 全局工具（pyright、prettier、instant-markdown-d、pnpm、claude-code——
Brewfile 不支持 npm 条目，其中 instant-markdown-d 是 vim markdown 预览的后端；
registry 已设为 npmmirror 国内镜像，见下表）→
Oh My Zsh → 符号链接配置（原文件自动备份为 `*.bak.时间戳`）→ Git 身份
（全局 + `~/work` 工作区两套，工作目录不存在则自动创建）→ SSH 密钥。

字体由 Brewfile 以 cask 安装（Hack Nerd Font，agnoster/airline/NERDTree 图标依赖）；
装完后需在终端偏好设置里手动选用才能生效。

冷启动只需一次。职责划分：**初始化/重建机器**永远用 `bash ~/dotfiles/bootstrap.sh`
（幂等可重跑——换机 `git pull` 后重放配置、修复符号链接、补装软件）；
**包的装/卸/同步**永远用 `dfm`（见下文日常维护）。

## 仓库结构

```
├── bootstrap.sh       # 新机器入口脚本
├── Brewfile           # 软件清单（按用途分组注释）
├── README.md          # 本文档
├── .zshrc             # zsh 入口：按序加载 zshrc.d/ 模块 + ~/.zshrc.local 钩子
├── zshrc.d/           # 按序模块：path/java/go/omz/enhance/ai/dfm/highlight(90=最后)
├── .gitconfig         # 共享 Git 配置（身份在 ~/.gitconfig.local / ~/.gitconfig-work，不入库）
├── .gitignore         # 仓库自身忽略规则
├── .claude/settings.json  # Claude Code 全局配置（插件启用清单、主题、权限模式）
└── .config/           # git/ignore（全局 gitignore，XDG 默认路径）、htop/htoprc
```

## 不入库的内容

| 内容 | 原因 | 新机器的处理 |
|---|---|---|
| `~/.ssh/`（密钥、config、known_hosts） | 含主机与凭据信息 | bootstrap 生成新密钥；config 手动同步 |
| `~/.gitconfig.local`（user.name/email） | 每台机器私有 | bootstrap 首次运行时交互输入 |
| `~/.gitconfig-work`（~/work 仓库的工作身份） | 每台机器私有 | bootstrap 首次运行时交互输入（并创建 `~/work`） |
| `~/.npmrc`（registry 指向 npmmirror 镜像） | 国内网络提速，机器偏好 | bootstrap 每次运行自动设置 |
| 仓库级 noreply 提交身份（`.git/config`） | 不随克隆分发；防止真实邮箱进公开仓库 | bootstrap 每次运行自动设置 |
| `~/.vim/`（vim 配置 + 插件） | vim 是独立的一套配置体系 | 自行同步，打开 vim 执行 `:PlugInstall` |
| Claude Code 的 API token | 密钥只存 macOS 钥匙串 | 见下方命令 |

新机器设置 Claude Code token（`.zshrc` 启动时从钥匙串读取）:

```bash
security add-generic-password -a "$USER" -s "claude_code_token" -w "<DeepSeek API Key>"
security add-generic-password -a "$USER" -s "glm_token" -w "<智谱 API Key>"
```

`mcc` 函数用智谱 GLM 启动 Claude Code，`claude_ext` 以 bypass 权限模式启动，详见 `.zshrc`。

**Claude Code 配置的跨机器注意点**：

- `settings.json` 已入库（符号链接到 `~/.claude/settings.json`）——注意 Claude Code
  自己也会写这个文件（如 `/plugin` 装插件后 `enabledPlugins` 变化），之后记得在
  `~/dotfiles` 里 `git commit`，否则变更只留在本机
- API token 只在 macOS 钥匙串（上面两条命令），新机器必须手动设置
- 插件恢复是自动的：bootstrap 第 9 步重注册 marketplace 并按 `enabledPlugins`
  清单逐个安装（清单从 settings.json 动态推导，永不漂移）
- 会话历史（`projects/`、`history.jsonl`）含隐私，绝不入库；项目记忆想带走可
  手动拷 `~/.claude/projects/<项目>/memory/`

## zsh 增强

`.zshrc` 在 Oh My Zsh 基础上启用 8 个内置插件 + 2 个 brew 插件 + fzf 集成：

| 来源 | 插件/功能 | 用法 |
|---|---|---|
| omz | `git` | `gst`/`gco`/`gp` 等百个别名 |
| omz | `z` | `z dotf` 直达高频目录（frecency 越用越准） |
| omz | `sudo` | 敲完命令**双击 ESC** 自动补 sudo |
| omz | `extract` | `x <任意压缩包>` 通吃所有格式 |
| omz | `colored-man-pages` | man 页着色 |
| omz | `macos` | `flushdns`、`ofd`（Finder 打开当前目录）等 |
| omz | `kubectl` | `k`=kubectl、`kgpo`=get pods 等 k8s 别名 |
| omz | `bgnotify` | 长命令（mvn/gradle/brew）结束弹系统通知 |
| brew | `zsh-autosuggestions` | 灰色历史建议，`→` 采纳 |
| brew | `zsh-syntax-highlighting` | 命令存在性即时着色（必须最后加载） |
| fzf | 键位集成 | `Ctrl-R` 模糊历史 / `Ctrl-T` 模糊文件名 / `Alt-C` 模糊跳目录 |

历史记录：5 万条容量、全量去重、搜索跳重、跨终端实时共享（`SHARE_HISTORY`）。

`.zshrc` 采用**模块化加载**：入口只做一件事——按文件名序 source
`zshrc.d/` 下的 `*.zsh`（`00-path` → `10-java` → `20-go` → `30-omz` →
`40-enhance` → `50-ai` → `60-dfm` → `90-highlight`），最后挂 `~/.zshrc.local`
钩子承接不入库的本机私有配置。**新增功能 = 新增一个模块文件**；数字前缀即
加载顺序（`90-highlight` 单列正是「语法高亮必须最后加载」约束的结构化表达）。

扩充方式：omz 内置插件加进 `30-omz.zsh` 的 `plugins=()`；外部插件走
`dfm i <包名>`（自动登记 Brewfile），再在 `zshrc.d/` 补一个 source 模块——
涉及 ZLE 的（高亮类）前缀取大数字保证最后加载。

## Java 多版本

Brewfile 安装 `openjdk`（滚动最新，默认）+ `openjdk@11/17/21/25`，均为 brew keg-only。
`.zshrc` 提供 `jdk` 命令在**当前会话内**切换（不影响默认）:

```zsh
jdk        # 列出已装版本和当前 JAVA_HOME
jdk 21     # 切到 JDK 21，java/javac 立即生效，仅本会话
```

## 日常维护

装新软件（推荐用 `dfm`，`.zshrc` 提供——安装即登记，防止清单漂移）:

```zsh
dfm i wget              # 安装 + 登记进 Brewfile + 自动 git 提交
dfm i --cask iina       # cask 同理
dfm rm tree             # 卸载 + 从 Brewfile 移除 + 提交
dfm s                   # 新机器或 git pull 后，按 Brewfile 补齐
```

`dfm i` 按包名+描述的关键词规则**自动归组**（规则表在 `.zshrc` 的 `dfm_classify`，
如 `helm`→k8s、`gradle`→Java、`gopls`→Go）；无匹配的包落文件末尾「dfm 登记」
待归组区，定期人工挪进上面的分组。规范名自动解析：`dlv`→`delve`、
`kubectl`→`kubernetes-cli`。Brewfile 新增/改名分组后，记得同步 `dfm_classify`
的规则（分组名须与标题行完全一致，不一致时安全回落待归组）。

不经 dfm 直接装了软件的兜底:

```bash
cd ~/dotfiles
brew bundle dump --force    # 重新导出（丢失注释分组，需手工整理回 Brewfile）
git add -A && git commit -m "chore: update Brewfile" && git push
```

改了 `~/.zshrc` 等文件（它们是指向本仓库的符号链接）直接在仓库里提交推送即可。
本仓库的提交身份已被 bootstrap 固定为 GitHub noreply 地址（仓库级配置），
真实邮箱只存在于 `~/.gitconfig.local` / `~/.gitconfig-work`，不会进入公开历史。
