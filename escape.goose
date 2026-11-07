// Escape sequence scanning for the ansi package.
//
// A CSI sequence is ESC '[', parameter bytes 0x30-0x3F, intermediate bytes
// 0x20-0x2F, and one final byte 0x40-0x7E. An OSC sequence is ESC ']', any
// bytes, and an end: BEL or ESC '\'. This is the set that strip-ansi takes.

namespace ansi;

import std;

// escape_end returns the index after the sequence that starts at i. It
// returns -1 when no complete CSI or OSC sequence starts there.
fn escape_end(s: u8[:], i: i64) -> i64 {
    if s[i] != 0x1b || i + 1 >= s.len { return -1; }
    var j = i + 2;
    if s[i + 1] == '[' {
        while j < s.len && s[j] >= 0x30 && s[j] <= 0x3f { j += 1; }
        while j < s.len && s[j] >= 0x20 && s[j] <= 0x2f { j += 1; }
        if j < s.len && s[j] >= 0x40 && s[j] <= 0x7e { return j + 1; }
        return -1;
    }
    if s[i + 1] == ']' {
        while j < s.len {
            if s[j] == 0x07 { return j + 1; }
            if s[j] == 0x1b && j + 1 < s.len && s[j + 1] == '\\' { return j + 2; }
            j += 1;
        }
    }
    return -1;
}

// is_sgr returns true when the sequence s[i..end] is a CSI "m" sequence.
fn is_sgr(s: u8[:], i: i64, end: i64) -> bool {
    return s[i + 1] == '[' && s[end - 1] == 'm';
}

// is_osc8 returns true when the sequence s[i..end] is an OSC 8 hyperlink.
fn is_osc8(s: u8[:], i: i64, end: i64) -> bool {
    return end - i >= 5 && s[i + 1] == ']' && s[i + 2] == '8' && s[i + 3] == ';';
}

// osc8_opens returns true when the OSC 8 sequence has a non-empty URL. The
// form is ESC ] 8 ; params ; URL terminator.
fn osc8_opens(s: u8[:], i: i64, end: i64) -> bool {
    var j = i + 4;
    while j < end && s[j] != ';' { j += 1; }
    j += 1;
    if j >= end { return false; }
    return s[j] != 0x07 && s[j] != 0x1b;
}
