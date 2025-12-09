/* See LICENSE file for copyright and license details. */

/* interval between updates (in ms) */
const unsigned int interval = 1000;

/* text to show if no value can be retrieved */
static const char unknown_str[] = "n/a";

/* maximum output string length */
#define MAXLEN 2048

static const struct arg args[] = {
    /* function        format           argument */

    /* Layout клавиатуры */
    {keymap, " [%s] ", NULL},

    /* CPU: Usage | Temp */
    {cpu_perc, "| CPU:%s%% ", NULL},
    {temp, "(%s°C) ", "/sys/class/thermal/thermal_zone0/temp"},

    /* RAM & Disk */
    {ram_perc, "| MEM:%s%% ", NULL},
    {disk_free, "| HDD:%s ", "/"},

    /* WiFi: Down | Up | Temp (Zone generic) */
    /* ЗАМЕНИ 'wlan0' НА СВОЙ ИНТЕРФЕЙС (ip a) */
    {netspeed_rx, "| ▼%s ", "wlan0"},
    {netspeed_tx, "▲%s ", "wlan0"},
    /* Обычно temp wifi сложно найти, используем заглушку или ищем путь в /sys/class/hwmon/ */
    /* { temp,         "(%s°C) ",       "/sys/class/thermal/thermal_zone1/temp" }, */

    /* Battery: % | State (3 chars) | Watts */
    /* ЗАМЕНИ 'BAT0' НА СВОЁ (ls /sys/class/power_supply) */
    {battery_perc, "| BAT:%s%%", "BAT0"},
    {battery_state, "(%.3s) ", "BAT0"}, /* %.3s обрезает строку до 3 символов */
    /* Читаем ватты через команду shell, т.к. нативно функции нет. Делим uW на 10^6 */
    {run_command, "%sW ",
     "awk '{print $1*10^-6}' /sys/class/power_supply/BAT0/power_now 2>/dev/null"},

    /* Time */
    {datetime, "| %s ", "%Y-%m-%d %H:%M"},
};
