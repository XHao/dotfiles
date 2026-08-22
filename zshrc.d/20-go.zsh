# 20-go —— Go 工具链与模块代理
# vim-go 的 :GoInstallBinaries 装到 ~/go/bin
# （追加在 PATH 末尾：gopls/dlv/golangci-lint 用 brew 版，其余 goimports/godef 等
#  由本目录提供——取代以往往 /opt/homebrew/bin 手工软链的做法）
[[ -d "$HOME/go/bin" ]] && export PATH="$PATH:$HOME/go/bin"

# 模块代理：默认 proxy.golang.org 国内不可达，走 goproxy.cn（七牛）；
# direct = 代理未命中时回退直连（私有仓库/本地 replace 场景）
export GOPROXY=https://goproxy.cn,direct
# 私有模块绕过代理与校验，如有公司私有仓库再取消注释（逗号分隔 glob）
# export GOPRIVATE="*.corp.example.com"
