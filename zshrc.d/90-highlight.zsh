# 90-highlight —— 语法高亮（必须最后加载）
# 官方要求：zsh-syntax-highlighting 要在任何包装 ZLE widget 的插件
# （autosuggestions、fzf 键位等，见 40-enhance.zsh）之后 source，
# 故本模块文件名前缀取 90 保证加载序最末
[ -f /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] && \
    source /opt/homebrew/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
