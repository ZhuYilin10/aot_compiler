#!/system/bin/sh
# ---------------------------------------------------------------------------
# AOT 编译器 - KernelSU / Magisk WebUI 后端
#
#   start <filter> <scope>   启动编译
#       filter: everything | speed | speed-profile | verify
#       scope : all | third | <包名>
#   stop                     停止任务并取消系统侧 dexopt 作业
#   status                   输出状态键值对
#   log [n]                  输出日志尾部 n 行（默认 300）
#   reset                    重置全部应用的 dexopt 状态
#   cleanup                  清理无用 odex/vdex
#   query <包名>             查看单个应用的编译状态
#   info                     设备与环境信息
#   version                  输出版本
#   _run <filter> <scope>    内部：后台工作进程
# ---------------------------------------------------------------------------

VERSION=1.2.0

BASE=${AOT_BASE:-/data/local/tmp/aot_compiler}
LOG=$BASE/aot.log
STATE=$BASE/state
TOTAL=$BASE/total
COUNT=$BASE/count
FILTERF=$BASE/filter
SCOPEF=$BASE/scope
STARTF=$BASE/start
ENDF=$BASE/end
PIDF=$BASE/pid
NOTEF=$BASE/note
mkdir -p "$BASE" 2>/dev/null

FALLBACK_SELF=/data/adb/modules/aot_compiler/bin/aot.sh
case "$0" in
    /*) SELF="$0" ;;
    *)  if [ -f "$0" ]; then SELF="$(pwd)/$0"; else SELF="$FALLBACK_SELF"; fi ;;
esac

# Android 14 (SDK 34) 起提供 --full 作用域与 pm art 子命令
SDK=$(getprop ro.build.version.sdk 2>/dev/null)
case "$SDK" in
    ''|*[!0-9]*) SDK=0 ;;
esac
has_full_scope() { [ "$SDK" -ge 34 ] 2>/dev/null; }
has_pm_art()     { [ "$SDK" -ge 34 ] 2>/dev/null; }

# ---------------------------------------------------------------- 基础工具
pkg_list() {
    # $1 为空表示全部；-3 表示第三方
    if out=$(cmd package list packages $1 2>/dev/null) && [ -n "$out" ]; then
        printf '%s\n' "$out"
    else
        pm list packages $1 2>/dev/null
    fi
}

dalvik_dir() {
    for d in /data/dalvik-cache/arm64 /data/dalvik-cache/arm \
             /data/dalvik-cache/x86_64 /data/dalvik-cache/x86 \
             /data/dalvik-cache/riscv64; do
        [ -d "$d" ] && { printf '%s' "$d"; return; }
    done
    for d in /data/dalvik-cache/*; do
        [ -d "$d" ] && { printf '%s' "$d"; return; }
    done
    printf '%s' /data/dalvik-cache
}

# 尽力让工作进程脱离调用方，避免 WebUI 关闭或 adb 断开时被回收
detach() {
    if command -v setsid >/dev/null 2>&1; then
        setsid "$@"
    elif command -v nohup >/dev/null 2>&1; then
        nohup "$@"
    else
        "$@"
    fi
}

is_running() {
    [ -s "$PIDF" ] || return 1
    p=$(cat "$PIDF" 2>/dev/null)
    [ -n "$p" ] || return 1
    kill -0 "$p" 2>/dev/null
}

count_done() {
    scope=$(cat "$SCOPEF" 2>/dev/null)
    if [ "$scope" = "all" ]; then
        [ -f "$LOG" ] || { echo 0; return; }
        grep -c 'Success' "$LOG" 2>/dev/null || echo 0
    else
        [ -s "$COUNT" ] && cat "$COUNT" || echo 0
    fi
}

collect_jobids() {
    [ -f "$LOG" ] || return 0
    sed -n 's/.*pm art cancel \([0-9a-f-]\{36\}\).*/\1/p' "$LOG" 2>/dev/null | sort -u
}

# ---------------------------------------------------------------- 编译
compile_target() {
    f="$1"
    target="$2"
    if has_full_scope; then
        cmd package compile -m "$f" -f --full "$target" >>"$LOG" 2>&1
    else
        cmd package compile -m "$f" -f "$target" >>"$LOG" 2>&1
        cmd package compile -m "$f" -f --secondary-dex "$target" >>"$LOG" 2>&1
    fi
}

