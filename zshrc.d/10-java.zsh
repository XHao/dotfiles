# 10-java —— JAVA_HOME 与多版本切换
# brew 的 openjdk 是 keg-only（不链接进 PATH，java_home 也发现不了），
# 需手动设置 JAVA_HOME 并暴露到 PATH；brew upgrade 后自动跟进新版本
export JAVA_HOME="/opt/homebrew/opt/openjdk"
[[ -d "$JAVA_HOME" ]] && export PATH="$JAVA_HOME/bin:$PATH"

# jdk <版本号> 只影响当前会话；jdk 无参数列出已装版本
# JDK 来自 brew（openjdk / openjdk@NN 均为 keg-only，统一经 /opt/homebrew/opt 寻址）
jdk() {
    local base="/opt/homebrew/opt"
    if [[ $# -eq 0 ]]; then
        echo "当前 JAVA_HOME: ${JAVA_HOME:-<未设置>}"
        echo "已装版本:"
        local d
        for d in "$base"/openjdk*(N); do
            printf "  %-14s %s\n" "${d:t}" "$("$d/bin/java" -version 2>&1 | head -1)"
        done
        echo "用法: jdk <版本号>，如 jdk 21"
        return 0
    fi
    local home="$base/openjdk@$1"
    if [[ ! -d "$home" ]]; then
        echo "未找到 openjdk@$1，已装版本:" >&2
        for d in "$base"/openjdk*(N); do echo "  ${d:t}" >&2; done
        return 1
    fi
    # 用 zsh 的 path 数组精确移除旧 JDK 的 bin，再前置新版本
    if [[ -n "${JAVA_HOME:-}" ]]; then
        path=("${(@)path:#${JAVA_HOME}/bin}")
    fi
    export JAVA_HOME="$home"
    path=("$home/bin" $path)
    "$home/bin/java" -version 2>&1 | head -1
}
