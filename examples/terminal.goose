// Shows the terminal check, the size, the override and the style parser.
import std;
import ansi from "..";

fn main() {
    print("stdout is a terminal: ", ansi::is_tty_stdout());
    var size: u8[>..] = [];
    ansi::terminal_size(size);
    print("size (columns rows): ", size);

    var codes: i64[>..] = [];
    if style::style_parse(codes, "bold red on blue") == 0 {
        var out: u8[>..] = [];
        ansi::style(out, "parsed style", codes[..]);
        print(out);
    }

    ansi::set_override(0);
    print("override level: ", ansi::color_level());
    ansi::unset_override();

    var line: u8[>..] = [];
    ansi::wrap_full(line, "a joined emoji takes two columns", 12, false, true, true);
    print(line);
    print("width of a family emoji: ", ansi::len("\xf0\x9f\x91\xa8\xe2\x80\x8d\xf0\x9f\x91\xa9\xe2\x80\x8d\xf0\x9f\x91\xa7"));
    return 0;
}
