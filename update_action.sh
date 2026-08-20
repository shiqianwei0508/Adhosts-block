#!/usr/bin/env bash
set -e
# set -x  # 调试时取消注释

# ============================================================
# 去广告 hosts 合并脚本
# 功能：下载多个去广告 hosts 源 -> 合并清洗去重 -> 套用白名单 -> 生成 hosts
# 依赖：curl / sed / sort / dos2unix
# 注意：需在项目根目录运行（脚本使用相对路径读取白名单与本地源）
# ============================================================

# ============================================================
# 配置区（经常手动修改的项都放在这里）
# ============================================================

# 最终生成的标准 hosts 文件名（磁盘文件名，一般无需改动）
output_hosts="hosts"

# 本地白名单 / 加速源路径（相对项目根目录）
allow_list_file="hosts_allow"          # 精确域名白名单
wildcard_allow_file="hosts_allow_g"    # 泛域名白名单
local_accel_file="sqwei/hosts_rewrite" # 本地域名加速源

# 去广告 hosts 源（hosts 格式，一个 URL 一行，可自由增删）
hosts_sources=(
    "https://gitlab.com/rainmor/Adhosts-block/-/raw/master/sqwei/hosts"
    "https://raw.githubusercontent.com/francis-zhao/quarklist/master/dist/hosts"
    "https://raw.githubusercontent.com/jdlingyu/ad-wars/master/sha_ad_hosts"
    "https://raw.githubusercontent.com/ilpl/ad-hosts/master/hosts"
    "https://raw.githubusercontent.com/lingeringsound/10007/main/all"
    "https://raw.githubusercontent.com/bigdargon/hostsVN/master/hosts"
    "https://gitlab.com/andryou/block/raw/master/chibi"
)

# 域名加速 hosts 源（追加到加速列表）
accel_sources=(
    "https://gitlab.com/ineo6/hosts/-/raw/master/hosts"
    "https://raw.githubusercontent.com/yangFenTuoZi/fcm-hosts/refs/heads/master/hosts"
)

# 纯域名格式的去广告源（直接提取域名，无需清洗前缀）
domain_sources=(
    "https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/anti-ad-domains.txt"
)
# 纯域名源（需替换前缀，如 mosdns 的 "domain:" 前缀）
domain_sources_sed=(
    "https://bitbucket.org/hacamer/adrules/raw/main/mosdns_adrules.txt|s/domain://"
)

# 备用下载源（按需取消注释后复制到上面对应数组启用）
# hosts 格式：
#   https://raw.githubusercontent.com/Cats-Team/AdRules/main/hosts.txt
#   https://hblock.molinero.dev/hosts
#   https://raw.githubusercontent.com/neodevpro/neodevhost/master/lite_host
#   https://raw.githubusercontent.com/hoshsadiq/adblock-nocoin-list/master/hosts.txt
#   https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews-gambling-social-only/hosts
#   https://hosts.ubuntu101.co.za/hosts
#   https://raw.githubusercontent.com/Goooler/1024_hosts/master/hosts
#   https://raw.githubusercontent.com/VeleSila/yhosts/master/hosts
#   https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
#   https://raw.githubusercontent.com/BlackJack8/iOSAdblockList/master/Regular%20Hosts.txt
#   https://raw.githubusercontent.com/badmojr/1Hosts/master/Xtra/hosts.txt
#   https://raw.githubusercontent.com/E7KMbb/AD-hosts/master/system/etc/hosts

# ============================================================
# 临时文件名（语义化变量，磁盘文件名保持原值，一般无需改动）
# ============================================================
tmp_domains="host"           # 合并后的去广告域名临时文件
accel_hosts="gh"             # 域名加速列表临时文件
whitelist="wlist"            # 精确域名白名单（来自 hosts_allow）
wildcard_whitelist="g_wlist" # 泛域名白名单（来自 hosts_allow_g）

# ------------------------------------------------------------
# curl 代理开关
# ------------------------------------------------------------
enable_curl_proxy() {
    if [ ! -f ~/.curlrc ]; then
        if [ -f ~/.curlrc.bak ]; then
            mv ~/.curlrc.bak ~/.curlrc
            echo "Renamed ~/.curlrc.bak to ~/.curlrc"
        else
            echo "No ~/.curlrc.bak file found"
        fi
    else
        echo "File ~/.curlrc already exists"
    fi
}

disable_curl_proxy() {
    mv ~/.curlrc ~/.curlrc.bak
}

# ------------------------------------------------------------
# 下载单个 hosts 源并追加到目标文件
# ------------------------------------------------------------
fetch_source() {
    local url="$1"
    local target="$2"
    if curl -s "$url" >> "$target"; then
        echo "$url 下载成功"
    else
        echo "$url 下载失败"
    fi
}

