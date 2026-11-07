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

fn bold(out: u8[>..]&, text: u8[:])      { style(out, text, [1]); }
fn dim(out: u8[>..]&, text: u8[:])       { style(out, text, [2]); }
fn italic(out: u8[>..]&, text: u8[:])    { style(out, text, [3]); }
fn underline(out: u8[>..]&, text: u8[:]) { style(out, text, [4]); }
fn reverse(out: u8[>..]&, text: u8[:])   { style(out, text, [7]); }
fn strike(out: u8[>..]&, text: u8[:])    { style(out, text, [9]); }

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
