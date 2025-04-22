#!/bin/bash

# 颜色输出函数
red() { echo -e "\033[31m\033[01m$@\033[0m"; }
green() { echo -e "\033[32m\033[01m$@\033[0m"; }
yellow() { echo -e "\033[33m\033[01m$@\033[0m"; }
blue() { echo -e "\033[34m\033[01m$@\033[0m"; }
plain() { echo -e "\033[0m$@\033[0m"; }
readp() { read -p "$(yellow "$1")" input; eval $2=\$input; }

# 初始化变量
port=40000     # 默认端口
sw46=4         # 默认协议参数

# 创建工作目录
mkdir -p /usr/local/psiphon

# 检测IP类型
v4v6() {
    v4=$(curl -s4m5 ip.gs -k)
    v6=$(curl -s6m5 ip.gs -k)
}

# 显示当前状态
show_status() {
    echo "------------------------------------------------------------------------------------"
    if [[ -n $(ps -e | grep xuiwpph) ]]; then
        s5port=$(cat /usr/local/psiphon/swpph.log 2>/dev/null | awk '{print $3}'| awk -F":" '{print $NF}')
        s5gj=$(cat /usr/local/psiphon/swpph.log 2>/dev/null | awk '{print $6}')
        case "$s5gj" in
            AT) showgj="奥地利" ;;
            AU) showgj="澳大利亚" ;;
            BE) showgj="比利时" ;;
            BG) showgj="保加利亚" ;;
            CA) showgj="加拿大" ;;
            CH) showgj="瑞士" ;;
            CZ) showgj="捷克" ;;
            DE) showgj="德国" ;;
            DK) showgj="丹麦" ;;
            EE) showgj="爱沙尼亚" ;;
            ES) showgj="西班牙" ;;
            FI) showgj="芬兰" ;;
            FR) showgj="法国" ;;
            GB) showgj="英国" ;;
            HR) showgj="克罗地亚" ;;
            HU) showgj="匈牙利" ;;
            IE) showgj="爱尔兰" ;;
            IN) showgj="印度" ;;
            IT) showgj="意大利" ;;
            JP) showgj="日本" ;;
            LT) showgj="立陶宛" ;;
            LV) showgj="拉脱维亚" ;;
            NL) showgj="荷兰" ;;
            NO) showgj="挪威" ;;
            PL) showgj="波兰" ;;
            PT) showgj="葡萄牙" ;;
            RO) showgj="罗马尼亚" ;;
            RS) showgj="塞尔维亚" ;;
            SE) showgj="瑞典" ;;
            SG) showgj="新加坡" ;;
            SK) showgj="斯洛伐克" ;;
            US) showgj="美国" ;;
        esac
        grep -q "country" /usr/local/psiphon/swpph.log 2>/dev/null && s5ms="多地区Psiphon代理模式 (端口:$s5port  国家:$showgj)" || s5ms="本地Warp代理模式 (端口:$s5port)"
        echo -e "WARP-plus-Socks5状态：$(blue "已启动") $s5ms"
    else
        echo -e "WARP-plus-Socks5状态：$(blue "未启动")"
    fi
    echo "------------------------------------------------------------------------------------"
}

# 安装核心功能
ins() {
    # 清理旧进程
    [ -f /usr/local/psiphon/swpphid.log ] && kill -15 $(cat /usr/local/psiphon/swpphid.log) >/dev/null 2>&1
    
    # 架构检测和下载
    if [ ! -e /usr/local/psiphon/swpph ]; then
        case $(uname -m) in
            aarch64) cpu=arm64 ;;
            x86_64)  cpu=amd64 ;;
            *) red "不支持的CPU架构!" && exit 1 ;;
        esac
        
        yellow "正在下载xuiwpph二进制文件..."
        if ! curl -L -o /usr/local/psiphon/swpph --retry 2 --insecure "https://raw.githubusercontent.com/yonggekkk/x-ui-yg/main/xuiwpph_$cpu"; then
            red "文件下载失败!" && exit 1
        fi
        chmod +x /usr/local/psiphon/swpph
    fi

    # 检测IP类型
    v4v6
    if [[ -n $v4 ]]; then
        sw46=4
    else
        red "未检测到IPv4地址，请确保已安装WARP IPv4模式!"
        sw46=6
    fi

    # 端口设置
    echo
    readp "设置WARP-plus-Socks5端口[默认40000]：" port
    [ -z "$port" ] && port=40000
    
    # 端口占用检测
    while :; do
        if ss -tunlp | awk '{print $5}' | grep -q ":$port$"; then
            yellow "端口 $port 被占用，请重新输入!"
            readp "请输入新端口：" port
        else
            break
        fi
    done
}

