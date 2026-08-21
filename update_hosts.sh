#!/usr/bin/env bash
# ============================================================
# update_hosts.sh
#
# 功能：
#   1) 在 master 分支上运行 update_action.sh 生成最新 hosts
#   2) 通过 orphan 分支创建“仅包含最新 hosts”的单快照
#   3) 将单快照强制推送到 hosts-latest 分支
#   4) master 分支历史完全不动，脚本结束后一定切回 master
#
# 设计原则：
#   - orphan 分支仅作为临时构建分支，用完即删
#   - 不 rename 分支，避免与已有 hosts-latest 冲突
#   - 所有关键步骤可预期、可回退
#
# 使用前提：
#   - 当前位于 master 分支
#   - GitLab 的 hosts-latest 分支允许 force push（或不存在）
# ============================================================
set -e

# 切换到脚本所在目录（项目根目录）
cd "$(dirname "$0")"

REMOTE="origin"
BRANCH="master"
HOSTS_FILE="hosts"
HOSTS_BRANCH="hosts-latest"
ORPHAN_BRANCH="__orphan_hosts"

# ========== 第 1 步：环境与分支校验 ==========
echo "==> [1/5] 校验环境与当前分支"
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "错误：当前目录不是 git 仓库" >&2
    exit 1
fi
if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
    echo "错误：未找到远程 '$REMOTE'" >&2
    exit 1
fi

CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD)
if [ "$CURRENT_BRANCH" != "$BRANCH" ]; then
    echo "错误：请在 $BRANCH 分支上运行此脚本（当前：$CURRENT_BRANCH）" >&2
    exit 1
fi

# ========== 第 2 步：生成最新 hosts ==========
echo "==> [2/5] 运行 update_action.sh 生成最新 hosts"
bash update_action.sh
if [ ! -f "$HOSTS_FILE" ]; then
    echo "错误：生成失败，$HOSTS_FILE 不存在" >&2
    exit 1
fi

# 将 hosts 内容读入变量，避免后续切分支后文件丢失
HOSTS_CONTENT=$(cat "$HOSTS_FILE")

# ========== 第 3 步：创建 orphan 分支并构建单快照 ==========
echo "==> [3/5] 创建 orphan 分支（hosts 单快照）"
git checkout --orphan "$ORPHAN_BRANCH"

# 清空工作区与暂存区（仅影响当前 orphan 分支）
git rm -rf . >/dev/null 2>&1 || true

# 仅写入 hosts 文件
echo "$HOSTS_CONTENT" > "$HOSTS_FILE"
git add "$HOSTS_FILE"

git commit -m "chore: update hosts (single snapshot)" || {
    echo "错误：hosts 提交失败" >&2
    git checkout "$BRANCH"
    exit 1
}

# ========== 第 4 步：强制推送 orphan 分支到 hosts-latest ==========
echo "==> [4/5] 强制推送至 $HOSTS_BRANCH 分支"
# 使用 refspec 方式推送，避免 rename 已有分支导致失败
git push --force "$REMOTE" "$ORPHAN_BRANCH:$HOSTS_BRANCH"

# ========== 第 5 步：切回 master 并清理临时分支 ==========
echo "==> [5/5] 切回 $BRANCH 分支并清理临时分支"
git checkout "$BRANCH"
git branch -D "$ORPHAN_BRANCH" >/dev/null 2>&1 || true

echo ""
echo "✅ 完成："
echo "  - 当前分支：$(git rev-parse --abbrev-ref HEAD)"
echo "  - master 分支历史未变动"
echo "  - hosts-latest 分支已更新为单快照"
echo "  - 下载地址："
echo "    https://gitlab.com/rainmor/Adhosts-block/-/raw/hosts-latest/hosts"
