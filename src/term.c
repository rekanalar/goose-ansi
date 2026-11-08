// The C layer of the ansi package.
//
// It answers two questions: is a file descriptor a terminal, and how many
// columns and rows does that terminal have. The Goose standard library has
// no call for either question.
//
// The file has no POSIX header on Windows. The size comes from the console
// buffer of Windows and from the ioctl call of the other systems.

#include "goose.h"

#include <stdint.h>
#include <stdio.h>

#ifdef _WIN32
#include <io.h>
#include <stdlib.h>
#include <windows.h>
#else
#include <sys/ioctl.h>
#include <unistd.h>
#endif

#ifdef _WIN32
// A bad descriptor makes the C runtime of Windows end the process. This
// handler turns that into an error return.
static void term_ignore(const wchar_t *a, const wchar_t *b, const wchar_t *c, unsigned d, uintptr_t e) {
    (void)a; (void)b; (void)c; (void)d; (void)e;
}

static void term_guard(void) {
    static int done = 0;
    if (done) return;
    done = 1;
    _set_invalid_parameter_handler(term_ignore);
}
#endif

// term_is_tty gives 1 when the file descriptor is a terminal. It gives 0
// for a pipe, for a file and for a bad descriptor.
int64_t term_is_tty(int64_t fd) {
#ifdef _WIN32
    term_guard();
    if (fd < 0 || fd > 1024) return 0;
    return _isatty((int)fd) ? 1 : 0;
#else
    return isatty((int)fd) ? 1 : 0;
#endif
}

// term_size writes the columns and the rows into the builder as text. The
// text holds the two numbers and a space. It gives the number of bytes
// written, or 0 when the size is not known.
int64_t term_size(int64_t fd, gs_rref out) {
    char text[32];
    int cols = 0;
    int rows = 0;
#ifdef _WIN32
    term_guard();
    if (fd < 0 || fd > 1024) return 0;
    HANDLE handle = (HANDLE)_get_osfhandle((int)fd);
    if (handle == (HANDLE)-1 || handle == INVALID_HANDLE_VALUE) return 0;
    CONSOLE_SCREEN_BUFFER_INFO info;
    if (!GetConsoleScreenBufferInfo(handle, &info)) return 0;
    cols = info.srWindow.Right - info.srWindow.Left + 1;
    rows = info.srWindow.Bottom - info.srWindow.Top + 1;
#else
    struct winsize ws;
    if (ioctl((int)fd, TIOCGWINSZ, &ws) != 0) return 0;
    cols = ws.ws_col;
    rows = ws.ws_row;
#endif
    if (cols <= 0 || rows <= 0) return 0;
    int n = snprintf(text, sizeof(text), "%d %d", cols, rows);
    if (n <= 0) return 0;
    gs_bld_append(out, text, n);
    return (int64_t)n;
}
