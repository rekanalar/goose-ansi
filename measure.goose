// Measuring styled text for the ansi package.
//
// The scanner walks the text once. It keeps the bytes that are not inside
// an escape sequence, and it counts the visible columns of the clusters it
// keeps.
//
// A column holds one narrow character or half of a wide one. The width of
// a cluster comes from the width model of the width module.

namespace ansi;

import std;
import width;
import escape;

// truncate writes at most width columns of s into out. The sequences it
// passes stay in place. A cut of styled text ends with the reset sequence,
// and a cut inside a hyperlink closes the link.
//
// A sequence is held until a visible character follows it. A cut drops the
// sequences after the last kept character. Text that fits keeps them all.
fn truncate(out: u8[>..]&, s: u8[:], width: i64) {
    var columns = 0;
    var i = 0;
    var cut = false;
    var styled = false;
    var link_open = false;
    var pending_sgr = false;
    // The bytes of the sequences that wait for a visible character.
    var pending_start = -1;
    var pending_end = -1;
    while i < s.len {
        let e = escape_end(s, i);
        if e >= 0 {
            if pending_start < 0 { pending_start = i; }
            pending_end = e;
            if is_sgr(s, i, e) { pending_sgr = true; }
            if !cut && is_osc8(s, i, e) { link_open = osc8_opens(s, i, e); }
            i = e;
            continue;
        }
        var end = 0;
        var w = 0;
        cluster_scan(s, i, true, end, w);
        if columns + w > width {
            cut = true;
            i = end;
            continue;
        }
        // The cluster is kept, so the sequences before it are kept too.
        if pending_start >= 0 {
            out.append(s[pending_start..pending_end]);
            pending_start = -1;
            if pending_sgr { styled = true; }
            pending_sgr = false;
        }
        columns += w;
        out.append(s[i..end]);
        i = end;
    }
    if !cut && pending_start >= 0 { out.append(s[pending_start..pending_end]); }
    if cut && link_open { out.append("\x1b]8;;\x07"); }
    if cut && styled { out.append("\x1b[0m"); }
}

// truncate_with writes s when it fits in width columns. Else it writes the
// cut of s and then tail, and the whole result takes width columns. A tail
// wider than width is cut itself.
fn truncate_with(out: u8[>..]&, s: u8[:], width: i64, tail: u8[:]) {
    if len(s) <= width { out.append(s); return; }
    let tw = len(tail);
    if tw >= width { truncate(out, tail, width); return; }
    truncate(out, s, width - tw);
    out.append(tail);
}

// truncate_ellipsis is truncate_with and the one character U+2026.
fn truncate_ellipsis(out: u8[>..]&, s: u8[:], width: i64) {
    truncate_with(out, s, width, "\xe2\x80\xa6");
}
