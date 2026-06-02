module tiny_vm::secd_asm;

import std::io;
import std::io::file;
import std::collections::list;

import tiny_vm::parse;
import tiny_vm::serialize;

fn void usage(String[] args) {
    io::printfn("Usage: %s -i input.secd -o output.bin", args[0]);
}


fn void main(String[] args) {
    if (args.len < 5) {
        io::printn("Incorrect flags");
    }
    String input_name = args[2];
    String output_name = args[4];
    Serial output;

    Header h;

    char[]? input_text = file::load(mem, input_name);

    if (catch fail_open = input_text) {
        io::printfn("Failed to load input file %s: %s", input_name, fail_open);
        return;
    }
    Spans myspans;
    myspans.init();
    CodeMeta? code = parse::parse_input((String)input_text, myspans);
    if (catch fail_parse = code) {
        io::printfn("Failed to parse input file: %s", fail_parse);
        return;
    }

    if (catch reason = parse::print_code(myspans.labels, code.code)) {
        io::printfn("Printing failed with reason \'%s\'", reason);
        return;
    }
    
    if (catch fail_out = output.init(output_name)) {
        io::printfn("Failed to open output file: %s", fail_out);
        return;
    }

    StrTable strs = serialize::build_string_table(code);

    if (catch header_wrong = output.write_header(h)) {
        io::printfn("Failed to write header to output file: %s", header_wrong);
        return;
    }

    if (catch strings_wrong = output.write_strings(strs)) {
        io::printfn("Failed to write strings to output file: %s", strings_wrong);
        return;
    }

    if (catch labels_wrong = output.write_labels(&code)) {
        io::printfn("Failed to write label table to output file: %s", labels_wrong);
        return;
    }

    if (catch code_wrong = output.write_code(&code)) {
        io::printfn("Failed to write label table to output file: %s", code_wrong);
        return;
    }

    h.l_len    = (uint)output.labels_len;
    h.l_tbl    = (uint)output.labels_off;

    if (code.labels.has_key("entry")) {
        usz entry_loc = code.labels.get("entry")!!;
        h.entry = (sz)entry_loc;
    } else {
        h.entry = -1;
    }

    if (catch header_wrong = output.write_header(h)) {
        io::printfn("Failed to write updated header to output file: %s", header_wrong);
        return;
    }

    if (catch file_wrong = output.save()) {
        io::printfn("Failed to close output file: %s", file_wrong);
        return;
    }
    io::printfn("Finished assembling %s, saved to %s", input_name, output_name);
}
