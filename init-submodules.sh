#!/bin/bash
# =============================================================================
# NOVA Video Player - 子模块初始化脚本（带自动重试）
# 用法: bash init-submodules.sh [最大重试次数]
# =============================================================================

cd "$(dirname "${BASH_SOURCE[0]}")"

MAX_RETRY=${1:-5}
RETRY_DELAY=5

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo "=== NOVA 子模块初始化（重试模式，最多 $MAX_RETRY 轮）==="

for round in $(seq 1 $MAX_RETRY); do
    echo ""
    echo -e "${YELLOW}--- 第 $round 轮初始化 ---${NC}"

    # 检查还有多少未完成的子模块
    remaining=$(git submodule status 2>/dev/null | grep -c "^-" || true)
    if [ "$remaining" -eq 0 ]; then
        echo -e "${GREEN}所有子模块已初始化完成！${NC}"
        break
    fi
    echo "剩余 $remaining 个子模块待初始化..."

    # 逐个克隆失败的子模块（避免一个失败阻塞全部）
    while IFS= read -r line; do
        status="${line:0:1}"
        path=$(echo "$line" | awk '{print $2}')
        if [ "$status" = "-" ]; then
            echo "  克隆 $path ..."
            if ! git submodule update --init --recursive "$path" 2>&1 | tail -2; then
                echo -e "  ${RED}$path 失败，稍后重试${NC}"
            fi
        fi
    done < <(git submodule status 2>/dev/null | grep "^-")

    # 网络稳定性配置：提高容错
    git config --global http.lowSpeedLimit 1000
    git config --global http.lowSpeedTime 60
    git config --global http.postBuffer 524288000

    if [ "$round" -lt "$MAX_RETRY" ]; then
        echo "等待 ${RETRY_DELAY}s 后重试..."
        sleep $RETRY_DELAY
    fi
done

# 最终检查
echo ""
remaining=$(git submodule status 2>/dev/null | grep -c "^-" || true)
if [ "$remaining" -eq 0 ]; then
    echo -e "${GREEN}=========================================${NC}"
    echo -e "${GREEN}✓ 全部 21 个子模块初始化完成！${NC}"
    echo -e "${GREEN}=========================================${NC}"
else
    echo -e "${RED}仍有 $remaining 个子模块未完成，请检查网络后重新运行:${NC}"
    echo "  bash init-submodules.sh"
fi
