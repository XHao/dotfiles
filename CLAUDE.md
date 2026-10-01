# CLAUDE.md

本仓库是 macOS 本地环境搭建的脚手架（dotfiles，公开仓，GitHub 账号 XHao）。
此文件为 Claude Code 提供工作约束与架构心智模型；用户视角的完整文档在
README.md。新增根目录文件时，README 目录树与下文清单表需同步更新。

## 硬约束（违反即事故）

- **公开仓库**：提交身份固定为仓库级 noreply（`XHao <XHao@users.noreply.github.com>`，
  bootstrap 已写入 `.git/config`）。真实邮箱在 `~/.gitconfig.local`，绝不入库；
  验证身份用裸 `git config user.name`（`--global` 读取不跟随 include 展开，会骗人）
- **泄漏判据 = 已 push 的全量历史，不是当前树**：敏感信息（密钥/token/真实主机名/
  资产编号/内网地址/真实邮箱）一旦 commit+push 即视为泄漏——事后删除或改占位符
  只清工作树，`git log -p` / `git log -S` 仍可提取历史原文（实例：`06-title.zsh`
  注释里的公司主机名，修复提交后历史中依然可取）。故：写入注释/配置/提交信息前
  一律占位符化（`<主机名>`、`<密钥>`）；修复类提交的信息不复述原文；密钥类泄漏
  无论能否改写历史都**先轮换**；标识类清除须 `git filter-repo --replace-text` +
  force push + 全部克隆重同步
- **本机网络**：github.com HTTPS 直连不通，git 远程操作一律 SSH
  （`git@github.com:…`，含第三方公开仓克隆）；npm registry 走 npmmirror
- **不自动 push**：对外动作保持手动（`dfm u` 自身也遵守此约定，只提示领先）
- **绝不入库**：SSH 密钥/config、API token（只存 macOS 钥匙串）、Claude 会话历史、
  机器私有文件（`~/.gitconfig.local`、`~/.zshrc.local`、`~/.tmux.conf.local`）；
  vim 配置是独立仓 myvim（`~/.vim`），内容不进本仓库
- bootstrap 步骤 7 的 Git 身份引导是**交互式**的：自动化场景先
  `touch ~/dotfiles/.git-setup-done` 跳过（身份已配好的机器）

## 架构心智模型

**四份清单 = 单一事实源**，装机端（bootstrap.sh）与日常端（dfm）共享消费，
绝不双处硬编码：

| 清单 | 装机（bootstrap） | 日常（dfm） |
|---|---|---|
| `Brewfile` | 步骤 4 安装 | `s` 补齐 / `i`·`rm` 登记 / `dr` 漂移体检 |
| `npm-globals.txt` | 步骤 4 安装 | `u` 升级 / `dr` 体检 |
| `clones.txt`（路径+URL 两列） | 步骤 5 克隆 | `u`（dfm_apply）补装 / `dr` 体检 |
| `link-paths.txt` | 步骤 6 建链 | `u`（dfm_apply）补装 / `dr` 体检 |

- `dfm u` = pull → **dfm_apply（机器侧安装：建链 + 补克隆 + 刷 tmux，幂等秒级）**
  → brew 系列 → npm → omz。核心不变式：**pull 到货 ≠ 装进系统**——
  「仓库有、机器无」的缺口全靠 dfm_apply 收口（2026-10-01 状态栏事故的教训：
  pull 带回新配置，但软链与 dracula 主题双缺，状态栏静默回落默认样式）
- `dfm dr` 只探测不开药，✗ 项即缺口清单（退出码非 0）。机器侧缺口全部
  **静默降级**（配置引用不存在的路径不报错）——排障第一步永远是 `dfm dr`
- 克隆**只装不更**：第三方上游变更不自动跟进，升级手动 `git -C ~/<路径> pull`
- 软链是活文件：改 `~/.tmux.conf`/`~/.zshrc` 等就是改仓库文件。激活边界：
  tmux `source-file` 对整个服务器即刻生效；已开的 zsh 无法热重载，新开 shell 生效

## zshrc.d 模块纪律

- 新增功能 = 新增模块文件，数字前缀即加载顺序：`35-fzf-tab` 必须卡在
  compinit（30-omz）之后、autosuggestions（40-enhance）之前；`90-highlight` 必须最后
- dfm 本体在 `zshrc.d/60-dfm.zsh`；改完必须 `source` 后实测（dr/apply 幂等可直跑）
- dfm 的 helper（dfm_register/dfm_brew_sets/dfm_step）借用调用方 dfm() 动态
  作用域的局部变量（bf/verbose/log）——单独测 helper 前先设同名变量

## 改动验证门槛（全过再提交）

1. 语法：`bash -n bootstrap.sh`、`zsh -n zshrc.d/60-dfm.zsh`（改到哪个查哪个）
2. `shellcheck bootstrap.sh` 零告警（存量已清零，不许新增）
3. 清单解析口径三处一致（bootstrap 的 bash 与 dfm_apply/dfm dr 的 zsh）：
   `#` 顶格注释、空行/纯空白行跳过；clones.txt 两列必须用默认 IFS 的
   `read -r a b` 拆列（`IFS= read` 不分列，整行进第一列）
4. 功能实跑：`dfm dr` 全 ✓；`dfm_apply` 幂等（缺失项能补装，连跑第二次无动作）
5. 提交：conventional commits 中文主题；`dfm i/rm/d` 会自动提交，勿重复提交。
   **push 前按功能压缩本地提交**——同一功能的功能改动与配套文档合一笔，
   零碎小修并入相关功能提交；重排仅限未 push 的本地提交（已公开历史不可动）
