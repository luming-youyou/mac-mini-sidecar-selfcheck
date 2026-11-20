#!/bin/zsh
# ============================================================
#  随航套装 · 设备自检
#  下单前先跑这个：自动检查你的 Mac 是否满足全部条件。
#  用法：双击运行（若提示"未验证的开发者"，右键 → 打开）
# ============================================================
emulate -L zsh

# 只在真正的交互终端里等待按键（管道/自动化环境下直接跳过，避免挂住）
pause_read() { [[ -t 0 ]] && { read -k 1 2>"/dev/null" || true }; }

# ---------- 解除「下载隔离」属性（第一步就该做）----------
# 为什么必须做：从网上下载的压缩包，解压后每个文件都会带上 com.apple.quarantine；
# 带着这个属性启动的程序，macOS 会直接杀掉进程 —— 没有弹窗、没有报错。
# 这是买家反馈「装完了却毫无反应」的头号原因，所以在自检里先把整包解开。
SELF_DIR="${0:A:h}"
/usr/bin/xattr -dr com.apple.quarantine "$SELF_DIR" 2>/dev/null

R=$'\e[31m'; G=$'\e[32m'; Y=$'\e[33m'; B=$'\e[1m'; D=$'\e[2m'; N=$'\e[0m'

PASS=0; FAIL=0; MAN=0
ok()  { print "  ${G}[通过]${N} $1"; PASS=$((PASS+1)) }
bad() { print "  ${R}[不通过]${N} $1"; FAIL=$((FAIL+1)) }
man() { print "  ${Y}[待确认]${N} $1"; MAN=$((MAN+1)) }
hdr() { print; print "${B}$1${N}" }

print "${B}================================================${N}"
print "${B}          随航套装 · 设备自检${N}"
print "${B}================================================${N}"

# ---------------- 1. 系统 ----------------
hdr "【1】系统要求"

ver=$(sw_vers -productVersion)
major=${ver%%.*}
if (( major >= 14 )); then
  ok "macOS $ver（要求 14 或更高）"
else
  bad "macOS $ver —— 低于 14，本套装不支持"
fi

arch=$(uname -m)
if [[ $arch == arm64 ]]; then
  ok "芯片架构 $arch（Apple Silicon）"
else
  bad "芯片架构 $arch —— 本套装目前只支持 Apple Silicon（M 系列芯片）"
fi

# ---------------- 2. 无头运行的两个硬条件 ----------------
hdr "【2】无头运行的两个硬条件（缺一不可）"

fv=$(fdesetup status 2>/dev/null)
if [[ $fv == *"FileVault is Off"* ]]; then
  ok "文件保险箱（FileVault）已关闭"
else
  bad "文件保险箱（FileVault）处于开启状态"
  print "     ${D}为什么必须关：无头开机时它会卡在解锁界面，等不到桌面${N}"
  print "     ${D}怎么关：系统设置 → 隐私与安全性 → 文件保险箱 → 关闭${N}"
fi

auto=$(defaults read /Library/Preferences/com.apple.loginwindow autoLoginUser 2>/dev/null || print "")
if [[ -n $auto ]]; then
  ok "自动登录已开启（账户：$auto）"
else
  man "自动登录未开启（可运行，但每次开机需人工登录一次）"
  print "     ${D}开启后＝无人值守：开机自动连，全程零操作${N}"
  print "     ${D}不开启也能用：开机后在键盘上盲输密码回车即可（实测可行）${N}"
  print "     ${D}怎么开：系统设置 → 用户与群组 → 自动登录 → 选你的账户${N}"
fi

# ---------------- 3. 硬件环境 ----------------
hdr "【3】硬件环境"

n=$(/usr/sbin/system_profiler SPDisplaysDataType 2>/dev/null | grep -cE '^        [^ ]')
if (( n > 0 )); then
  ok "检测到显示输出（自检需要屏幕，正常）"
else
  man "当前没有检测到显示器 —— 首次安装需要临时接一次屏幕"
fi

if /usr/bin/nc -z 127.0.0.1 22 2>/dev/null; then
  ok "远程登录已开启（可选，用于 iPad 快捷指令遥控）"
else
  man "远程登录未开启（可选）"
  print "     ${D}想用 iPad 快捷指令遥控开关的话才需要：${N}"
  print "     ${D}系统设置 → 通用 → 共享 → 远程登录 → 打开${N}"
fi

# ---------------- 3.5 型号识别 ----------------
hdr "【3.5】iPad 型号识别（决定画面清晰度）"

# SELF_DIR 是「交付包/」这一层，kit 就在它下面
MODELBIN="$SELF_DIR/kit/sidecar-model"
if [[ -x $MODELBIN ]]; then
  m=$("$MODELBIN" 2>/dev/null | head -1)
  if [[ -n $m ]]; then
    ok "已识别 iPad 型号：$m"
    print "     ${D}启动时会据此自动匹配分辨率，做到 1 像素对 1 像素${N}"
  else
    man "未识别到 iPad 型号（可能尚未配对成功过随航）"
    print "     ${D}不影响使用：会退回通用分辨率，画面正常${N}"
  fi
else
  man "未找到型号识别工具（安装包可能不完整）"
fi

# ---------------- 4. 手动确认项 ----------------
hdr "【4】需要你手动确认的两项（脚本查不到，请自己核对）"

man "Mac：锁屏密码（设不设都能用，看你偏好）"
print "     ${D}设为【永不】＝最省事；保留密码＝更安全，敲一下键盘唤出密码框，看着 iPad 画面输入即可${N}"
print "     ${D}位置：系统设置 → 锁定屏幕 →「屏幕保护程序开始或显示器关闭后需要密码」${N}"

man "iPad：建议把「自动锁定」设为【永不】"
print "     ${D}iPad → 设置 → 显示与亮度 → 自动锁定 → 永不${N}"
print "     ${D}不设的后果：iPad 中途熄屏，需点亮并敲一下键盘唤醒（能恢复，多一步）${N}"

# ---------------- 结论 ----------------
hdr "【5】结论"
print "  通过 ${G}$PASS${N} 项　不通过 ${R}$FAIL${N} 项　待手动确认 ${Y}$MAN${N} 项"
print

if (( FAIL == 0 )); then
  print "  ${G}${B}你的设备满足条件，可以购买。${N}"
  print
  print "  ${D}接下来的步骤：${N}"
  print "  ${D}1. 运行「2-安装」${N}"
  print "  ${D}2. 按提示重启一次${N}"
  print "  ${D}3. 拔掉显示器，iPad 会自动亮起（实测约 7 秒）${N}"
else
  print "  ${R}${B}有 $FAIL 项不达标，暂时无法使用。${N}"
  print
  print "  ${D}请先解决上面标 [不通过] 的问题，再重新运行本自检。${N}"
fi

print
print "${D}按任意键关闭窗口${N}"
pause_read
