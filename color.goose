// Colour levels and the fall back to a lower level.
//
// The levels follow chalk: 0 none, 1 sixteen colours, 2 the 256 palette,
// 3 truecolor. A writer with a level lowers a palette number or an RGB
// value to what the level takes. Level 0 writes the plain text.
//
// The rules for the fall back are the ones of color-convert, the library
// that ansi-styles and chalk use.

namespace ansi;

import std;

// round_div returns a / b rounded to the nearest integer, for a >= 0.
fn round_div(a: i64, b: i64) -> i64 {
    return (a * 2 + b) / (b * 2);
}

// rgb_to_256 returns the palette number nearest to the colour.
fn rgb_to_256(r: i64, g: i64, b: i64) -> i64 {
    let rc = clamp255(r);
    let gc = clamp255(g);
    let bc = clamp255(b);
    if rc == gc && gc == bc {
        if rc < 8 { return 16; }
        if rc > 248 { return 231; }
        return round_div((rc - 8) * 24, 247) + 232;
    }
    return 16 + 36 * round_div(rc * 5, 255) + 6 * round_div(gc * 5, 255) + round_div(bc * 5, 255);
}

// to_16 returns the SGR foreground code nearest to the palette entry n.
// The rule is ansi256ToAnsi of ansi-styles, with its exact test for the bright code.
fn to_16(n: i64) -> i64 {
    let c = clamp255(n);
    if c < 8 { return 30 + c; }
    if c < 16 { return 90 + c - 8; }
    var rc = 0;
    var gc = 0;
    var bc = 0;
    if c >= 232 {
        let v = (c - 232) * 10 + 8;
        rc = v;
        gc = v;
        bc = v;
    } else {
        let k = c - 16;
        rc = k / 36 * 51;
        gc = (k % 36) / 6 * 51;
        bc = (k % 6) * 51;
    }
    var top = rc;
    if gc > top { top = gc; }
    if bc > top { top = bc; }
    if top == 0 { return 30; }
    let code = 30 + ((round_div(bc, 255) << 2) | (round_div(gc, 255) << 1) | round_div(rc, 255));
    // ansi-styles tests value === 2 with no rounding. Only a full component
    // gives the bright code. A light gray from the gray ramp does not.
    if top == 255 { return code + 60; }
    return code;
}

// rgb_to_16 returns the SGR foreground code nearest to the colour. It goes
// through the palette, as chalk does.
fn rgb_to_16(r: i64, g: i64, b: i64) -> i64 {
    return to_16(rgb_to_256(r, g, b));
}

// styled_at writes the codes at the level, or the plain text at level 0.
fn styled_at(out: u8[>..]&, text: u8[:], codes: i64[:], level: i64) {
    if level <= 0 { out.append(text); return; }
    style(out, text, codes);
}

// color256_at writes the text in the palette colour n, lowered to the
// level.
fn color256_at(out: u8[>..]&, text: u8[:], n: i64, level: i64) {
    let c = clamp255(n);
    if level >= 2 { styled_at(out, text, [38, 5, c], level); return; }
    styled_at(out, text, [to_16(c)], level);
}

// bg_color256_at writes the text on the palette colour n, lowered to the
// level.
fn bg_color256_at(out: u8[>..]&, text: u8[:], n: i64, level: i64) {
    let c = clamp255(n);
    if level >= 2 { styled_at(out, text, [48, 5, c], level); return; }
    styled_at(out, text, [to_16(c) + 10], level);
}

// truecolor_at writes the text in the colour, lowered to the level.
fn truecolor_at(out: u8[>..]&, text: u8[:], r: i64, g: i64, b: i64, level: i64) {
    if level >= 3 { styled_at(out, text, [38, 2, clamp255(r), clamp255(g), clamp255(b)], level); return; }
    if level == 2 { styled_at(out, text, [38, 5, rgb_to_256(r, g, b)], level); return; }
    styled_at(out, text, [rgb_to_16(r, g, b)], level);
}

// bg_truecolor_at writes the text on the colour, lowered to the level.
fn bg_truecolor_at(out: u8[>..]&, text: u8[:], r: i64, g: i64, b: i64, level: i64) {
    if level >= 3 { styled_at(out, text, [48, 2, clamp255(r), clamp255(g), clamp255(b)], level); return; }
    if level == 2 { styled_at(out, text, [48, 5, rgb_to_256(r, g, b)], level); return; }
    styled_at(out, text, [rgb_to_16(r, g, b) + 10], level);
}

// idx16 turns an SGR foreground code of the 16 colour set into the colour
// index 0 to 15 that the codes 58;5 and 38;5 take.
fn idx16(code: i64) -> i64 {
    if code < 90 { return code - 30; }
    return code - 82;
}

// underline_rgb writes the text with an underline in the colour. It does
// not lower the colour. chalk 6 calls it underlineRgb.
fn underline_rgb(out: u8[>..]&, text: u8[:], r: i64, g: i64, b: i64) {
    style(out, text, [58, 2, clamp255(r), clamp255(g), clamp255(b)]);
}

// underline_color256 writes the text with an underline in the palette
// colour n. chalk 6 calls it underlineAnsi256.
fn underline_color256(out: u8[>..]&, text: u8[:], n: i64) {
    style(out, text, [58, 5, clamp255(n)]);
}

