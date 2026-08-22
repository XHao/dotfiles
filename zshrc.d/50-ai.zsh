# 50-ai —— Claude Code 环境与启动函数
# token 从 macOS 钥匙串读取，不入库；新机器需先执行:
#   security add-generic-password -a "$USER" -s "claude_code_token" -w "<DeepSeek API Key>"
#   security add-generic-password -a "$USER" -s "glm_token" -w "<智谱 API Key>"
export ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
export ANTHROPIC_MODEL=deepseek-v4-flash[1m]
export ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek-v4-pro[1m]
export ANTHROPIC_DEFAULT_SONNET_MODEL=deepseek-v4-flash[1m]
export ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-v4-flash
export CLAUDE_CODE_SUBAGENT_MODEL=deepseek-v4-flash
export CLAUDE_CODE_EFFORT_LEVEL=high
export CLAUDE_CODE_AUTO_COMPACT_WINDOW=786432
export ANTHROPIC_AUTH_TOKEN=$(security find-generic-password -a "$USER" -s "claude_code_token" -w 2>/dev/null)

claude_ext() {
    command claude --permission-mode bypassPermissions "$@"
}

# mcc: 用 GLM（智谱）启动 claude code，仅本次进程生效，不影响默认的 DeepSeek 配置
mcc() {
    local token
    token=$(security find-generic-password -a "$USER" -s "glm_token" -w 2>/dev/null)
    if [[ -z "$token" ]]; then
        echo "未找到 glm_token，请先执行:" >&2
        echo '  security add-generic-password -a "$USER" -s "glm_token" -w "你的智谱API Key"' >&2
        return 1
    fi
    ANTHROPIC_BASE_URL=https://open.bigmodel.cn/api/anthropic \
    ANTHROPIC_AUTH_TOKEN="$token" \
    ANTHROPIC_MODEL=glm-5.3[1m] \
    ANTHROPIC_DEFAULT_OPUS_MODEL=glm-5.3[1m] \
    ANTHROPIC_DEFAULT_SONNET_MODEL=glm-5.3[1m] \
    ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-4.7 \
    CLAUDE_CODE_SUBAGENT_MODEL=glm-4.7 \
    CLAUDE_CODE_EFFORT_LEVEL=high \
    CLAUDE_CODE_AUTO_COMPACT_WINDOW=786432 \
    command claude --permission-mode bypassPermissions "$@"
}
