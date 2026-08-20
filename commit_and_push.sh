#!/usr/bin/env bash
# ============================================================
# commit_and_push.sh
#
# 功能：
#   只提交代码/脚本/文档的变更到 master 分支
#   不碰 hosts，不重写历史，不 force push
#
# 使用前提：
#   - 当前在 master 分支
#   - 有代码变更需要提交
# ============================================================
set -e

cd "$(dirname "$0")"

REMOTE="origin"
BRANCH="master"

# ========== 白名单：需要提交的文件/目录 ==========
WHITELIST=(
    "README.md"
    "LICENSE"
    "update_action.sh"
    "commit_and_push.sh"
    "update_hosts.sh"
    "docs"
    "hosts_allow"
    "hosts_allow_g"
    "sqwei"
)

echo "==> [1/4] 校验环境"
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "错误：当前目录不是 git 仓库" >&2
    exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
    echo "错误：请在 $BRANCH 分支上运行（当前：$CURRENT_BRANCH）" >&2
    exit 1
fi

echo "==> [2/4] 校验关键文件完整性"
for item in "${WHITELIST[@]}"; do
    if [ ! -e "$item" ]; then
        echo "警告：缺少 $item（继续运行）" >&2
    fi
done

echo "==> [3/4] 暂存并提交代码变更"
git add "${WHITELIST[@]}" 2>/dev/null || true

# 检查是否有东西可提交
if git diff --cached --quiet; then
    echo "    无代码变更，跳过提交"
else
    git commit -m "chore: 更新代码/脚本/文档"
fi

echo "==> [4/4] 推送到 $REMOTE/$BRANCH"
git push "$REMOTE" "$BRANCH"

echo ""
echo "✅ 完成：代码已推送到 master（无 force push，历史完整保留）"
