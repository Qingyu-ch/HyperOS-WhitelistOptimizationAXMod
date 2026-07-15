#!/system/bin/sh
# 这里编辑的脚本会在模块底部显示"执行"按钮，点击"执行"将会执行此脚本

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

APPS="cn.wps.moffice_eng.xiaomi.lite com.miui.securitymanager com.miui.cleanmaster com.miui.screenrecorder com.xiaomi.market com.android.deskclock com.miui.micloudsync com.lbe.security.miui com.xiaomi.metoknlp com.miui.cloudservice com.xiaomi.account com.xiaomi.simactivate.service com.xiaomi.xmsf com.unionpay.tsmservice.mi com.miui.guardprovider com.miui.securityadd com.miui.packageinstaller com.xiaomi.xmsfkeeper"

for pkg in $APPS; do
    restrict_app "$pkg"
done

echo "- 执行完成！"
