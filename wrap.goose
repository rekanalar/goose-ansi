// Word wrap that keeps the SGR state and the hyperlink.
//
// A line break closes the open link and resets the style. The next line
// opens them again. Escape sequences take no columns.
//
// The style state holds the SGR codes that are open. A reset clears it.
// A new foreground or background colour replaces the old one. A close code
// removes the code that it closes.

namespace ansi;

import std;
import width;
import escape;

// close_of gives the SGR code that closes the open code c. It gives 0 when
// the code has no close.
fn close_of(c: i64) -> i64 {
    if c == 1 || c == 2 { return 22; }
    if c == 3 { return 23; }
    if c == 4 || c == 21 { return 24; }
    if c == 5 { return 25; }
    if c == 6 { return 26; }
    if c == 7 { return 27; }
    if c == 8 { return 28; }
    if c == 9 { return 29; }
    if c == 51 || c == 52 { return 54; }
    if c == 53 { return 55; }
    return 0;
}

// sgr_codes adds the codes of an SGR sequence to the state. A reset clears
// the state. A new foreground or background colour replaces the old one.
// A close code removes the code that it closes.
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
        } else if v == 38 || v == 48 || v == 58 {
            // The colour that follows takes more codes. The old colour of
            // the same kind goes away.
            while codes.len > 0 {
                let last = codes[codes.len - 1];
                if last == 38 || last == 48 || last == 58 || last == 5 || last == 2 { codes.pop(); } else { break; }
            }
            codes.push(v);
            // The kind of the colour: 5 for the palette, 2 for RGB. The test
            // reads the kind, so an RGB colour takes three values.
            if k + 1 < parsed.len { codes.push(parsed[k + 1]); k += 1; }
            // The values of the colour follow.
            var want = 1;
            if parsed[k] == 2 { want = 3; }
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
            // A close code takes the code that it closes out of the state.
            var keep: i64[>..<] = [];
            for c in codes {
                if close_of(c) != v { keep.push(c); }
            }
            while codes.len > 0 { codes.pop(); }
            for c in keep { codes.push(c); }
            codes.push(v);
        }
        k += 1;
    }
}

// track updates the state with the sequence s[i..end].
fn track(s: u8[:], i: i64, end: i64, codes: i64[>..<]&, link: u8[>..<]&) {
    if is_sgr(s, i, end) {
        sgr_codes(s[csi_body(i)..end - 1], codes);
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
        var end = 0;
        var w = 0;
        cluster_scan(word, i, true, end, w);
        if hard && col > 0 && col + w > width {
            line_break(out, codes, link);
            col = 0;
        }
        out.append(word[i..end]);
        col += w;
        i = end;
    }
}

// wrap_width writes the text and breaks the line at the width. It gives
// the new column count. The break comes at the width, not at a space.
fn wrap_width(out: u8[>..]&, s: u8[:], width: i64, col: i64&, codes: i64[>..<]&, link: u8[>..<]&) {
    var i = 0;
    while i < s.len {
        if s[i] == '\n' {
            line_break(out, codes, link);
            col = 0;
            i += 1;
            continue;
        }
        let e = escape_end(s, i);
        if e >= 0 {
            track(s, i, e, codes, link);
            out.append(s[i..e]);
            i = e;
            continue;
        }
        var end = 0;
        var w = 0;
        cluster_scan(s, i, true, end, w);
        if col > 0 && col + w > width {
            line_break(out, codes, link);
            col = 0;
        }
        out.append(s[i..end]);
        col += w;
        i = end;
    }
}

// wrap_full writes s into out with a break before the word that crosses
// width columns. A newline in s starts a new line. A space at a break is
// dropped when trim is true.
//
// With word_wrap false the break comes at the width and not at a space.
// With hard a word that is wider than the width breaks inside the word.
fn wrap_full(out: u8[>..]&, s: u8[:], width: i64, hard: bool, trim: bool, word_wrap: bool) {
    var codes: i64[>..<] = [];
    var link: u8[>..<] = [];
    var col = 0;
    if !word_wrap {
        wrap_width(out, s, width, col, codes, link);
        return;
    }
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
            if trim { spaces = 0; }
        }
        for k in 0..spaces { out.push(' '); }
        col += spaces;
        spaces = 0;
        emit_word(out, word, width, hard, col, codes, link);
        i = j;
    }
}

// wrap writes s into out with a break before the word that crosses width
// columns. A newline in s starts a new line. A space at a break is dropped.
// A word wider than width stays whole, or breaks when hard is true.
fn wrap(out: u8[>..]&, s: u8[:], width: i64, hard: bool) {
    wrap_full(out, s, width, hard, true, true);
}
