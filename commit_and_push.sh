#!/usr/bin/env bash
# ============================================================
# commit_and_push.sh —— 生成 hosts 并提交，且只保留“最新一份” hosts 历史
#
# 设计目标：
#   1) 运行 update_action.sh 重新生成最新的 hosts（不保存旧的那份）
#   2) 用 git filter-branch 把历史里所有的 hosts 旧版本彻底抹掉
#   3) 仅把这份最新生成的 hosts 作为“唯一一份”提交进仓库
#   4) force push 覆盖远程，使远程历史同样只保留一份 hosts
#
# 注意：
#   - hosts 是生成产物，随时可重新生成，因此本脚本不做任何备份。
#   - 本脚本会重写 git 历史（所有提交 hash 改变），并 force push。
#   - 其他所有代码/配置（update_action.sh、hosts_allow、sqwei/、docs 等）
#     的历史完好保留，不受影响。
#   - 使用 git 自带的 filter-branch（兼容 Git 2.30，无需额外安装 filter-repo）。
# ============================================================
set -e

# 切换到脚本所在目录（项目根目录）
cd "$(dirname "$0")"

REMOTE="origin"
BRANCH="master"
HOSTS_FILE="hosts"

echo "==> [1/5] 校验环境与远程"
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    echo "错误：当前目录不是 git 仓库" >&2
    exit 1
fi
if ! git remote get-url "$REMOTE" >/dev/null 2>&1; then
    echo "错误：未找到远程 '$REMOTE'" >&2
    exit 1
fi
if ! git filter-branch --help >/dev/null 2>&1; then
    echo "错误：当前 git 不支持 filter-branch（需 Git 2.30+ 自带）" >&2
    exit 1
fi

echo "==> [2/5] 运行 update_action.sh 生成最新 hosts"
if [ -f update_action.sh ]; then
    bash update_action.sh
else
    echo "错误：未找到 update_action.sh" >&2
    exit 1
fi
if [ ! -f "$HOSTS_FILE" ]; then
    echo "错误：生成失败，$HOSTS_FILE 不存在" >&2
    exit 1
fi

echo "==> [3/5] 用 git filter-branch 清除历史中所有的 hosts 旧版本"
# 从每一个历史提交的索引中删除 hosts；--prune-empty 去掉因此变空的提交
git filter-branch --force --index-filter \
    "git rm --cached --ignore-unmatch '$HOSTS_FILE'" \
    --prune-empty -- --all
# 清理 filter-branch 遗留的备份引用与悬空对象，确保历史真正干净
git for-each-ref --format='%(refname)' refs/original/ | \
    while read -r ref; do git update-ref -d "$ref"; done
git reflog expire --expire=now --all
git gc --prune=now

echo "==> [4/5] 仅提交最新一份 hosts（历史中只此一份）"
git add "$HOSTS_FILE"
git commit -m "chore: 更新 hosts（仅保留最新一份，历史已清理）" || echo "    无可提交的 hosts 变更，跳过"

echo "==> [5/5] force push 覆盖远程（历史已重写）"
git push --force "$REMOTE" "$BRANCH"

echo ""
echo "完成：仓库中已保留最新 hosts 的唯一一份，历史中的旧 hosts 变更已全部清除。"