# 卸载功能
unins() {
    [ -f /usr/local/psiphon/swpphid.log ] && kill -15 $(cat /usr/local/psiphon/swpphid.log) >/dev/null 2>&1
    rm -f /usr/local/psiphon/swpph.log /usr/local/psiphon/swpphid.log
    
    # 清理定时任务
    crontab -l | grep -v xuiwpphid.log | crontab -
    green "已清除所有WARP-plus-Socks5相关配置!"
}

# 主菜单
while true; do
    clear
    echo
    yellow "=============== WARP-plus-Socks5 高级管理脚本 ==============="
    show_status
    yellow " 1. 启动本地WARP代理模式 (自动优选IP)"
    yellow " 2. 启动多地区代理模式 (手动选择国家)"
    yellow " 3. 停止并卸载代理服务"
    yellow " 0. 退出脚本"
    echo
    readp "请输入操作编号 [0-3]：" menu
    
    case $menu in
        1)
            ins
            nohup setsid /usr/local/psiphon/swpph -b 127.0.0.1:$port --gool -$sw46 >/dev/null 2>&1 &
            echo "$!" > /usr/local/psiphon/swpphid.log
            
            green "\n正在申请IP... (约需20秒)" && sleep 20
            
            # IP验证
            resv1=$(curl -sx socks5://localhost:$port icanhazip.com)
            resv2=$(curl -sx socks5h://localhost:$port icanhazip.com)
            
            if [[ -n $resv1 || -n $resv2 ]]; then
                echo "/usr/local/psiphon/swpph -b 127.0.0.1:$port --gool -$sw46 >/dev/null 2>&1" > /usr/local/psiphon/swpph.log
                # 设置开机启动
                crontab -l | grep -v xuiwpphid.log | {
                    cat
                    echo "@reboot /bin/bash -c 'nohup setsid $(cat /usr/local/psiphon/swpph.log) & echo \$! > /usr/local/psiphon/swpphid.log'"
                } | crontab -
                green "成功启动! socks5信息：127.0.0.1:$port | 出口IP: $resv1"
            else
                red "IP申请失败!" && unins
            fi
            ;;
            
        2)
            ins
            echo
            yellow "=================== 国家/地区代码表 ==================="
            echo "
AT-奥地利       AU-澳大利亚       BE-比利时
BG-保加利亚      CA-加拿大        CH-瑞士
CZ-捷克         DE-德国          DK-丹麦
EE-爱沙尼亚      ES-西班牙        FI-芬兰
FR-法国         GB-英国          HR-克罗地亚
HU-匈牙利       IE-爱尔兰        IN-印度
IT-意大利       JP-日本          LT-立陶宛
LV-拉脱维亚      NL-荷兰          NO-挪威
PL-波兰         PT-葡萄牙        RO-罗马尼亚
RS-塞尔维亚      SE-瑞典          SG-新加坡
SK-斯洛伐克      US-美国          GR-希腊
NZ-新西兰       KR-韩国          BR-巴西
TR-土耳其       ZA-南非          IS-冰岛
IL-以色列       MY-马来西亚       PH-菲律宾
TH-泰国         VN-越南          AE-阿联酋
SA-沙特阿拉伯    UA-乌克兰        RU-俄罗斯
MX-墨西哥       AR-阿根廷        CL-智利
CO-哥伦比亚      PE-秘鲁          CN-中国(需特殊配置)
            "
            readp "请输入国家代码(大写字母 如US)：" guojia
            
            nohup setsid /usr/local/psiphon/swpph -b 127.0.0.1:$port --cfon --country $guojia -$sw46 >/dev/null 2>&1 &
            echo "$!" > /usr/local/psiphon/swpphid.log
            
            green "\n正在申请 $guojia 地区IP..." && sleep 20
            
            # IP验证
            resv1=$(curl -sx socks5://localhost:$port icanhazip.com)
            if [[ -n $resv1 ]]; then
                echo "/usr/local/psiphon/swpph -b 127.0.0.1:$port --cfon --country $guojia -$sw46 >/dev/null 2>&1" > /usr/local/psiphon/swpph.log
                # 设置开机启动
                crontab -l | grep -v xuiwpphid.log | {
                    cat
                    echo "@reboot /bin/bash -c 'nohup setsid $(cat /usr/local/psiphon/swpph.log) & echo \$! > /usr/local/psiphon/swpphid.log'"
                } | crontab -
                green "成功连接 $guojia!  socks5信息：127.0.0.1:$port | 出口IP: $resv1"
            else
                red "连接失败，请尝试其他地区!" && unins
            fi
            ;;
            
        3)
            unins
            ;;
            
        0)
            exit 0
            ;;
        *)
            red "无效输入，请重新选择!"
            sleep 1
            ;;
    esac
    
    read -p "按回车键继续..."
done
