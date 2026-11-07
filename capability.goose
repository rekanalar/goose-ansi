// The terminal capability check for the ansi package.
//
// The check follows the NO_COLOR convention: the variable NO_COLOR, set to
// any value including the empty one, turns styling off. The terminal name
// dumb turns it off too. Everything else stays on.

namespace ansi;

import std;
import os;

// enabled returns true when the terminal takes styling. It reads the
// environment at every call.
fn enabled() -> bool {
    var value: u8[>..] = [];
    let has_no_color = env("NO_COLOR", value);
    var term: u8[>..] = [];
    env("TERM", term);
    return enabled_with(has_no_color, term);
}

// enabled_with holds the logic, so a test can pass the inputs directly.
fn enabled_with(no_color: bool, term: u8[:]) -> bool {
    if no_color { return false; }
    if term == "dumb" { return false; }
    return true;
}

// is_digits tells whether s is one or more ASCII digits.
fn is_digits(s: u8[:]) -> bool {
    if s.len == 0 { return false; }
    for c in s {
        if c < '0' || c > '9' { return false; }
    }
    return true;
}

// term_level gives the level that the name of the terminal alone gives.
// The rules and their order are those of supports-color in chalk 6.0.1.
// It gives -1 when no rule fits.
fn term_level(term: u8[:], colorterm: u8[:]) -> i64 {
    if colorterm == "truecolor" || colorterm == "24bit" { return 3; }
    if term == "xterm-kitty" || term == "xterm-ghostty" || term == "wezterm" { return 3; }
    var low: u8[>..] = [];
    low.append(term);
    to_lower(low[..]);
    let t = low[..];
    if ends_with(t, "-256") || ends_with(t, "-256color") { return 2; }
    if starts_with(t, "screen") || starts_with(t, "xterm") || starts_with(t, "vt100") { return 1; }
    if starts_with(t, "vt220") || starts_with(t, "rxvt") { return 1; }
    if find(t, "color") >= 0 || find(t, "ansi") >= 0 || find(t, "cygwin") >= 0 || find(t, "linux") >= 0 { return 1; }
    if colorterm.len > 0 { return 1; }
    return -1;
}

// color_level_tty gives the colour level for the environment. is_tty says
// whether the stream is a terminal; the caller knows, the package cannot ask.
// force is FORCE_COLOR. The empty string means not set, for force and for
// colorterm. The order follows chalk 6.0.1, with two differences: NO_COLOR
// gives 0 when FORCE_COLOR does not decide, and COLORTERM=24bit gives 3.
fn color_level_tty(is_tty: bool, no_color: bool, term: u8[:], colorterm: u8[:], force: u8[:]) -> i64 {
    var min = 0;
    var forced = false;
    if force == "false" { return 0; }
    if force == "true" {
        forced = true;
        min = 1;
    } else if is_digits(force) {
        // The value is a level. Stop adding at 4, so a long string is safe.
        var n = 0;
        for c in force {
            if n < 4 { n = n * 10 + (c - '0'); }
        }
        if n > 3 { return 3; }
        return n;
    }
    if !forced {
        if no_color || !is_tty { return 0; }
    }
    if term == "dumb" { return min; }
    let l = term_level(term, colorterm);
    if l >= 0 { return l; }
    return min;
}

// color_level_with holds the logic for a terminal, so a test can pass the
// inputs directly.
fn color_level_with(no_color: bool, term: u8[:], colorterm: u8[:], force: u8[:]) -> i64 {
    return color_level_tty(true, no_color, term, colorterm, force);
}

// color_level_stream reads the environment and gives the level for a stream.
// chalk gives supportsColor for the stdout stream and supportsColorStderr for
// the stderr stream. The two differ only by the terminal flag.
fn color_level_stream(is_tty: bool) -> i64 {
    var no_color: u8[>..] = [];
    let has_no_color = env("NO_COLOR", no_color);
    var term: u8[>..] = [];
    env("TERM", term);
    var colorterm: u8[>..] = [];
    env("COLORTERM", colorterm);
    var force: u8[>..] = [];
    env("FORCE_COLOR", force);
    return color_level_tty(is_tty, has_no_color, term[..], colorterm[..], force[..]);
}

// color_level returns the colour level for a terminal: 0 none, 1 sixteen
// colours, 2 the 256 palette, 3 truecolor.
fn color_level() -> i64 {
    return color_level_stream(true);
}
