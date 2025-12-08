#!/usr/bin/env bash

#!/usr/bin/env bash

SLEEP=5

# ------------- CPU USAGE -------------
read_cpu() {
    read -r cpu user nice system idle iowait irq softirq steal guest guest_nice < /proc/stat
    total=$((user + nice + system + idle + iowait + irq + softirq + steal + guest + guest_nice))
    echo "$total $idle"
}

# ------------- CPU TEMP (без sensors) -------------
get_temp_cpu() {
    # ищем сначала x86_pkg_temp, затем TCPU, затем TCPU_PCI
    for name in x86_pkg_temp TCPU TCPU_PCI; do
        for tz in /sys/class/thermal/thermal_zone*; do
            ttype=$(cat "$tz/type")
            if [ "$ttype" = "$name" ]; then
                val=$(cat "$tz/temp")
                if [ "$val" -gt 1000 ]; then
                    awk "BEGIN{printf(\"%.1f\", $val/1000)}"
                else
                    echo "$val"
                fi
                return
            fi
        done
    done
    echo "N/A"
}

# ------------- WiFi/BT TEMP (просто N/A) -------------
get_temp_wireless() {
    # ищем thermal_zone с типом iwlwifi
    for tz in /sys/class/thermal/thermal_zone*; do
        type=$(cat "$tz/type")
        if echo "$type" | grep -iq "iwlwifi"; then
            val=$(cat "$tz/temp")
            # если значение в milliC
            if [ "$val" -gt 1000 ]; then
                awk "BEGIN{printf(\"%.1f\", $val/1000)}"
            else
                echo "$val"
            fi
            return
        fi
    done
    echo "N/A"
}

# ------------- RAM -------------
mem_percent() {
    awk '
        /^MemTotal:/ {t=$2}
        /^MemAvailable:/ {a=$2}
        END {
            if(t>0) printf("%.0f", (t-a)/t*100);
        }' /proc/meminfo
}

# ------------- DISK -------------
disk_usage() {
    df -BG --output=used,size / | tail -n1 | awk '{printf "%s/%s", $1, $2}'
}

# ------------- BATTERY -------------
battery_info() {
    # ищем батарею
    bat=$(ls -d /sys/class/power_supply/BAT* 2>/dev/null | head -n1)
    if [ -z "$bat" ]; then
        echo "N/A"
        return
    fi

    # ёмкость %
    cap=$(cat "$bat/capacity" 2>/dev/null || echo "N/A")

    # статус (Charging/Discharging/Full) → первые 3 буквы
    stat=$(cat "$bat/status" 2>/dev/null || echo "N/A")
    stat=${stat:0:3}

    # ориентировочная мощность (Вт)
    if [ -r "$bat/power_now" ]; then
        power=$(cat "$bat/power_now")
        # перевод из микроватт в ватт
        power_w=$(awk "BEGIN{printf(\"%.2f\", $power/1000000)}")
    elif [ -r "$bat/current_now" ] && [ -r "$bat/voltage_now" ]; then
        current=$(cat "$bat/current_now")
        voltage=$(cat "$bat/voltage_now")
        # из микроампер и микровольт → Вт
        power_w=$(awk "BEGIN{printf(\"%.2f\", ($current/1000000)*($voltage/1000000))}")
    else
        power_w="N/A"
    fi

    echo "${cap}% ${stat} ${power_w}W"
}

# ------------- NETWORK SPEED -------------
format_speed() {
    b=$1
    if [ "$b" -ge 1048576 ]; then
        awk "BEGIN{printf(\"%.1fMB/s\", $b/1048576)}"
    elif [ "$b" -ge 1024 ]; then
        awk "BEGIN{printf(\"%.1fKB/s\", $b/1024)}"
    else
        echo "${b}B/s"
    fi
}

# detect_iface() {
#     ip -o link show up | awk -F': ' '{print $2}' | grep -v lo | head -n1
# }

IFACE="wlan0"
[ -z "$IFACE" ] && IFACE="lo"

rx_prev=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
tx_prev=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)

# ------------- CPU INIT -------------
read_cpu_vals=($(read_cpu))
cpu_total_prev=${read_cpu_vals[0]}
cpu_idle_prev=${read_cpu_vals[1]}

# # ------------- JSON HEADER -------------
# echo '{"version":1}'
# echo '['
# echo '[],'

# ------------- MAIN LOOP -------------
while true; do
    sleep $SLEEP

    # CPU %
    read_cpu_vals=($(read_cpu))
    cpu_total=${read_cpu_vals[0]}
    cpu_idle=${read_cpu_vals[1]}
    dt=$((cpu_total - cpu_total_prev))
    di=$((cpu_idle - cpu_idle_prev))
    cpu_total_prev=$cpu_total
    cpu_idle_prev=$cpu_idle
    cpu_pct=$(awk "BEGIN{printf(\"%.0f\", ($dt-$di)/$dt*100)}")

    # TEMPS
    cpu_temp=$(get_temp_cpu)
    wifi_temp=$(get_temp_wireless)

    # RAM
    ram=$(mem_percent)

    # DISK
    disk=$(disk_usage)

    # NET
    rx_now=$(cat /sys/class/net/$IFACE/statistics/rx_bytes)
    tx_now=$(cat /sys/class/net/$IFACE/statistics/tx_bytes)
    rx_diff=$(( (rx_now - rx_prev) / SLEEP ))
    tx_diff=$(( (tx_now - tx_prev) / SLEEP ))
    rx_prev=$rx_now
    tx_prev=$tx_now
    rx_h=$(format_speed "$rx_diff")
    tx_h=$(format_speed "$tx_diff")

    # BATTERY
    bat=$(battery_info)

    # TIME
    now=$(date "+%F %R")

    # FULL TEXT
    full="CPU ${cpu_pct}% ${cpu_temp}°C | RAM ${ram}% | Disk ${disk} | ${rx_h} / ${tx_h} WiFi/BT ${wifi_temp}°C | Bat ${bat} | ${now}"

    # ESCAPE JSON
    esc=$(printf '%s' "$full" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g')

    printf '%s\n' "$esc"
done