# 探测 everything 是否被当前系统接受；不支持则自动降级
probe_filter() {
    f="$1"
    [ "$f" = "everything" ] || return 0
    out=$(cmd package compile -m everything -f com.android.shell 2>&1)
    case "$out" in
        *"Invalid compiler filter"*|*"Unknown compiler filter"*|\
        *"Unsupported compiler filter"*|*"invalid compiler filter"*)
            printf '%s' "$out" >"$NOTEF"
            return 1
            ;;
    esac
    return 0
}

_run() {
    f="$1"
    scope="$2"

    echo $$ >"$PIDF"
    : >"$LOG"
    echo 0 >"$COUNT"
    rm -f "$NOTEF" "$ENDF"
    echo "$f" >"$FILTERF"
    echo "$scope" >"$SCOPEF"
    date +%s >"$STARTF"
    echo running >"$STATE"

    if ! probe_filter "$f"; then
        echo "当前系统不支持 everything 过滤器，已自动降级为 speed" >"$NOTEF"
        f=speed
        echo "$f" >"$FILTERF"
    fi

    case "$scope" in
        all)   total=$(pkg_list | wc -l) ;;
        third) total=$(pkg_list -3 | wc -l) ;;
        *)     total=1 ;;
    esac
    echo "$total" >"$TOTAL"

    {
        echo "=== AOT 编译开始 $(date '+%Y-%m-%d %H:%M:%S') ==="
        echo "模式: $f    范围: $scope    目标数: $total"
        if has_full_scope; then
            echo "作用域: --full (Android $SDK)"
        else
            echo "作用域: 默认 + --secondary-dex (Android $SDK)"
        fi
        echo ""
    } >>"$LOG" 2>&1

    if [ "$scope" = "all" ]; then
        compile_target "$f" "-a"
    elif [ "$scope" = "third" ]; then
        n=0
        for p in $(pkg_list -3 | sed 's/^package://'); do
            compile_target "$f" "$p"
            n=$((n + 1))
            echo "$n" >"$COUNT"
        done
    else
        compile_target "$f" "$scope"
        echo 1 >"$COUNT"
    fi

    date +%s >"$ENDF"
    echo done >"$STATE"
    rm -f "$PIDF"
}

# ---------------------------------------------------------------- 启动
start() {
    f="$1"
    scope="$2"
    [ -n "$scope" ] || scope=all

    case "$f" in
        everything|speed|speed-profile|verify) ;;
        *) f=everything ;;
    esac
    case "$scope" in
        all|third) ;;
        *) scope=$(printf '%s' "$scope" | tr -d ' ' | head -1) ;;
    esac
    [ -n "$scope" ] || scope=all

    if is_running; then
        echo "ERR: 已有任务正在运行 (pid $(cat "$PIDF"))"
        return 1
    fi

    chmod 755 "$SELF" 2>/dev/null
    detach sh "$SELF" _run "$f" "$scope" >/dev/null 2>&1 </dev/null &

    n=0
    while [ ! -s "$PIDF" ] && [ "$n" -lt 50 ]; do
        sleep 0.1
        n=$((n + 1))
    done

    echo "OK: 已启动 模式=$f 范围=$scope"
}

# ---------------------------------------------------------------- 停止
stop() {
    if is_running; then
        p=$(cat "$PIDF")
        kill -TERM -"$p" 2>/dev/null
        kill -TERM "$p" 2>/dev/null
        sleep 1
        kill -9 -"$p" 2>/dev/null
        kill -9 "$p" 2>/dev/null
    fi
    rm -f "$PIDF"

    if has_pm_art; then
        for j in $(collect_jobids); do
            pm art cancel "$j" >/dev/null 2>&1
        done
        pm art cancel "*" >/dev/null 2>&1
        echo "已停止编译，并已请求取消系统侧 dexopt 作业"
    else
        echo "已停止编译"
    fi
    echo stopped >"$STATE"
}

