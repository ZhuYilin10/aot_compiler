#!/system/bin/sh

ui_print "*******************************"
ui_print "  AOT 编译器 v1.2.0"
ui_print "  一键 dex2oat AOT 编译"
ui_print "*******************************"

chmod 755 "$MODPATH/bin/aot.sh"
chmod 755 "$MODPATH/bin"

SDK=$(getprop ro.build.version.sdk 2>/dev/null)
ABI=$(getprop ro.product.cpu.abi 2>/dev/null)
ui_print "- 设备: $(getprop ro.product.model) / $ABI"
ui_print "- Android SDK: $SDK"

case "$SDK" in
    ''|*[!0-9]*) ui_print "- 无法识别 SDK，使用兼容模式" ;;
    *)
        if [ "$SDK" -ge 34 ]; then
            ui_print "- 作用域: --full (Android 14+)"
        else
            ui_print "- 作用域: 默认 + --secondary-dex (Android 13 及以下)"
        fi
        ;;
esac

ui_print "- 安装完成，请在模块页面点开 WebUI 使用"
