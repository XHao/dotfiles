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
npm 全局工具（清单见 `npm-globals.txt`——Brewfile 不支持 npm 条目；
registry 已设为 npmmirror 国内镜像，见下表）→
Oh My Zsh → 符号链接配置（原文件自动备份为 `*.bak.时间戳`）→ Git 身份引导（可输 `n` 跳过）
（全局 + `~/work` 工作区两套，工作目录不存在则自动创建）→ SSH 密钥。

字体由 Brewfile 以 cask 安装（Hack Nerd Font，agnoster/airline/NERDTree 图标依赖）；
装完后需在终端偏好设置里手动选用才能生效。

冷启动只需一次。职责划分：**初始化/重建机器**永远用 `bash ~/dotfiles/bootstrap.sh`
（幂等可重跑——换机 `git pull` 后重放配置、修复符号链接、补装软件）；
**包的装/卸/同步/升级**永远用 `dfm`（见下文日常维护）。

## 仓库结构

```
├── bootstrap.sh       # 新机器入口脚本
├── Brewfile           # 软件清单（按用途分组注释）
├── npm-globals.txt    # npm 全局工具清单（bootstrap 与 dfm u 共享，支持 # 注释）
├── README.md          # 本文档
├── .zshrc             # zsh 入口：按序加载 zshrc.d/ 模块 + ~/.zshrc.local 钩子
├── zshrc.d/           # 按序模块：path/tmux/java/go/omz/enhance/ai/dfm/highlight(90=最后)
├── .tmux.conf         # tmux 配置（分屏/真彩透传/剪贴板打通/Powerline 状态栏）
├── .gitconfig         # 共享 Git 配置（身份与路由在 ~/.gitconfig.local + ~/.gitconfig-<身份名>，不入库）
├── .gitignore         # 仓库自身忽略规则
├── .claude/settings.json  # Claude Code 全局配置（插件启用清单、主题、权限模式）
└── .config/           # git/ignore（全局 gitignore，XDG 默认路径）、htop/htoprc
```

## 不入库的内容

| 内容 | 原因 | 新机器的处理 |
|---|---|---|
| `~/.ssh/`（密钥、config、known_hosts） | 含主机与凭据信息 | bootstrap 生成新密钥；config 手动同步 |
| `~/.gitconfig.local`（默认身份 + 附属身份路由） | 每台机器私有 | bootstrap 引导生成（可输 `n` 跳过） |
| `~/.gitconfig-<身份名>`（各附属身份，如 personal） | 每台机器私有 | bootstrap 引导生成，身份名与关联目录自定义 |
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
`zshrc.d/` 下的 `*.zsh`（`00-path` → `05-tmux` → `10-java` → `20-go` → `30-omz` →
`40-enhance` → `50-ai` → `60-dfm` → `90-highlight`），最后挂 `~/.zshrc.local`
钩子承接不入库的本机私有配置。**新增功能 = 新增一个模块文件**；数字前缀即
加载顺序（`90-highlight` 单列正是「语法高亮必须最后加载」约束的结构化表达）。

扩充方式：omz 内置插件加进 `30-omz.zsh` 的 `plugins=()`；外部插件走
`dfm i <包名>`（自动登记 Brewfile），再在 `zshrc.d/` 补一个 source 模块——
涉及 ZLE 的（高亮类）前缀取大数字保证最后加载。

## tmux

Brewfile 安装 tmux，`.tmux.conf` 入库（bootstrap 软链到 `~/.tmux.conf`），给
Terminal.app 补上分屏与会话持久化（会话独立于终端窗口存活，`tmux attach` 恢复现场）。

Terminal 每个新窗口自动进 tmux（`zshrc.d/05-tmux.zsh`：`exec tmux new -A -s main`
attach 优先接入；detach 时窗口随之关闭不留裸壳；tmux 内/非交互/未装时跳过）。
多个窗口接入同一 main 会话互为镜像，要独立现场就 `前缀 :` 输 `new -s <名>`。

前缀保持默认 `Ctrl-b`：zsh 里它的光标左移用 `←` 替代，vim 翻页不用它——冲突成本最低。
配置要点：真彩透传（Tahoe Terminal 已支持 24-bit）、复制直达系统剪贴板（pbcopy）、
Powerline 状态栏（依赖 Hack Nerd Font）、机器私有配置放 `~/.tmux.conf.local`（存在则加载）。

键位速查（前缀 = `Ctrl-b`）:

| 键 | 作用 |
|---|---|
| `前缀 \|` / `前缀 -` | 左右 / 上下分屏（继承当前目录） |
| `前缀 h/j/k/l` | 切窗格（方向键亦可） |
| `前缀 z` | 当前窗格放大/还原 |
| `前缀 c` / `数字` / `n` / `p` | 新窗口 / 按号跳转 / 下一个 / 上一个 |
| `前缀 ,` / `前缀 $` | 窗口 / 会话重命名 |
| `前缀 [` | 回滚 copy mode（`Ctrl-b/f` 整页、`Ctrl-u/d` 半页、`/` 搜索、`q` 退出） |
| `v` / `y`（回滚中） | 选择 / 复制进系统剪贴板（之后 `Cmd+V` 直接粘贴） |
| `前缀 S` | 同步输入开关（广播到当前窗口所有窗格，⚠️ 用完立刻关） |
| `前缀 d` / `前缀 s` / `前缀 (` `)` | 脱离会话 / 会话列表 / 上一个、下一个会话 |
| `前缀 r` | 热重载配置 |

常用命令：`tmux new -s <名>` 新建命名会话、`tmux ls` 列出、`tmux attach -t <名>`
回到现场；关掉终端窗口甚至退出 Terminal，会话照活。

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
dfm u                   # 升级全家桶（见下）
dfm h                   # 帮助
```

`dfm u` 把机器拉到最新，六步各自独立（某步失败不阻断后续，结尾 ✓/✗ 汇总）：
dotfiles 仓库 `git pull --ff-only`（有未提交变更直接终止提示处理；本地领先
只提示不自动 push）→ `brew bundle` 补齐新条目 → `brew update` →
`brew upgrade`（含 cask；不做 `brew bundle cleanup`，删包保持手动）→
npm 全局工具按 `npm-globals.txt` 重装即升级 → `omz update`。

默认**安静模式**：每步一行 ✓/✗，失败自动带出该步日志尾部 20 行；全量输出
留档 `~/.dfm/upgrade.log`（另开终端 `tail -f` 实时围观）。`dfm u -v` 全量
透传；`dfm u -b` 丢进 tmux 后台窗口跑（tee 同一份日志，跑完状态栏提醒，
回车前窗口保留摘要——不占当前终端，断连不死）。

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
真实邮箱只存在于 `~/.gitconfig.local` / `~/.gitconfig-<身份名>`，不会进入公开历史。
