// The style string parser of the ansi package.
//
// The words of a style string name the attributes and the colours of one
// style. The grammar follows Style.parse of rich: the words are lowercase
// and they sit between spaces. "bold red on blue" gives the codes
// [1, 31, 41]. The word "on" turns the next colour into a background. The
// word "not" keeps an attribute off. The word "none" gives no code. The
// word "link" names the url of a hyperlink; style_link reads it.
//
// A colour word is a name, "#rrggbb", "rgb(r,g,b)" or "color(n)". The
// names are the sixteen base colours and their bright forms.
//
// The xterm-256 colour names of rich are a stated limit. Only rich has
// them, so the package takes the sixteen names here.

namespace style;

import std;

// The attribute words and their SGR codes. The short names come after the
// long names of the same attribute.
let ATTR_WORD: const u8[:][] = [
    "bold", "b", "dim", "d", "italic", "i", "underline", "u",
    "blink", "blink2", "reverse", "r", "conceal", "c", "hidden",
    "strike", "s", "underline2", "uu", "frame", "encircle", "overline", "o",
];
let ATTR_CODE: i64[] = [
    1, 1, 2, 2, 3, 3, 4, 4,
    5, 6, 7, 7, 8, 8, 8,
    9, 9, 21, 21, 51, 52, 53, 53,
];

// The colour words and their foreground codes. The background code of a
// colour is the foreground code plus 10, except the bright forms, where it
// is the foreground code plus 10 too. gray and grey name the same colour.
let COLOR_WORD: const u8[:][] = [
    "black", "red", "green", "yellow", "blue", "magenta", "cyan", "white",
    "bright_black", "bright_red", "bright_green", "bright_yellow",
    "bright_blue", "bright_magenta", "bright_cyan", "bright_white",
    "gray", "grey",
];
let COLOR_CODE: i64[] = [
    30, 31, 32, 33, 34, 35, 36, 37,
    90, 91, 92, 93, 94, 95, 96, 97,
    90, 90,
];

// attr_code gives the SGR code of an attribute word, or -1.
fn attr_code(word: u8[:]) -> i64 {
    for i in 0..ATTR_WORD.len {
        if word == ATTR_WORD[i] { return ATTR_CODE[i]; }
    }
    return -1;
}

// color_code gives the foreground code of a colour name, or -1.
fn color_code(word: u8[:]) -> i64 {
    for i in 0..COLOR_WORD.len {
        if word == COLOR_WORD[i] { return COLOR_CODE[i]; }
    }
    return -1;
}

// hex_nibble gives the value of one hex digit, or -1.
fn hex_nibble(c: u8) -> i64 {
    if c >= '0' && c <= '9' { return c - '0'; }
    if c >= 'a' && c <= 'f' { return c - 'a' + 10; }
    if c >= 'A' && c <= 'F' { return c - 'A' + 10; }
    return -1;
}

// push_rgb writes the truecolour codes. bg gives the background form.
fn push_rgb(out_codes: i64[>..]&, r: i64, g: i64, b: i64, bg: bool) {
    if bg {
        out_codes.push(48); out_codes.push(2);
    } else {
        out_codes.push(38); out_codes.push(2);
    }
    out_codes.push(r); out_codes.push(g); out_codes.push(b);
}

