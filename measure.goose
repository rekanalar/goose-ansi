// Measuring styled text for the ansi package.
//
// The scanner walks the bytes once. It keeps the bytes that are not inside
// an SGR sequence, and it counts the visible columns of the bytes it keeps.
//
// A column holds one narrow character or half of a wide one. The wide
// characters are the East Asian Wide and Fullwidth ranges of Unicode. A
// malformed UTF-8 byte counts one column.

namespace ansi;

import std;
import width;

// strip writes s without its SGR sequences into out. Another kind of
// escape sequence stays. A sequence is ESC, '[', any bytes up to 'm'.
fn strip(out: u8[>..]&, s: u8[:]) {
    var i = 0;
    while i < s.len {
        if s[i] == 0x1b && i + 1 < s.len && s[i + 1] == '[' {
            var j = i + 2;
            while j < s.len && !is_final_byte(s[j]) { j += 1; }
            if j < s.len {
                i = j + 1;
                continue;
            }
        }
        out.push(s[i]);
        i += 1;
    }
}

// is_final_byte returns true when the byte ends an escape sequence. The
// final byte of an SGR sequence is 'm', and the parameter bytes before it
// are digits and separators.
fn is_final_byte(b: u8) -> bool {
    return b == 'm';
}

// len returns the visible length of s in columns. It skips the SGR
// sequences.
fn len(s: u8[:]) -> i64 {
    var text: u8[>..] = [];
    strip(text, s);
    var n = 0;
    var i = 0;
    while i < text.len {
        let b = text[i];
        if b < 0x80 {
            n += 1;
            i += 1;
            continue;
        }
        let cp = decode_utf8(text, i);
        var size = utf8_size(b);
        if i + size > text.len { size = text.len - i; }
        n += char_width(cp);
        i += size;
    }
    return n;
}

// utf8_size returns the number of bytes of the UTF-8 sequence that starts
// with the byte b. It returns 1 for a malformed byte.
fn utf8_size(b: u8) -> i64 {
    if b >= 0xF0 { return 4; }
    if b >= 0xE0 { return 3; }
    if b >= 0xC0 { return 2; }
    return 1;
}

// decode_utf8 returns the code point of the sequence at i. A malformed
// sequence gives U+FFFD.
fn decode_utf8(s: u8[:], i: i64) -> i64 {
    let size = utf8_size(s[i]);
    if i + size > s.len { return 0xFFFD; }
    if size == 1 {
        if s[i] >= 0x80 { return 0xFFFD; }
        return s[i];
    }
    // The bytes go into i64 values first. The shifts then keep their
    // values, because a shift on a u8 would lose the high bits.
    if size == 2 {
        if (s[i] & 0xE0) != 0xC0 || (s[i + 1] & 0xC0) != 0x80 { return 0xFFFD; }
        let a: i64 = s[i];
        let b: i64 = s[i + 1];
        return (a & 0x1F) << 6 | (b & 0x3F);
    }
    if size == 3 {
        if (s[i] & 0xF0) != 0xE0 || (s[i + 1] & 0xC0) != 0x80 || (s[i + 2] & 0xC0) != 0x80 { return 0xFFFD; }
        let a: i64 = s[i];
        let b: i64 = s[i + 1];
        let c: i64 = s[i + 2];
        return (a & 0x0F) << 12 | (b & 0x3F) << 6 | (c & 0x3F);
    }
    if (s[i] & 0xF8) != 0xF0 || (s[i + 1] & 0xC0) != 0x80 || (s[i + 2] & 0xC0) != 0x80 || (s[i + 3] & 0xC0) != 0x80 { return 0xFFFD; }
    let a: i64 = s[i];
    let b: i64 = s[i + 1];
    let c: i64 = s[i + 2];
    let d: i64 = s[i + 3];
    return (a & 0x07) << 18 | (b & 0x3F) << 12 | (c & 0x3F) << 6 | (d & 0x3F);
}

// truncate writes at most width columns of s into out. The sequences it
// passes stay in place. A cut of styled text ends with the reset sequence.
//
// A sequence is held until a visible character follows it. A sequence with
// no character after it is dropped. This keeps a cut of plain text plain.
fn truncate(out: u8[>..]&, s: u8[:], width: i64) {
    var columns = 0;
    var i = 0;
    var cut = false;
    var styled = false;
    // The bytes of the sequence that waits for a visible character.
    var pending_start = -1;
    var pending_end = -1;
    while i < s.len {
        if s[i] == 0x1b && i + 1 < s.len && s[i + 1] == '[' {
            var j = i + 2;
            while j < s.len && !is_final_byte(s[j]) { j += 1; }
            if j < s.len {
                pending_start = i;
                pending_end = j + 1;
                i = j + 1;
                continue;
            }
        }
        if cut {
            i += 1;
            continue;
        }
        let b = s[i];
        var size = 1;
        var w = 1;
        if b >= 0x80 {
            let cp = decode_utf8(s, i);
            size = utf8_size(b);
            // A sequence cut at the end of the text has fewer bytes.
            if i + size > s.len { size = s.len - i; }
            w = char_width(cp);
        }
        if columns + w > width {
            cut = true;
            i += size;
            continue;
        }
        // The character is kept, so the sequence before it is kept too.
        if pending_start >= 0 {
            out.append(s[pending_start..pending_end]);
            pending_start = -1;
            styled = true;
        }
        columns += w;
        out.append(s[i..i + size]);
        i += size;
    }
    if cut && styled { out.append("\x1b[0m"); }
}
