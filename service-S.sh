#!/system/bin/sh
# server.sh - 模块后台守护进程 (优化版，包名从config读取，自动过滤关键组件)

MODPATH="${0%/*}"
CONFIG_FILE="$MODPATH/config.conf"
PID_FILE="$MODPATH/server.pid"
LOG_FILE="$MODPATH/service.log"

# ---------- 关键系统组件黑名单（不会被限制）----------
# 这些包名即使出现在 config.conf 中也会被自动忽略
SYSTEM_PROTECTED_PACKAGES="
com.android.systemui
com.android.settings
com.miui.securitycenter
com.miui.home
com.miui.systemui.plugin
com.android.phone
com.android.server.telecom
com.qualcomm.qcrilmsgtunnel
com.miui.wmsvc
com.miui.cit
com.miui.securitycore
com.miui.rom
com.miui.core
com.xiaomi.finddevice
com.xiaomi.location.fused
com.xiaomi.smarthome
com.xiaomi.mico
com.miui.notes
com.android.providers.settings
com.android.providers.contacts
com.android.providers.media
com.android.providers.calendar
com.google.android.gms
com.google.android.gsf
com.android.vending
"
# 你可以根据实际系统版本自行增删，以上为常见关键组件

# ---------- 函数定义 ----------
log() {
    if [ "$enable_logging" = "true" ] || [ "$1" = "force" ]; then
        local msg="$1"
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >> "$LOG_FILE"
    fi
}

cleanup() {
    log "Server stopping, cleaning up..."
    rm -f "$PID_FILE"
    log "Server stopped."
    exit 0
}

trap cleanup TERM INT

# 记录 PID
echo $$ > "$PID_FILE"
log "Server started (PID: $$)"

# 加载配置
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
else
    interval=60
    enable_logging=true
    apps_to_restrict=""
    log "Config file not found, using defaults." "force"
fi

# 检查必要命令
for cmd in dumpsys cmd am; do
    if ! command -v "$cmd" &> /dev/null; then
        log "ERROR: Required command '$cmd' not found! Exiting." "force"
        cleanup
    fi
done

# 将黑名单字符串转为空格分隔的列表（方便 grep 匹配）
PROTECTED_LIST=$(echo "$SYSTEM_PROTECTED_PACKAGES" | tr '\n' ' ' | sed 's/  */ /g')

# 检查包名是否在黑名单中
is_protected() {
    local pkg="$1"
    # 使用 grep 精确匹配单词边界
    echo "$PROTECTED_LIST" | grep -qw "$pkg"
}

# 限制单个应用的函数
restrict_app() {
    local pkg="$1"
    [ -z "$pkg" ] && return

    # 跳过受保护的包
    if is_protected "$pkg"; then
        log "Skipping protected package: $pkg"
        return
    fi

    dumpsys deviceidle whitelist -"$pkg" 2>/dev/null
    cmd appops set "$pkg" RUN_IN_BACKGROUND ignore 2>/dev/null
    cmd appops set "$pkg" RUN_ANY_IN_BACKGROUND ignore 2>/dev/null
    cmd appops set "$pkg" START_FOREGROUND ignore 2>/dev/null
    cmd appops set "$pkg" INSTANT_APP_START_FOREGROUND ignore 2>/dev/null
    am set-standby-bucket "$pkg" restricted 2>/dev/null
    cmd appops set "$pkg" WAKE_LOCK deny 2>/dev/null
    am force-stop "$pkg" 2>/dev/null

    log "Restricted: $pkg"
}

# 从 apps_to_restrict 中解析包名（分号分隔）
parse_app_list() {
    local raw="$1"
    # 将分号替换为换行，然后去除空白行和前后空格
    echo "$raw" | tr ';' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$'
}

# ---------- 主循环 ----------
loop_count=0
while true; do
    loop_count=$((loop_count + 1))
    log "--- Cycle $loop_count starting ---"

    # 读取最新的 config（允许热修改）
    if [ -f "$CONFIG_FILE" ]; then
        . "$CONFIG_FILE"
    fi

    # 解析包名列表
    pkg_list=$(parse_app_list "$apps_to_restrict")

    for pkg in $pkg_list; do
        restrict_app "$pkg"
    done

    log "--- Cycle $loop_count completed, sleeping for ${interval}s ---"
    sleep "$interval"
done

cleanup