# ---------------------------------------------------------------- 状态
status() {
    st=idle
    [ -f "$STATE" ] && st=$(cat "$STATE" 2>/dev/null)
    if [ "$st" = "running" ] && ! is_running; then
        st=done
        echo done >"$STATE"
    fi

    f=""
    [ -f "$FILTERF" ] && f=$(cat "$FILTERF")
    sc=""
    [ -f "$SCOPEF" ] && sc=$(cat "$SCOPEF")
    t=0
    [ -f "$TOTAL" ] && t=$(cat "$TOTAL")
    s=$(count_done)
    ts=0
    [ -f "$STARTF" ] && ts=$(cat "$STARTF")
    en=0
    [ -f "$ENDF" ] && en=$(cat "$ENDF")
    note=""
    [ -f "$NOTEF" ] && note=$(head -1 "$NOTEF" 2>/dev/null)
    now=$(date +%s)

    eta=0
    if [ "$st" = "running" ] && [ "$s" -gt 0 ] 2>/dev/null && [ "$t" -gt "$s" ] 2>/dev/null; then
        elapsed=$((now - ts))
        eta=$((elapsed * (t - s) / s))
    fi

    echo "state=$st"
    echo "filter=$f"
    echo "scope=$sc"
    echo "total=$t"
    echo "done=$s"
    echo "start=$ts"
    echo "end=$en"
    echo "now=$now"
    echo "eta=$eta"
    echo "jobid=$(collect_jobids | tail -1)"
    echo "note=$note"
}

# ---------------------------------------------------------------- 其它
logtail() {
    n="$1"
    [ -n "$n" ] || n=300
    [ -f "$LOG" ] || { echo "(暂无日志)"; return; }
    tail -n "$n" "$LOG" 2>/dev/null
}

reset_all() {
    echo "正在重置全部应用 dexopt 状态..."
    cmd package compile --reset -a 2>&1 | tail -5
    echo "重置完成"
}

cleanup() {
    if has_pm_art; then
        echo "正在清理无用 odex/vdex..."
        pm art cleanup 2>&1
    else
        echo "当前系统 (SDK $SDK) 不支持 pm art cleanup"
    fi
}

query() {
    [ -n "$1" ] || { echo "用法: query <包名>"; return; }
    if has_pm_art; then
        pm art dump 2>/dev/null | grep -A3 "^\[$1\]"
    else
        dumpsys package "$1" 2>/dev/null | grep -iE "compilerFilter|dexopt|codePath" | head -5
    fi
}

info() {
    if has_full_scope; then
        args="--full"
    else
        args="默认作用域 + --secondary-dex"
    fi
    echo "version=$VERSION"
    echo "device=$(getprop ro.product.model)"
    echo "android=$(getprop ro.build.version.release)"
    echo "sdk=$SDK"
    echo "arch=$(getprop ro.product.cpu.abi)"
    echo "kernel=$(uname -r)"
    echo "build=$(getprop ro.build.version.incremental)"
    echo "pkgs=$(pkg_list | wc -l)"
    echo "third=$(pkg_list -3 | wc -l)"
    echo "dalvik=$(du -sm "$(dalvik_dir)" 2>/dev/null | awk '{print $1}')"
    echo "datasize=$(df -h /data/user/0 2>/dev/null | awk 'NR==2{print $2}')"
    echo "dataused=$(df -h /data/user/0 2>/dev/null | awk 'NR==2{print $3}')"
    echo "datafree=$(df -h /data/user/0 2>/dev/null | awk 'NR==2{print $4}')"
    echo "battery=$(dumpsys battery 2>/dev/null | sed -n 's/^ *level: \([0-9]*\).*/\1/p' | head -1)"
    echo "scope_args=$args"
}

case "$1" in
    start)   shift; start "$@" ;;
    stop)    stop ;;
    status)  status ;;
    log)     shift; logtail "$@" ;;
    reset)   reset_all ;;
    cleanup) cleanup ;;
    query)   shift; query "$@" ;;
    info)    info ;;
    version) echo "$VERSION" ;;
    _run)    shift; _run "$@" ;;
    *)
        echo "AOT 编译器 v$VERSION"
        echo "用法: aot.sh {start|stop|status|log|reset|cleanup|query|info|version}"
        ;;
esac
