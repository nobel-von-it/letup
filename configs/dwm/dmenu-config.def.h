/* See LICENSE file for copyright and license details. */
/* Default settings; can be overriden by command line. */

static int topbar = 1; /* -b  option; if 0, dmenu appears at bottom     */
/* -fn option overrides fonts[0]; default X11 font or font set */
static const char *fonts[] = {
    "JetBrainsMonoNerdFont:size=10" /* Используем тот же шрифт, что в st/dwm */
};
static const char *prompt = NULL; /* -p  option; prompt to the left of input field */

// guis
/* Цвета из палитры Melancholy */
static const char *colors[SchemeLast][2] = {
    /*     fg         bg       */
    [SchemeNorm] = {"#aab1be", "#1a1c23"}, /* Grey text on Dark BG */
    [SchemeSel] = {"#1a1c23", "#7a8ca3"},  /* Dark text on Blue Accent */
    [SchemeOut] = {"#1a1c23", "#889ca6"},  /* Dark text on Cyan (Matches) */
};
/* -l option; if nonzero, dmenu uses vertical list with given number of lines */
static unsigned int lines = 0;

/*
 * Characters not considered part of a word while deleting words
 * for example: " /?\"&[]"
 */
static const char worddelimiters[] = " ";