# ------------------------------------------------------------
# 规范化列表文件：
#   删除 # 注释行、压缩 2+ 空格为 1 空格、去除行尾空格
#   用于白名单 / 本地加速源等“读取即清洗”的场景
#   用法：normalize_list <源文件> <目标文件>（追加到目标）
# ------------------------------------------------------------
normalize_list() {
    local src="$1"
    local target="$2"
    sed "/#/d;s/ \{2,\}/ /g;s/ *$//" "$src" >> "$target"
}

# ------------------------------------------------------------
# 就地清洗已存在的列表文件：
#   删除 # 注释行、压缩 2+ 空格为 1 空格、去除行尾空格
#   与 normalize_list 规则一致，但作用于“已下载到本地的文件”
#   用法：sanitize_inplace <文件>
# ------------------------------------------------------------
sanitize_inplace() {
    sed -i "/#/d;s/ \{2,\}/ /g;s/ *$//" "$1"
}

# ------------------------------------------------------------
# 删除文件中的空行（含纯空白行）
#   用法：strip_blank_lines <文件>
# ------------------------------------------------------------
strip_blank_lines() {
    sed -i "/^\s*$/d" "$1"
}

# ------------------------------------------------------------
# 清洗域名列表：
#   1) 只保留 127/0 开头的 hosts 行
#   2) 删除空白符与 # 及其后内容
#   3) 删除 127.0.0.1 / 0.0.0.0 前缀，得到纯域名
# ------------------------------------------------------------
clean_domains() {
    sed -i -e "/^\s*\(127\|0\)/!d" \
           -e "s/\s\|#.*//g" \
           -e "s/^\(127.0.0.1\|0.0.0.0\)//g" "$1"
}

# ============================================================
# 主流程
# ============================================================

# 1. 开启 curl 代理
enable_curl_proxy

# 2. 下载去广告 hosts 源（hosts 格式）
for url in "${hosts_sources[@]}"; do
    fetch_source "$url" "$tmp_domains"
done

# 3. 下载域名加速 hosts，并合并本地加速源
for url in "${accel_sources[@]}"; do
    fetch_source "$url" "$accel_hosts"
done
normalize_list "$local_accel_file" "$accel_hosts"
# 加速源下载内容含 # 注释行，需统一清洗（与本地源规则一致），否则会泄漏到最终 hosts
sanitize_inplace "$accel_hosts"

# 4. 读取本地白名单（精确 / 泛域名）
# 删注释行、压缩多空格、去除行尾空格（避免尾随空格导致白名单匹配失效）
normalize_list "$allow_list_file" "$whitelist"
normalize_list "$wildcard_allow_file" "$wildcard_whitelist"

# 5. 清洗下载数据，提取纯域名
clean_domains "$tmp_domains"

# 6. 追加纯域名格式的去广告源
for url in "${domain_sources[@]}"; do
    fetch_source "$url" "$tmp_domains"
done
for entry in "${domain_sources_sed[@]}"; do
    src_url="${entry%%|*}"
    src_sed="${entry#*|}"
    curl -s "$src_url" | sed "$src_sed" >> "$tmp_domains"
done

# 7. 统一换行符
dos2unix "$tmp_domains" "$accel_hosts" "$whitelist" "$wildcard_whitelist"

# 8. 二次清洗：删除空白/# 及 . * | 开头的行
sed -i -e "s/\s\|#.*//g" \
       -e "/^\.\|^\*\|^|/d" "$tmp_domains"

# 9. 组装文件头并去重
file_header="# 更新时间：$(date '+%Y-%m-%d %T')\n# hosts获取：https://gitlab.com/rainmor/Adhosts-block/-/raw/master/hosts\n# 邮箱： sqwei2012@gmail.com\n# 如果存在误杀情况，请通过邮件把被误杀的APP或者域名发给我，谢谢！\n\n"

sort -u "$tmp_domains" -o "$tmp_domains"
sed -i -e "/^127.0.0.1$/d" \
       -e "/^0.0.0.0$/d" "$tmp_domains"
strip_blank_lines "$tmp_domains"

# 10. 生成标准 hosts：文件头 + 域名列表 + 加速 hosts
# 加速 hosts 直接 cat 拼接，需先清除空行，避免泄漏到最终文件
strip_blank_lines "$accel_hosts"
(echo -e "$file_header" && sed "s/^/0.0.0.0 /g" "$tmp_domains" && cat "$accel_hosts") > "$output_hosts"

# 11. 应用精确白名单：删除 0.0.0.0 <domain> 行
while read -r domain; do
    [ -n "$domain" ] || continue
    sed -i "/0.0.0.0 ${domain}$/d" "$output_hosts"
done < "$whitelist"

# 12. 应用泛域名白名单：删除 0.0.0.0 <任意前缀>.<domain> 行
while read -r domain; do
    [ -n "$domain" ] || continue
    sed -i "/0.0.0.0 .*.${domain}$/d" "$output_hosts"
done < "$wildcard_whitelist"

# 13. 清理临时文件并关闭 curl 代理
rm -f "$tmp_domains" "$accel_hosts" "$whitelist" "$wildcard_whitelist"
disable_curl_proxy
