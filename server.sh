#!/system/bin/sh
# server.sh - 模块后台守护进程
# 由 AxManager 在模块启用时启动，禁用时终止

# 配置文件
MODPATH="${0%/*}"
CONFIG_FILE="$MODPATH/config.conf"
PID_FILE="$MODPATH/server.pid"
LOG_FILE="$MODPATH/service.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$MODPATH/service.log"
}

cleanup() {
    log "Cleaning up before exit..."
    rm -f "$PID_FILE"
    exit 0
}

# 捕获终止信号（AxManager 发送 SIGTERM 来停止服务）
trap cleanup TERM INT

# 记录 PID
echo $$ > "$PID_FILE"
log "Server started (PID: $$)"

# 读取配置
if [ -f "$CONFIG_FILE" ]; then
    . "$CONFIG_FILE"
fi

# 定义限制函数
restrict_app() {
    local pkg="$1"
    dumpsys deviceidle whitelist -"$pkg"
    cmd appops set "$pkg" RUN_IN_BACKGROUND ignore
    cmd appops set "$pkg" RUN_ANY_IN_BACKGROUND ignore
    cmd appops set "$pkg" START_FOREGROUND ignore
    cmd appops set "$pkg" INSTANT_APP_START_FOREGROUND ignore
    am set-standby-bucket "$pkg" restricted
    cmd appops set "$pkg" WAKE_LOCK deny
    cmd appops set "$pkg" START_FOREGROUND ignore
    am force-stop "$pkg"
}

# 应用列表
APPS="cn.wps.moffice_eng.xiaomi.lite com.miui.securitymanager com.miui.cleanmaster com.miui.screenrecorder com.xiaomi.market com.android.deskclock com.miui.micloudsync com.lbe.security.miui com.xiaomi.metoknlp com.miui.cloudservice com.xiaomi.account com.xiaomi.simactivate.service com.xiaomi.xmsf com.unionpay.tsmservice.mi com.miui.guardprovider com.miui.securityadd com.miui.packageinstaller com.xiaomi.xmsfkeeper"

# 主循环
while true; do
    for pkg in $APPS; do
        restrict_app "$pkg"
    done
    log "Cycle completed, next run in ${interval:-30}s"
    sleep ${interval:-30}
done

cleanup
