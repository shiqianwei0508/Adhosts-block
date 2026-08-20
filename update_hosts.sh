#!/usr/bin/env bash
# ============================================================
# update_hosts.sh
#
# 功能：
#   1) 在 master 分支上运行 update_action.sh 生成最新 hosts
#   2) 将 hosts 通过 orphan 分支推送到 hosts-latest（单快照）
#   3) master 分支历史完全不动
#
# 使用前提：
#   - 当前在 master 分支
#   - GitLab 的 hosts-latest 分支允许 force push（或不存在）
# ============================================================
set -e

cd "$(dirname "$0")"

REMOTE="origin"
BRANCH="master"
HOSTS_FILE="hosts"
HOSTS_BRANCH="hosts-latest"
ORPHAN_BRANCH="__orphan_hosts"

# ========== 校验 ==========
echo "==> [1/5] 校验环境"
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "错误：当前目录不是 git 仓库" >&2
    exit 1
fi
if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
    echo "错误：未找到远程 '$REMOTE'" >&2
    exit 1
fi

# 必须在 master 分支
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
    echo "错误：请在 $BRANCH 分支上运行此脚本（当前：$CURRENT_BRANCH）" >&2
    exit 1
fi

# ========== 生成 hosts ==========
echo "==> [2/5] 运行 update_action.sh 生成最新 hosts"
bash update_action.sh
if [ ! -f "$HOSTS_FILE" ]; then
    echo "错误：生成失败，$HOSTS_FILE 不存在" >&2
    exit 1
fi

# 暂存 hosts 内容（因为后面要切分支）
HOSTS_CONTENT=$(cat "$HOSTS_FILE")

# ========== 创建 orphan 分支 ==========
echo "==> [3/5] 创建 orphan 分支（hosts 单快照）"
git checkout --orphan "$ORPHAN_BRANCH"

# 清空工作区
git rm -rf . >/dev/null 2>&1 || true

# 只写入 hosts
echo "$HOSTS_CONTENT" > "$HOSTS_FILE"
git add "$HOSTS_FILE"

git commit -m "chore: update hosts (single snapshot)" || {
    echo "错误：hosts 提交失败" >&2
    git checkout "$BRANCH"
    exit 1
}

# ========== 替换 hosts-latest ==========
echo "==> [4/5] 替换 $HOSTS_BRANCH 分支"
git branch -D "$HOSTS_BRANCH" >/dev/null 2>&1 || true
git branch -m "$HOSTS_BRANCH"

# ========== 推送 ==========
echo "==> [5/5] force push to $HOSTS_BRANCH"
git push --force "$REMOTE" "$HOSTS_BRANCH"

echo ""
echo "✅ 完成："
echo "  - master 分支历史未动"
echo "  - hosts-latest 分支已更新（单快照）"
echo "  - 下载地址："
echo "    https://gitlab.com/rainmor/Adhosts-block/-/raw/hosts-latest/hosts"
