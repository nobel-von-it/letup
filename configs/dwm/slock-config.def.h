/* user and group to drop privileges to */
static const char *user = "nobody";
static const char *group = "nobody"; /* В Arch/Artix группа обычно 'nobody', а не 'nogroup' */

static const char *colorname[NUMCOLS] = {
    [INIT] = "#1a1c23",   /* after initialization (Background) */
    [INPUT] = "#7a8ca3",  /* during input (Blue accent) */
    [FAILED] = "#b07b7b", /* wrong password (Red accent) */
};

/* treat a cleared input like a wrong password (color) */
static const int failonclear = 1;