// parse_color_word writes the codes of one colour word. It returns false
// for a word that is no colour. The colour forms are a name, "#rrggbb",
// "rgb(r,g,b)" and "color(n)".
fn parse_color_word(out_codes: i64[>..]&, word: u8[:], bg: bool) -> bool {
    if word == "default" {
        if bg { out_codes.push(49); } else { out_codes.push(39); }
        return true;
    }
    if word.len >= 1 && word[0] == '#' {
        if word.len != 7 { return false; }
        var rgb: i64[3] = [0, 0, 0];
        for k in 0..3 {
            let hi = hex_nibble(word[1 + k * 2]);
            let lo = hex_nibble(word[2 + k * 2]);
            if hi < 0 || lo < 0 { return false; }
            rgb[k] = hi * 16 + lo;
        }
        push_rgb(out_codes, rgb[0], rgb[1], rgb[2], bg);
        return true;
    }
    if word.len > 4 && word[0] == 'r' && word[1] == 'g' && word[2] == 'b' && word[3] == '(' {
        if word[word.len - 1] != ')' { return false; }
        var rgb: i64[3] = [0, 0, 0];
        var got = 0;
        var i = 4;
        while i < word.len - 1 && got < 3 {
            var j = i;
            while j < word.len - 1 && word[j] != ',' { j += 1; }
            let v, ok = parse_int(word[i..j]);
            if !ok || v < 0 || v > 255 { return false; }
            rgb[got] = v;
            got += 1;
            i = j + 1;
        }
        if got != 3 { return false; }
        push_rgb(out_codes, rgb[0], rgb[1], rgb[2], bg);
        return true;
    }
    if word.len > 6 && word[0] == 'c' && word[1] == 'o' && word[2] == 'l' && word[3] == 'o' && word[4] == 'r' && word[5] == '(' {
        if word[word.len - 1] != ')' { return false; }
        let v, ok = parse_int(word[6..word.len - 1]);
        if !ok || v < 0 || v > 255 { return false; }
        if bg {
            if v < 8 { out_codes.push(40 + v); }
            else if v < 16 { out_codes.push(92 + v); }
            else { out_codes.push(48); out_codes.push(5); out_codes.push(v); }
        } else {
            if v < 8 { out_codes.push(30 + v); }
            else if v < 16 { out_codes.push(82 + v); }
            else { out_codes.push(38); out_codes.push(5); out_codes.push(v); }
        }
        return true;
    }
    let code = color_code(word);
    if code >= 0 {
        if bg { out_codes.push(code + 10); } else { out_codes.push(code); }
        return true;
    }
    return false;
}

// ATTR_ORDER lists the attribute codes in the order that rich writes them.
let ATTR_ORDER: i64[13] = [1, 2, 3, 4, 5, 6, 7, 8, 9, 21, 51, 52, 53];

// next_word gives the next word of spec from i, in lower case, and moves i
// past it. buf holds the lower case copy. An empty word means the end.
fn next_word(buf: u8[>..]&, spec: u8[:], i: i64&) -> u8[:] {
    while i < spec.len && spec[i] == ' ' { i += 1; }
    let start = i;
    while i < spec.len && spec[i] != ' ' { i += 1; }
    buf.clear();
    buf.append(spec[start..i]);
    to_lower(buf[..]);
    return buf[..];
}

// style_parse writes the SGR codes of the style string spec into
// out_codes. It returns 0, or -1 for a bad word or for a string that has
// only "not" words. The codes come in the order of rich: the attributes by
// code, then the foreground, then the background. The last colour wins.
fn style_parse(out_codes: i64[>..]&, spec: u8[:]) -> i64 {
    var on: bool[64] = [false; 64];
    var fg: i64[>..] = [];
    var bg: i64[>..] = [];
    var buf: u8[>..] = [];
    var i = 0;
    var words = 0;
    var produced = false;
    while i < spec.len {
        let w = next_word(buf, spec, i);
        if w.len == 0 { break; }
        words += 1;
        if w == "none" { produced = true; continue; }
        if w == "not" {
            var nb: u8[>..] = [];
            let a = attr_code(next_word(nb, spec, i));
            if a < 0 { return -1; }
            on[a] = false;
            continue;
        }
        if w == "on" {
            var cb: u8[>..] = [];
            bg.clear();
            if !parse_color_word(bg, next_word(cb, spec, i), true) { return -1; }
            produced = true;
            continue;
        }
        if w == "link" {
            // The url goes to style_link. The word writes no code.
            var ub: u8[>..] = [];
            if next_word(ub, spec, i).len == 0 { return -1; }
            produced = true;
            continue;
        }
        let a = attr_code(w);
        if a >= 0 { on[a] = true; produced = true; continue; }
        fg.clear();
        if !parse_color_word(fg, w, false) { return -1; }
        produced = true;
    }
    if !produced && words > 0 { return -1; }
    for a in ATTR_ORDER {
        if on[a] { out_codes.push(a); }
    }
    for c in fg { out_codes.push(c); }
    for c in bg { out_codes.push(c); }
    return 0;
}

// style_link reads the url of the "link" word of the style string spec
// into out_url. It returns 1 when the word is there and 0 when it is not.
fn style_link(out_url: u8[>..]&, spec: u8[:]) -> i64 {
    var i = 0;
    while i < spec.len {
        while i < spec.len && spec[i] == ' ' { i += 1; }
        if i >= spec.len { break; }
        var j = i;
        while j < spec.len && spec[j] != ' ' { j += 1; }
        let word = spec[i..j];
        i = j;
        if word == "link" {
            while i < spec.len && spec[i] == ' ' { i += 1; }
            var k = i;
            while k < spec.len && spec[k] != ' ' { k += 1; }
            out_url.append(spec[i..k]);
            return 1;
        }
    }
    return 0;
}
