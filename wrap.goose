// Word wrap that keeps the SGR state and the hyperlink.
//
// A line break closes the open link and resets the style. The next line
// opens them again. Escape sequences take no columns.
//
// The style state holds the SGR codes that are open. A reset clears it.
// The link state holds the OSC 8 sequence that opens the current link.

namespace ansi;

import std;

// sgr_codes adds the codes of an SGR sequence to the state. A reset clears
// the state. A new foreground or background colour replaces the old one.
fn sgr_codes(params: u8[:], codes: i64[>..<]&) {
    if params.len == 0 {
        while codes.len > 0 { codes.pop(); }
        return;
    }
    // The codes of the sequence, in order.
    var parsed: i64[>..<] = [];
    var i = 0;
    while i < params.len {
        var j = i;
        while j < params.len && params[j] != ';' { j += 1; }
        let v, ok = parse_int(params[i..j]);
        if ok { parsed.push(v); }
        i = j + 1;
    }
    var k = 0;
    while k < parsed.len {
        let v = parsed[k];
        if v == 0 {
            while codes.len > 0 { codes.pop(); }
        } else if v == 38 || v == 48 {
            // The colour that follows takes more codes. The old colour of
            // the same kind goes away.
            while codes.len > 0 {
                let last = codes[codes.len - 1];
                if last == 38 || last == 48 || last == 5 || last == 2 { codes.pop(); } else { break; }
            }
            codes.push(v);
            // The kind of the colour: 5 for the palette, 2 for RGB.
            if k + 1 < parsed.len { codes.push(parsed[k + 1]); k += 1; }
            // The values of the colour follow.
            var want = 1;
            if k + 1 < parsed.len && parsed[k + 1] == 2 { want = 3; }
            var got = 0;
            while got < want && k + 1 < parsed.len {
                k += 1;
                codes.push(parsed[k]);
                got += 1;
            }
        } else if v >= 30 && v <= 37 || v >= 90 && v <= 97 {
            while codes.len > 0 {
                let last = codes[codes.len - 1];
                if last >= 30 && last <= 37 || last >= 90 && last <= 97 { codes.pop(); } else { break; }
            }
            codes.push(v);
        } else if v >= 40 && v <= 47 || v >= 100 && v <= 107 {
            while codes.len > 0 {
                let last = codes[codes.len - 1];
                if last >= 40 && last <= 47 || last >= 100 && last <= 107 { codes.pop(); } else { break; }
            }
            codes.push(v);
        } else {
            codes.push(v);
        }
        k += 1;
    }
}

// track updates the state with the sequence s[i..end].
fn track(s: u8[:], i: i64, end: i64, codes: i64[>..<]&, link: u8[>..<]&) {
    if is_sgr(s, i, end) {
        sgr_codes(s[i + 2..end - 1], codes);
    } else if is_osc8(s, i, end) {
        while link.len > 0 { link.pop(); }
        if osc8_opens(s, i, end) { link.append(s[i..end]); }
    }
}

// write_codes writes the SGR codes as one sequence.
fn write_codes(out: u8[>..]&, codes: i64[:]) {
    if codes.len == 0 { return; }
    out.append("\x1b[");
    for c, i in codes {
        if i > 0 { out.push(';'); }
        format(out, c);
    }
    out.push('m');
}

// line_break writes a newline and carries the open style and link over.
fn line_break(out: u8[>..]&, codes: i64[>..<]&, link: u8[>..<]&) {
    if link.len > 0 { out.append("\x1b]8;;\x07"); }
    if codes.len > 0 { out.append("\x1b[0m"); }
    out.push('\n');
    write_codes(out, codes);
    if link.len > 0 { out.append(link); }
}

// emit_word writes the word and moves col. With hard set it breaks a word
// that crosses the width. Else the word stays whole.
fn emit_word(out: u8[>..]&, word: u8[:], width: i64, hard: bool, col: i64&, codes: i64[>..<]&, link: u8[>..<]&) {
    var i = 0;
    while i < word.len {
        let e = escape_end(word, i);
        if e >= 0 {
            track(word, i, e, codes, link);
            out.append(word[i..e]);
            i = e;
            continue;
        }
        var size = 1;
        var w = 1;
        if word[i] >= 0x80 {
            size = utf8_size(word[i]);
            if i + size > word.len { size = word.len - i; }
            w = char_width(decode_utf8(word, i));
        }
        if hard && col > 0 && col + w > width {
            line_break(out, codes, link);
            col = 0;
        }
        out.append(word[i..i + size]);
        col += w;
        i += size;
    }
}

// wrap writes s into out with a break before the word that crosses width
// columns. A newline in s starts a new line. A space at a break is dropped.
// A word wider than width stays whole, or breaks when hard is true.
fn wrap(out: u8[>..]&, s: u8[:], width: i64, hard: bool) {
    var codes: i64[>..<] = [];
    var link: u8[>..<] = [];
    var col = 0;
    var spaces = 0;
    var i = 0;
    while i < s.len {
        if s[i] == '\n' {
            line_break(out, codes, link);
            col = 0;
            spaces = 0;
            i += 1;
            continue;
        }
        if s[i] == ' ' {
            spaces += 1;
            i += 1;
            continue;
        }
        var j = i;
        while j < s.len && s[j] != ' ' && s[j] != '\n' { j += 1; }
        let word = s[i..j];
        if col > 0 && col + spaces + len(word) > width {
            line_break(out, codes, link);
            col = 0;
            spaces = 0;
        }
        for k in 0..spaces { out.push(' '); }
        col += spaces;
        spaces = 0;
        emit_word(out, word, width, hard, col, codes, link);
        i = j;
    }
}
