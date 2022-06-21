#!/bin/bash
# 下载去广告hosts合并并去重

t=host       hn=hosts       an=adguard
f=host-full  hf=hosts-full  af=adguard-full

# 转换为 adguard 格式函数
adguard() {
  sed "1d;s/^/||/g;s/$/^/g" $1
}

# 去除误杀函数
manslaughter(){
  sed -i "/tencent\|c\.pc\|xmcdn\|googletagservices\|zhwnlapi\|samizdat/d" $1
}

# 海阔影视 hosts 导入成功
#curl -s https://gitee.com/qiusunshine233/hikerView/raw/master/ad_v1.txt > $t
#sed -i 's/\&\&/\n/g' $t
#curl -s https://gitee.com/qiusunshine233/hikerView/raw/master/ad_v2.txt >> $t
#sed -i '/\(\/\|@\|\*\|^\.\|\:\)/d;s/^/127.0.0.1 /g' $t && echo "海阔影视 hosts 导入成功"


# 导入hosts格式
while read i;do curl -s "$i">>$t&&echo "下载成功"||echo "$i 下载失败";done<<EOF
https://raw.githubusercontent.com/VeleSila/yhosts/master/hosts
https://raw.githubusercontent.com/jdlingyu/ad-wars/master/hosts
https://raw.githubusercontent.com/Goooler/1024_hosts/master/hosts
https://raw.githubusercontent.com/shiqianwei0508/Adhosts-block/master/sqwei/hosts
https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts
https://raw.githubusercontent.com/ilpl/ad-hosts/master/hosts
https://raw.githubusercontent.com/neodevpro/neodevhost/master/lite_host
https://raw.githubusercontent.com/francis-zhao/quarklist/master/dist/hosts
EOF
#https://raw.githubusercontent.com/BlackJack8/iOSAdblockList/master/Regular%20Hosts.txt
#https://hblock.molinero.dev/hosts
#https://raw.githubusercontent.com/badmojr/1Hosts/master/Xtra/hosts.txt
#https://raw.githubusercontent.com/Cats-Team/AdRules/main/hosts.txt
#https://raw.githubusercontent.com/E7KMbb/AD-hosts/master/system/etc/hosts

# 域名加速hosts
# curl -s https://raw.githubusercontent.com/521xueweihan/GitHub520/master/hosts | sed "/#/d;s/ \{2,\}/ /g" > gh
curl -s https://raw.githubusercontent.com/Cats-Team/AdRules/main/rules/fasthosts.txt | sed "/#/d;s/ \{2,\}/ /g" > gh


# EnergizedProtection 域名白名单
#curl -s https://raw.githubusercontent.com/EnergizedProtection/unblock/master/basic/formats/domains.txt | sed "/#/d;s/ \{2,\}/ /g" > wlist

# 自己维护的域名白名单
curl -s https://raw.githubusercontent.com/shiqianwei0508/Adhosts-block/master/hosts_allow | sed "/#/d;s/ \{2,\}/ /g" >> wlist

# keytoolazy
curl -s https://keytoolazy.coding.net/p/hms-core/d/HMS-CORE/git/raw/master/other/%E6%8E%92%E9%99%A4%E5%88%97%E8%A1%A8.prop | sed "/#/d;s/ \{2,\}/ /g" >> wlist

# 冷莫 hosts
# curl -s https://file.trli.club/dns/ad-hosts.txt | sed "/==/d;/^$/d;1d;s/0.0.0.0 /127.0.0.1 /g;/^\:\|^\*/d" > $f
# curl -s https://file.trli.club/dns/ad-domains.txt | sed "/^#/d" | awk '{print "127.0.0.1 "$0}' > $f

# 转换换行符
dos2unix *
dos2unix */*

# 保留必要 host
# 只保留 127、0 开头的行
sed -i "/^\s*\(127\|0\)/!d" $t
# 删除空白符和 # 及后
sed -i "s/\s\|#.*//g" $t
# 删除 127.0.0.1 、 0.0.0.0 、 空行、第一行
sed -i "s/^\(127.0.0.1\|0.0.0.0\)//g" $t

#curl -s https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/anti-ad-domains.txt | sed "/#/d;s/ \{2,\}/ /g" >> $t

# 导入domain list格式
while read i;do curl -s "$i">>$t&&echo "下载成功"||echo "$i 下载失败";done<<EOF
https://raw.githubusercontent.com/privacy-protection-tools/anti-AD/master/anti-ad-domains.txt
EOF


sed -i "s/\s\|#.*//g" $t
# 删除 . 或 * 开头的
sed -i "/^\.\|^\*/d" $t

# 使用声明
statement="# 更新时间：$(date '+%Y-%m-%d %T')\n# 开源地址：https://github.com/shiqianwei0508/Adhosts-block.git\n# 严正声明：仅供自用，请勿商用\n\n"

# 获得标准去重版 host
sort -u $t -o $t
sed -i "/^127.0.0.1$/d;/^0.0.0.0$/d;/^\s*$/d" $t

# 去除误杀
#manslaughter $t

# 获得标准版 hosts
#(echo -e $statement && sed "s/^/127.0.0.1 /g" $t && cat gh) > $hn
(echo -e $statement && sed "s/^/0.0.0.0 /g" $t && cat gh) > $hn
#(echo -e $statement && sed "s/^/127.0.0.1 /g" $t) > $hn

# 配置域名白名单
#for i in `cat wlist1`;do
#   sed -i "/$i/d" $hn
#done
for i in `cat wlist`;do
   sed -i "/0.0.0.0 $i$/d" $hn
done


# 获得标准 adguard 版规则
# adguard $t > $an


# 获得拓展去重版 host
# cat $t $f | sort -u -o $f
# sed -i "/^127.0.0.1$/d;/^0.0.0.0$/d;/^\s*$/d" $f
# manslaughter $f
# 删除 . 或 * 开头的
# sed -i "/^\.\|^\*/d" $f

# 获得拓展版 hosts
# (echo -e $statement && sed "s/^/127.0.0.1 /g" $f && cat gh) > $hf
# (echo -e $statement && sed "s/^/127.0.0.1 /g" $f) > $hf

# 清洗 127.0.0.1 127.0.0.1
# sed -i 's+127.0.0.1 127.0.0.1 +127.0.0.1 +g' $hf
# cat $hf | sort -u -o $hf

# 获得拓展 adguard 版规则
# adguard $f > $af


#rm $t $f gh
#rm $t $f
rm $t gh wlist
