#!/usr/bin/env python3
"""Make the width tables of the ansi package.

The script reads the Unicode data files and prints the Goose table blocks.
The output goes into width.goose.

    python3 scripts/build-width.py /path/to/unicode-data > width.goose

The data files are:

  EastAsianWidth.txt          the width of a code point
  DerivedGeneralCategory.txt  the category of a code point
  emoji-data.txt              the emoji properties of a code point

The script uses only the standard library of Python.
"""

import os
import sys

# The Default_Ignorable_Code_Point set of the Unicode data. The list is
# small and it does not change often.
DEFAULT_IGNORABLE = [
    (0x00AD, 0x00AD), (0x034F, 0x034F), (0x061C, 0x061C),
    (0x115F, 0x1160), (0x17B4, 0x17B5), (0x180B, 0x180F),
    (0x200B, 0x200F), (0x202A, 0x202E), (0x2060, 0x2064),
    (0x2065, 0x2065), (0x2066, 0x206F), (0xFEFF, 0xFEFF),
    (0xFFF0, 0xFFF8), (0x1BCA0, 0x1BCA3), (0x1D173, 0x1D17A),
    (0xE0000, 0xE0FFF),
]

# The Other_Grapheme_Extend set of the Unicode data. Most of the code points
# are marks already. The list holds the rest.
OTHER_GRAPHEME_EXTEND = [
    (0x200C, 0x200C), (0xFF9E, 0xFF9F), (0x1133E, 0x1133E),
    (0x11357, 0x11357), (0x114B0, 0x114C3), (0x114BD, 0x114BD),
    (0x115AF, 0x115AF), (0x11930, 0x11930), (0x1D165, 0x1D165),
    (0x1D16E, 0x1D172), (0xE0020, 0xE007F),
]

# The emoji modifiers. They join the cluster before them.
EMOJI_MODIFIER = [(0x1F3FB, 0x1F3FF)]

# The regional indicators. They pair up.
REGIONAL_INDICATOR = [(0x1F1E6, 0x1F1FF)]

# The zero width joiner and the zero width non-joiner. They join the
# cluster before them.
ZWJ = 0x200D


def read_props(path):
    """Read a Unicode data file. It gives a dict of property to ranges."""
    props = {}
    with open(path, encoding="utf-8") as handle:
        for line in handle:
            line = line.split("#")[0].strip()
            if not line:
                continue
            parts = [x.strip() for x in line.split(";")]
            if len(parts) < 2:
                continue
            rng, prop = parts[0], parts[1]
            if ".." in rng:
                first, last = rng.split("..")
                first, last = int(first, 16), int(last, 16)
            else:
                first = last = int(rng, 16)
            props.setdefault(prop, []).append((first, last))
    return props


def to_set(ranges):
    """Turn a list of ranges into a set of code points."""
    out = set()
    for first, last in ranges:
        out.update(range(first, last + 1))
    return out


def merge(ranges):
    """Merge ranges and sort them."""
    points = sorted(to_set(ranges))
    out = []
    for cp in points:
        if out and cp == out[-1][1] + 1:
            out[-1][1] = cp
        else:
            out.append([cp, cp])
    return [(a, b) for a, b in out]


def emit(name, ranges, comment):
    """Print a Goose table of ranges."""
    ranges = merge(ranges)
    print("// %s" % comment)
    print("let %s_LO: u32[%d] = [" % (name, len(ranges)))
    print("    " + ", ".join("0x%X" % a for a, _ in ranges))
    print("];")
    print()
    print("let %s_HI: u32[%d] = [" % (name, len(ranges)))
    print("    " + ", ".join("0x%X" % b for _, b in ranges))
    print("];")
    print()


def main():
    if len(sys.argv) != 2:
        sys.stderr.write("usage: build-width.py <unicode-data-dir>\n")
        return 2
    root = sys.argv[1]
    eaw = read_props(os.path.join(root, "EastAsianWidth.txt"))
    cat = read_props(os.path.join(root, "DerivedGeneralCategory.txt"))
    emo = read_props(os.path.join(root, "emoji-data.txt"))

    wide = [r for r in eaw.get("W", []) + eaw.get("F", [])]
    ambiguous = eaw.get("A", [])

    # The marks. They join the cluster before them and they take no column.
    marks = cat.get("Mn", []) + cat.get("Mc", []) + cat.get("Me", [])

    # The emoji set of the references. It holds every code point with the
    # Emoji property, except the digits, the hash and the asterisk. Those
    # three take one column on their own.
    emoji = [r for r in emo.get("Emoji", [])]
    digits = [(0x23, 0x23), (0x2A, 0x2A), (0x30, 0x39)]
    excluded = to_set(digits) | to_set(REGIONAL_INDICATOR)
    emoji = [(a, b) for a, b in emoji if not any(a <= x <= b for x in excluded)]
    # The emoji that show as a picture without a selector. The others show
    # as text, one column, until the selector U+FE0F follows them.
    pres = [r for r in emo.get("Emoji_Presentation", [])
            if r[0] not in excluded]

    # The zero width code points. A mark, a control, a format and the
    # default ignorable ones.
    zero = marks + cat.get("Cc", []) + cat.get("Cf", []) + cat.get("Zl", [])
    zero = zero + cat.get("Zp", []) + DEFAULT_IGNORABLE

    # The code points that end a cluster. A control or a format ends it.
    # The joiner, the non-joiner and the tag characters do not.
    enders = cat.get("Cc", []) + cat.get("Cf", []) + cat.get("Zl", [])
    enders = enders + cat.get("Zp", []) + [(0x2065, 0x2065), (0xFFF0, 0xFFF8)]
    keep = to_set([(ZWJ, ZWJ), (0x200C, 0x200C), (0xE0020, 0xE007F)])
    enders = [(a, b) for a, b in enders if not any(a <= x <= b for x in keep)]

    # The code points that join the cluster before them.
    join = marks + OTHER_GRAPHEME_EXTEND + EMOJI_MODIFIER

    print("// The width tables of the ansi package.")
    print("//")
    print("// The script scripts/build-width.py makes this file from the Unicode")
    print("// data files. Do not edit the tables by hand.")
    print()
    emit("WIDE", wide, "The East Asian Wide and Fullwidth code points.")
    emit("AMBIGUOUS", ambiguous, "The East Asian Ambiguous code points.")
    emit("EMOJI", emoji, "The code points with the Emoji property.")
    emit("PRES", pres, "The code points with the Emoji_Presentation property.")
    emit("ZERO", zero, "The code points that take no column.")
    emit("END", enders, "The code points that end a cluster.")
    emit("JOIN", join, "The code points that join the cluster before them.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
