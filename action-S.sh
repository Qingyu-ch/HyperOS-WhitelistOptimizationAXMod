#!/system/bin/sh
# action.sh - 手动执行一次系统后台优化（含全量系统应用扫描）
# 用法：可直接在终端执行，或通过 AxManager 的动作按钮触发

MODPATH="${0%/*}"
CONFIG_FILE="$MODPATH/config.conf"
LOG_FILE="$MODPATH/action.log"

# ---------- 关键系统组件黑名单（与 server.sh 保持一致）----------
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

# ---------- 函数定义 ----------
log() {
    local msg="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $msg" >> "$LOG_FILE"
    echo "$msg"  # 同时输出到终端
}

# 检查包名是否在黑名单中
is_protected() {
    local pkg="$1"
    local protected_list=$(echo "$SYSTEM_PROTECTED_PACKAGES" | tr '\n' ' ' | sed 's/  */ /g')
    echo "$protected_list" | grep -qw "$pkg"
}

# 限制单个应用的函数（与 server.sh 一致）
restrict_app() {
    local pkg="$1"
    [ -z "$pkg" ] && return

    if is_protected "$pkg"; then
        log "⏭️ Skipping protected component: $pkg"
        return
    fi

    log "🔧 Restricting: $pkg"
    dumpsys deviceidle whitelist -"$pkg" 2>/dev/null
    cmd appops set "$pkg" RUN_IN_BACKGROUND ignore 2>/dev/null
    cmd appops set "$pkg" RUN_ANY_IN_BACKGROUND ignore 2>/dev/null
    cmd appops set "$pkg" START_FOREGROUND ignore 2>/dev/null
    cmd appops set "$pkg" INSTANT_APP_START_FOREGROUND ignore 2>/dev/null
    am set-standby-bucket "$pkg" restricted 2>/dev/null
    cmd appops set "$pkg" WAKE_LOCK deny 2>/dev/null
    am force-stop "$pkg" 2>/dev/null
}

# 从 config.conf 解析包名（分号分隔）
parse_app_list() {
    local raw="$1"
    echo "$raw" | tr ';' '\n' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | grep -v '^$'
}

# ---------- 主流程 ----------
echo ""
echo "⚠️  5秒后将会优化全部系统软件和系统重要组件，如果不想要请立即退出界面（按 Ctrl+C）"
echo ""

# 等待 5 秒，期间可中断
sleep 5

# 检查 root 权限
HAS_ROOT=false
if [ "$(id -u)" -eq 0 ]; then
    HAS_ROOT=true
    log "✅ Running with root privileges."
else
    log "⚠️  No root detected. Some commands may fail (e.g., dumpsys whitelist)."
fi

# 加载 config 配置
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
else
    apps_to_restrict=""
    log "⚠️  Config file not found, using empty app list."
fi

# 1️⃣ 处理 config.conf 中指定的包名
log "📋 Processing apps from config.conf..."
config_pkgs=$(parse_app_list "$apps_to_restrict")
for pkg in $config_pkgs; do
    restrict_app "$pkg"
done

# 2️⃣ 扫描所有系统应用（排除黑名单）
log "🔍 Scanning all system apps..."
# 获取系统应用列表（-s 表示系统应用，-3 表示第三方应用，这里取系统应用）
all_system_pkgs=$(pm list packages -s 2>/dev/null | cut -d: -f2)
count=0
for pkg in $all_system_pkgs; do
    # 跳过已在 config 中处理过的包（避免重复）
    # 简单起见，直接全部处理，restrict_app 内部会跳过黑名单
    restrict_app "$pkg"
    count=$((count + 1))
done

log "Action completed! Total system apps processed: $count"
echo ""
echo "优化执行完毕，请查看日志：$LOG_FILE"