# 50-ai —— Claude Code 后端切换器
# 用法: ai glm | ai deepseek   切换当前 shell（含子进程）的 claude 后端
#       裸 ai                  查看当前后端
# 切换后所有入口的裸 claude（终端、vim <leader>ai、pipe、子代理）都走该后端；
# bypassPermissions 由 ~/.claude/settings.json 的 defaultMode 提供，无需命令行参数。
# token 从 macOS 钥匙串读取，不入库；新机器需先执行:
#   security add-generic-password -a "$USER" -s "claude_code_token" -w "<DeepSeek API Key>"
#   security add-generic-password -a "$USER" -s "glm_token" -w "<智谱 API Key>"
ai() {
    local token
    case "$1" in
        glm)
            token=$(security find-generic-password -a "$USER" -s "glm_token" -w 2>/dev/null)
            if [[ -z "$token" ]]; then
                echo "未找到 glm_token，请先执行:" >&2
                echo '  security add-generic-password -a "$USER" -s "glm_token" -w "你的智谱API Key"' >&2
                return 1
            fi
            export AI_BACKEND=glm
            export ANTHROPIC_BASE_URL=https://open.bigmodel.cn/api/anthropic
            export ANTHROPIC_AUTH_TOKEN="$token"
            export ANTHROPIC_MODEL=glm-5.3[1m]
            export ANTHROPIC_DEFAULT_OPUS_MODEL=glm-5.3[1m]
            export ANTHROPIC_DEFAULT_SONNET_MODEL=glm-5.3[1m]
            export ANTHROPIC_DEFAULT_HAIKU_MODEL=glm-5.3-flash
            export CLAUDE_CODE_SUBAGENT_MODEL=glm-5.3-flash
            # 智谱端点 schema 校验不支持 Artifact 工具的 \p{Cc} 转义，交互模式必报 400(1210)；
            # 用特性开关整体禁用（仅 TUI 产物预览，无功能损失），-p 打印模式不受影响
            export CLAUDE_CODE_DISABLE_ARTIFACT=1
            ;;
        deepseek)
            token=$(security find-generic-password -a "$USER" -s "claude_code_token" -w 2>/dev/null)
            if [[ -z "$token" ]]; then
                echo "未找到 claude_code_token，请先执行:" >&2
                echo '  security add-generic-password -a "$USER" -s "claude_code_token" -w "<DeepSeek API Key>"' >&2
                return 1
            fi
            export AI_BACKEND=deepseek
            export ANTHROPIC_BASE_URL=https://api.deepseek.com/anthropic
            export ANTHROPIC_AUTH_TOKEN="$token"
            export ANTHROPIC_MODEL=deepseek-flash[1m]
            export ANTHROPIC_DEFAULT_OPUS_MODEL=deepseek-v4-pro[1m]
            export ANTHROPIC_DEFAULT_SONNET_MODEL=deepseek-flash[1m]
            export ANTHROPIC_DEFAULT_HAIKU_MODEL=deepseek-flash
            export CLAUDE_CODE_SUBAGENT_MODEL=deepseek-flash
            unset CLAUDE_CODE_DISABLE_ARTIFACT    # 防从 glm 切回时残留
            ;;
        "")
            echo "当前后端: ${AI_BACKEND:-未设置}" >&2
            ;;
        *)
            echo "用法: ai [glm|deepseek]" >&2
            return 1
            ;;
    esac
    export CLAUDE_CODE_AUTO_COMPACT_WINDOW=786432
}

# 加载默认后端（暂定 glm）；父 shell 已 export AI_BACKEND 时尊重其选择不覆盖
ai "${AI_BACKEND:-glm}"
