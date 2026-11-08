// Escape sequence scanning for the ansi package.
//
// A CSI sequence is ESC '[', parameter bytes 0x30-0x3F, intermediate bytes
// 0x20-0x2F, and one final byte 0x40-0x7E. An OSC sequence is ESC ']', any
// bytes, and an end: BEL, ESC '\' or the byte 0x9C. The byte 0x9B starts a
// CSI sequence and the byte 0x9D starts an OSC sequence. This is the set
// that strip-ansi takes.

namespace ansi;

import std;

// The C1 controls are code points U+009B (CSI), U+009C (ST) and U+009D
// (OSC). In UTF-8 text each takes the two bytes 0xC2 and 0x9B, 0x9C or 0x9D.
// A lone byte 0x9B is a continuation byte of another character, so it never
// starts a sequence.

// c1_at tells whether the C1 control with the low byte lo starts at i.
fn c1_at(s: u8[:], i: i64, lo: u8) -> bool {
    return i + 1 < s.len && s[i] == 0xc2 && s[i + 1] == lo;
}

// csi_end returns the index after the CSI sequence whose body starts at j.
fn csi_end(s: u8[:], j: i64) -> i64 {
    var k = j;
    while k < s.len && s[k] >= 0x30 && s[k] <= 0x3f { k += 1; }
    while k < s.len && s[k] >= 0x20 && s[k] <= 0x2f { k += 1; }
    if k < s.len && s[k] >= 0x40 && s[k] <= 0x7e { return k + 1; }
    return -1;
}

// OSC_MAX is the longest body that osc_end reads. An open sequence with no
// end would else make every scan quadratic. A hyperlink of 2048 bytes is
// longer than any terminal takes.
let OSC_MAX: i64 = 2048;

// osc_end returns the index after the OSC sequence whose body starts at j.
// The ends are BEL, ESC backslash and the C1 control ST. It returns -1 for
// a body with no end in OSC_MAX bytes.
fn osc_end(s: u8[:], j: i64) -> i64 {
    var k = j;
    var limit = s.len;
    if j + OSC_MAX < limit { limit = j + OSC_MAX; }
    while k < limit {
        if s[k] == 0x07 { return k + 1; }
        if c1_at(s, k, 0x9c) { return k + 2; }
        if s[k] == 0x1b && k + 1 < s.len && s[k + 1] == '\\' { return k + 2; }
        k += 1;
    }
    return -1;
}

// escape_end returns the index after the sequence that starts at i. It
// returns -1 when no complete CSI or OSC sequence starts there.
fn escape_end(s: u8[:], i: i64) -> i64 {
    if i >= s.len { return -1; }
    if c1_at(s, i, 0x9b) { return csi_end(s, i + 2); }
    if c1_at(s, i, 0x9d) { return osc_end(s, i + 2); }
    if s[i] != 0x1b || i + 1 >= s.len { return -1; }
    let k = s[i + 1];
    if k == '[' { return csi_end(s, i + 2); }
    if k == ']' { return osc_end(s, i + 2); }
    return -1;
}

// csi_body gives the index of the first parameter byte of a CSI sequence.
fn csi_body(i: i64) -> i64 {
    return i + 2;
}

// osc_body gives the index of the first byte of the body of an OSC
// sequence.
fn osc_body(i: i64) -> i64 {
    return i + 2;
}

// is_csi tells whether the sequence s[i..end] is a CSI sequence.
fn is_csi(s: u8[:], i: i64, end: i64) -> bool {
    if c1_at(s, i, 0x9b) { return true; }
    return s[i] == 0x1b && i + 1 < end && s[i + 1] == '[';
}

// is_osc tells whether the sequence s[i..end] is an OSC sequence.
fn is_osc(s: u8[:], i: i64, end: i64) -> bool {
    if c1_at(s, i, 0x9d) { return true; }
    return s[i] == 0x1b && i + 1 < end && s[i + 1] == ']';
}

// is_sgr returns true when the sequence s[i..end] is a CSI "m" sequence.
fn is_sgr(s: u8[:], i: i64, end: i64) -> bool {
    return is_csi(s, i, end) && end > i && s[end - 1] == 'm';
}

// is_osc8 returns true when the sequence s[i..end] is an OSC 8 hyperlink.
fn is_osc8(s: u8[:], i: i64, end: i64) -> bool {
    if !is_osc(s, i, end) { return false; }
    let b = osc_body(i);
    return b + 2 <= end && s[b] == '8' && s[b + 1] == ';';
}

// osc8_opens returns true when the OSC 8 sequence has a non-empty URL. The
// form is ESC ] 8 ; params ; URL terminator.
fn osc8_opens(s: u8[:], i: i64, end: i64) -> bool {
    let b = osc_body(i);
    var j = b + 2;
    while j < end && s[j] != ';' { j += 1; }
    j += 1;
    if j >= end { return false; }
    return s[j] != 0x07 && s[j] != 0x1b && !c1_at(s, j, 0x9c);
}

// has_escape tells whether the text holds a byte that starts a sequence.
fn has_escape(s: u8[:]) -> bool {
    for b in s {
        if b == 0x1b || b == 0xc2 { return true; }
    }
    return false;
}

// strip writes s without its CSI and OSC sequences into out. An open
// sequence with no end stays.
fn strip(out: u8[>..]&, s: u8[:]) {
    if !has_escape(s) {
        out.append(s);
        return;
    }
    var i = 0;
    while i < s.len {
        let e = escape_end(s, i);
        if e >= 0 {
            i = e;
            continue;
        }
        out.push(s[i]);
        i += 1;
    }
}