// underline_rgb_at writes the underline colour, lowered to the level.
fn underline_rgb_at(out: u8[>..]&, text: u8[:], r: i64, g: i64, b: i64, level: i64) {
    if level >= 3 { styled_at(out, text, [58, 2, clamp255(r), clamp255(g), clamp255(b)], level); return; }
    if level == 2 { styled_at(out, text, [58, 5, rgb_to_256(r, g, b)], level); return; }
    styled_at(out, text, [58, 5, idx16(rgb_to_16(r, g, b))], level);
}

// underline_color256_at writes the underline palette colour n, lowered to
// the level.
fn underline_color256_at(out: u8[>..]&, text: u8[:], n: i64, level: i64) {
    let c = clamp255(n);
    if level >= 2 { styled_at(out, text, [58, 5, c], level); return; }
    styled_at(out, text, [58, 5, idx16(to_16(c))], level);
}

// hex_digit gives the value of one hex digit, or -1.
fn hex_digit(c: u8) -> i64 {
    if c >= '0' && c <= '9' { return c - '0'; }
    if c >= 'a' && c <= 'f' { return c - 'a' + 10; }
    if c >= 'A' && c <= 'F' { return c - 'A' + 10; }
    return -1;
}

// parse_hex reads a colour from three or six hex digits, after at most one
// "#". It gives the parts and true, or zeros and false for any other text.
// chalk reads other text as black, or as the first match. This package
// refuses it.
fn parse_hex(s: u8[:]) -> i64, i64, i64, bool {
    var start = 0;
    if s.len > 0 && s[0] == '#' { start = 1; }
    let n = s.len - start;
    if n != 3 && n != 6 { return 0, 0, 0, false; }
    var v: i64[6] = [0, 0, 0, 0, 0, 0];
    for i in 0..n {
        let d = hex_digit(s[start + i]);
        if d < 0 { return 0, 0, 0, false; }
        v[i] = d;
    }
    if n == 3 { return v[0] * 17, v[1] * 17, v[2] * 17, true; }
    return v[0] * 16 + v[1], v[2] * 16 + v[3], v[4] * 16 + v[5], true;
}

// hex_at writes the text in the colour of the hex string, lowered to the
// level. It gives false and writes nothing for a bad string.
fn hex_at(out: u8[>..]&, text: u8[:], s: u8[:], level: i64) -> bool {
    let r, g, b, ok = parse_hex(s);
    if !ok { return false; }
    truecolor_at(out, text, r, g, b, level);
    return true;
}

// bg_hex_at writes the text on the colour of the hex string.
fn bg_hex_at(out: u8[>..]&, text: u8[:], s: u8[:], level: i64) -> bool {
    let r, g, b, ok = parse_hex(s);
    if !ok { return false; }
    bg_truecolor_at(out, text, r, g, b, level);
    return true;
}

// underline_hex_at writes the text with an underline in the colour of the
// hex string.
fn underline_hex_at(out: u8[>..]&, text: u8[:], s: u8[:], level: i64) -> bool {
    let r, g, b, ok = parse_hex(s);
    if !ok { return false; }
    underline_rgb_at(out, text, r, g, b, level);
    return true;
}

// hex, bg_hex and underline_hex write the truecolor form. They do not lower.
fn hex(out: u8[>..]&, text: u8[:], s: u8[:]) -> bool { return hex_at(out, text, s, 3); }
fn bg_hex(out: u8[>..]&, text: u8[:], s: u8[:]) -> bool { return bg_hex_at(out, text, s, 3); }
fn underline_hex(out: u8[>..]&, text: u8[:], s: u8[:]) -> bool { return underline_hex_at(out, text, s, 3); }

// The bright set of the 16 colours.
fn bright_black(out: u8[>..]&, text: u8[:])   { style(out, text, [90]); }
fn bright_red(out: u8[>..]&, text: u8[:])     { style(out, text, [91]); }
fn bright_green(out: u8[>..]&, text: u8[:])   { style(out, text, [92]); }
fn bright_yellow(out: u8[>..]&, text: u8[:])  { style(out, text, [93]); }
fn bright_blue(out: u8[>..]&, text: u8[:])    { style(out, text, [94]); }
fn bright_magenta(out: u8[>..]&, text: u8[:]) { style(out, text, [95]); }
fn bright_cyan(out: u8[>..]&, text: u8[:])    { style(out, text, [96]); }
fn bright_white(out: u8[>..]&, text: u8[:])   { style(out, text, [97]); }

fn bg_bright_black(out: u8[>..]&, text: u8[:])   { style(out, text, [100]); }
fn bg_bright_red(out: u8[>..]&, text: u8[:])     { style(out, text, [101]); }
fn bg_bright_green(out: u8[>..]&, text: u8[:])   { style(out, text, [102]); }
fn bg_bright_yellow(out: u8[>..]&, text: u8[:])  { style(out, text, [103]); }
fn bg_bright_blue(out: u8[>..]&, text: u8[:])    { style(out, text, [104]); }
fn bg_bright_magenta(out: u8[>..]&, text: u8[:]) { style(out, text, [105]); }
fn bg_bright_cyan(out: u8[>..]&, text: u8[:])    { style(out, text, [106]); }
fn bg_bright_white(out: u8[>..]&, text: u8[:])   { style(out, text, [107]); }
