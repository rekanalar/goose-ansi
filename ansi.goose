// ansi - terminal styling for Goose.
//
// The writers append SGR sequences to a builder the caller owns. The
// measuring functions scan styled text. The capability function reads the
// environment.
//
// Every file in this package declares "namespace ansi;". A user calls
// ansi::red. A user calls ansi::truncate.
namespace ansi;

import std;
import measure;
import capability;
import escape;
import color;
import link;
import wrap;
import style;
import os;

// The C layer in src/term.c. Each call takes at most two slots.
extern fn term_is_tty(fd: i64) -> i64;
extern fn term_size(fd: i64, out: u8[>..]&) -> i64;

// is_tty tells whether the file descriptor is a terminal. The descriptor 0
// is stdin, 1 is stdout and 2 is stderr.
fn is_tty(fd: i64) -> bool { return term_is_tty(fd) == 1; }
fn is_tty_stdout() -> bool { return is_tty(1); }
fn is_tty_stderr() -> bool { return is_tty(2); }

// env_number reads an environment variable that holds digits only. It gives
// 0 for a variable that is not set, empty, or not a number.
fn env_number(name: u8[:]) -> i64 {
    var v: u8[>..] = [];
    if !env(name, v) || !is_digits(v[..]) || v.len > 6 { return 0; }
    let n, ok = parse_int(v[..]);
    if !ok { return 0; }
    return n;
}

// terminal_size_with writes "columns rows" for the terminal of fd into out
// and gives the number of bytes. COLUMNS and LINES override the terminal,
// as in rich. A size that is not known gives 80 and 25.
fn terminal_size_with(fd: i64, out: u8[>..]&) -> i64 {
    var cols = 0;
    var rows = 0;
    var raw: u8[>..] = [];
    if term_size(fd, raw) > 0 {
        var sp = 0;
        while sp < raw.len && raw[sp] != ' ' { sp += 1; }
        let c, ok1 = parse_int(raw[..sp]);
        let r, ok2 = parse_int(raw[sp + 1..]);
        if ok1 && ok2 { cols = c; rows = r; }
    }
    let ec = env_number("COLUMNS");
    let el = env_number("LINES");
    if ec > 0 { cols = ec; }
    if el > 0 { rows = el; }
    if cols <= 0 { cols = 80; }
    if rows <= 0 { rows = 25; }
    let start = out.len;
    format(out, cols, " ", rows);
    return out.len - start;
}

// terminal_size writes "columns rows" for stdout. The size of stdout is
// tried first, then stderr, then stdin.
fn terminal_size(out: u8[>..]&) -> i64 {
    var fd = 1;
    if !is_tty(1) && is_tty(2) { fd = 2; }
    if !is_tty(1) && !is_tty(2) && is_tty(0) { fd = 0; }
    return terminal_size_with(fd, out);
}

// style writes the text with the SGR parameters in codes. One select
// carries the parameters, so style(out, "x", [1, 31]) is bold red.
fn style(out: u8[>..]&, text: u8[:], codes: i64[:]) {
    out.append("\x1b[");
    for c, i in codes {
        if i > 0 { out.push(';'); }
        format(out, c);
    }
    out.push('m');
    out.append(text);
    out.append("\x1b[0m");
}

// styled writes the text in the style of a style string such as
// "bold red on blue" or "rgb(255,136,0)". It gives false and writes nothing
// for a bad string. A link word makes the text a hyperlink.
fn styled(out: u8[>..]&, text: u8[:], spec: u8[:]) -> bool {
    var codes: i64[>..] = [];
    if style::style_parse(codes, spec) != 0 { return false; }
    var url: u8[>..] = [];
    if style::style_link(url, spec) == 1 {
        out.append("\x1b]8;;");
        osc8_url(out, url);
        out.push(0x07);
    }
    if codes.len > 0 { style(out, text, codes[..]); } else { out.append(text); }
    if url.len > 0 { out.append("\x1b]8;;\x07"); }
    return true;
}

fn bold(out: u8[>..]&, text: u8[:])      { style(out, text, [1]); }
fn dim(out: u8[>..]&, text: u8[:])       { style(out, text, [2]); }
fn italic(out: u8[>..]&, text: u8[:])    { style(out, text, [3]); }
fn underline(out: u8[>..]&, text: u8[:]) { style(out, text, [4]); }
fn reverse(out: u8[>..]&, text: u8[:])   { style(out, text, [7]); }
fn strike(out: u8[>..]&, text: u8[:])    { style(out, text, [9]); }
fn overline(out: u8[>..]&, text: u8[:])  { style(out, text, [53]); }
fn blink(out: u8[>..]&, text: u8[:])      { style(out, text, [5]); }
fn blink2(out: u8[>..]&, text: u8[:])     { style(out, text, [6]); }
fn underline2(out: u8[>..]&, text: u8[:]) { style(out, text, [21]); }
fn frame(out: u8[>..]&, text: u8[:])      { style(out, text, [51]); }
fn encircle(out: u8[>..]&, text: u8[:])   { style(out, text, [52]); }
fn hidden(out: u8[>..]&, text: u8[:])    { style(out, text, [8]); }

fn black(out: u8[>..]&, text: u8[:])   { style(out, text, [30]); }
fn red(out: u8[>..]&, text: u8[:])     { style(out, text, [31]); }
fn green(out: u8[>..]&, text: u8[:])   { style(out, text, [32]); }
fn yellow(out: u8[>..]&, text: u8[:])  { style(out, text, [33]); }
fn blue(out: u8[>..]&, text: u8[:])    { style(out, text, [34]); }
fn magenta(out: u8[>..]&, text: u8[:]) { style(out, text, [35]); }
fn cyan(out: u8[>..]&, text: u8[:])    { style(out, text, [36]); }
fn white(out: u8[>..]&, text: u8[:])   { style(out, text, [37]); }
fn gray(out: u8[>..]&, text: u8[:])    { style(out, text, [90]); }

fn bg_black(out: u8[>..]&, text: u8[:])   { style(out, text, [40]); }
fn bg_red(out: u8[>..]&, text: u8[:])     { style(out, text, [41]); }
fn bg_green(out: u8[>..]&, text: u8[:])   { style(out, text, [42]); }
fn bg_yellow(out: u8[>..]&, text: u8[:])  { style(out, text, [43]); }
fn bg_blue(out: u8[>..]&, text: u8[:])    { style(out, text, [44]); }
fn bg_magenta(out: u8[>..]&, text: u8[:]) { style(out, text, [45]); }
fn bg_cyan(out: u8[>..]&, text: u8[:])    { style(out, text, [46]); }
fn bg_white(out: u8[>..]&, text: u8[:])   { style(out, text, [47]); }

// The color numbers clamp into 0..255. A wrong number stays safe.
fn clamp255(n: i64) -> i64 {
    if n < 0 { return 0; }
    if n > 255 { return 255; }
    return n;
}

fn color256(out: u8[>..]&, text: u8[:], n: i64) {
    style(out, text, [38, 5, clamp255(n)]);
}

fn bg_color256(out: u8[>..]&, text: u8[:], n: i64) {
    style(out, text, [48, 5, clamp255(n)]);
}

fn truecolor(out: u8[>..]&, text: u8[:], r: i64, g: i64, b: i64) {
    style(out, text, [38, 2, clamp255(r), clamp255(g), clamp255(b)]);
}

fn bg_truecolor(out: u8[>..]&, text: u8[:], r: i64, g: i64, b: i64) {
    style(out, text, [48, 2, clamp255(r), clamp255(g), clamp255(b)]);
}
