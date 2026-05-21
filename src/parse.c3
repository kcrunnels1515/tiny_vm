module tiny_vm::parse;

// import tiny_vm::opers;

import std::io;
import std::collections::list;
import std::collections::linkedlist;
import std::collections::map;
import std::core::mem::allocator;

// typedef sz = inline sz;

faultdef 
    ARRAY_OVERFLOW,
    INCONS_STATE,
    NO_TAG,
    EXCESSIVE_ARGS,
    INVALID_TOKEN,
    UNDEF_REF;

enum TokenType : char (String name) {
    LIST_START  {"LIST_START"},
    QUOTE		{"QUOTE"},
    INSTR		{"INSTR"},
    INT_TOK		{"INT_TOK"},
    FLOAT_TOK	{"FLOAT_TOK"},
    REF			{"REF"},
    LABEL		{"LABEL"},
    ATOM		{"ATOM"},
    NIL_TOK		{"NIL_TOK"},
}

bool label_mode = false;

struct Pair
{
    usz fst; 
    usz snd;
}

struct Span {
    usz fst;
    usz snd;
    int section;
    sz w_off;
    bool is_list;
    bool ignore;
    List{usz} children;
}

struct SpanPair {
    Span* real;
    Span* copied;
}

struct CodeData {
    TokenType tt;
    // bool initialized;
    union {
        String str;
        long iVal;
        double fVal;
    }
    sz arg1;
    sz arg2;
    usz next;
}

fn List{Span} scan_parens(String input) {
    List{Span} oStck;
    List{Span} spans;
    int depth = 0;

    for (usz i = 0; i < input.len; i++) {
        if (input[i] == '(') {
            Span open = { .fst = i, .snd = 0, .section = depth, .w_off = -1, .is_list = true };
            if (i > 0 && input[i-1] == '#') {
                open.fst = i-1;
            }
            oStck.push(open);
            depth++;
        } else if (input[i] == ')') {
            Span? own = oStck.pop();
            if (catch reason = own) {
                io::printfn("Nothing in open paren stack");
                break;
            } else {
                depth--;
                own.snd = i;
                spans.push(own);

                if (oStck.len() > 0) {
                    oStck[oStck.len() - 1].children.push(spans.len() - 1);
                }
            }
        } else {
            switch ATOM_CHR: (input[i]) {
                case ' ':
                case '\n':
                case '\t':
                case '\r':
                case '#':
                    break ATOM_CHR;
                default:
                    Span atom_span = { .fst = i, .snd = 0, .section = depth, .w_off = -1 };
                    bool is_str = false;
                    while STEP_ATOM: (i < input.len) {
                        switch (input[i]) {
                            case ' ':
                            case '\n':
                            case '\t':
                            case '\r':
                                if (is_str) {
                                    i++;
                                } else {
                                    nextcase;
                                }
                            case ')':
                            case '(':
                                if (!is_str) {
                                    i--;
                                    atom_span.snd = i;
                                    spans.push(atom_span);
                                    if (oStck.len() > 0) {
                                        oStck[oStck.len() - 1].children.push(spans.len() - 1);
                                    }
                                    break STEP_ATOM;
                                } else {
                                    i++;
                                }
                            case '\"':
                                if (!is_str) {
                                    is_str = true;
                                    // i++ above --> trim quotes from string
                                    // i++ below --> keep quotes in string
                                    // i++;
                                    atom_span.fst = i;
                                    i++;
                                } else {
                                    // i-1 --> trim quotes from string
                                    // i   --> keep quotes in string
                                    // atom_span.snd = i-1;
                                    atom_span.snd = i;
                                    spans.push(atom_span);
                                    if (oStck.len() > 0) {
                                        oStck[oStck.len() - 1].children.push(spans.len() - 1);
                                    }
                                    // i++;
                                    break STEP_ATOM;
                                }
                            default:
                                i++;
                        }
                    }
                // case '0':
                // case '1':
                // case '2':
                // case '3':
                // case '4':
                // case '5':
                // case '6':
                // case '7':
                // case '8':
                // case '9':
                //     break;
                // case '@':
                //     break;
            }
        }
    }
    return spans;
}

fn bool is_instruction(String chunk) {
    switch(true) {
        case String.starts_with(chunk, "LDF"):
        case String.starts_with(chunk, "LDC"):
        case String.starts_with(chunk, "LD"):
        case String.starts_with(chunk, "NIL"):
        case String.starts_with(chunk, "SEL"):
        case String.starts_with(chunk, "JOIN"):
        case String.starts_with(chunk, "AP"):
        case String.starts_with(chunk, "RET"):
        case String.starts_with(chunk, "DUM"):
        case String.starts_with(chunk, "RAP"):
        case String.starts_with(chunk, "SYSC"):
        case String.starts_with(chunk, "ADD"):
        case String.starts_with(chunk, "MUL"):
        case String.starts_with(chunk, "DIV"):
        case String.starts_with(chunk, "SUB"):
        case String.starts_with(chunk, "MOD"):
        case String.starts_with(chunk, "CAR"):
        case String.starts_with(chunk, "CDR"):
        case String.starts_with(chunk, "CONS"):
        case String.starts_with(chunk, "EQ"):
        case String.starts_with(chunk, "ATOM"):
        case String.starts_with(chunk, "STOP"):
            return true;
        default:
            return false;
    }
}

fn TokenType? num_type(String chunk) {
    if (string::char_in_set('.', chunk) || string::char_in_set('e', chunk)) {
        // real number
        if (catch cause = String.to_double(chunk)) {
            return INVALID_TOKEN~;
        } else {
            return FLOAT_TOK;
        }
    } else {
        // integer
        if (catch cause = String.to_long(chunk)) {
            return INVALID_TOKEN~;
        } else {
            return INT_TOK;
        }
    }
}

fn TokenType? data_type(String chunk) {
    switch (chunk[0]) {
        case '(':
            return LIST_START;
        case '\"':
            return QUOTE;
        case '@':
            return REF;
        case '\'':
            return ATOM;
        case '+':
        case '-':
        case '0' .. '9':
            return num_type(chunk);
        default:
            if (is_instruction(chunk)) {
                return INSTR;
            } 
            // else if (label_mode) {
            //     return LABEL;
            // }
            else {
                io::printfn("Could not understand: %s", chunk);
                return INVALID_TOKEN~;
            }
    }
}

// input    -> the complete user input
// curspan  -> reference to the span of input currently being evaluated
// labels   -> reference to a hashmap of label names to the position of their data on disk
// span_pos -> reference to a list of size: number of spans, where the i'th element holds
//    the position of the i'th span on disk
// fn TokenType span_type(String input, Span* curspan, HashMap{String, usz}* labels, List{sz}* span_pos) {
//     // if we are processing this, it means that either it has no sub-expressions,
//     // or that they have already been processed
//     // further, there can be exactly two ways this can look:
//     // #(symName (data))
//     // (instruction [args])
//     // 
//     // in both cases, we have already written sub-expressions, and thus we know their 
//     //  locations on disk
//
//     String span_txt = input[curspan.fst .. curspan.snd];
//
//     @pool() {
//         // label
//         if (span_txt[0] == '#') {
//             String internal = input[curspan.fst+2 .. curspan.snd-1];
//             String[] chunks = String.tsplit(internal, " ", internal.len, true);
//         }
//
//         // regular list
//         else if (span_txt[0] == '(') {
//             String internal = input[curspan.fst+1 .. curspan.snd-1];
//             String[] chunks = String.tsplit(internal, " ", internal.len, true);
//
//             // code list
//             if (is_instruction(chunks[0])) {
//             }
//             // data list
//             else {
//                 TokenType? tok = data_type(chunk);
//             }
//         }
//     };
//     return LIST_START;
// }

fn TokenType? span_type(String input, Span* curspan, HashMap{String, Span*}* labels) {
    // if we are processing this, it means that either it has no sub-expressions,
    // or that they have already been processed
    // further, there can be exactly two ways this can look:
    // #(symName (data))
    // (instruction [args])
    // 
    // in both cases, we have already written sub-expressions, and thus we know their 
    //  locations on disk
    String span_txt = input[curspan.fst .. curspan.snd];

    if (span_txt[0] == '#' && curspan.is_list) {
        return LABEL;
    }
    else if (curspan.is_list) {
        return LIST_START;
    }


    // reference to label
    if (span_txt[0] == '@') {
        if (labels.has_key(span_txt[1..])) {
            return REF;
        } else {
            io::printfn("Invalid token: %s", span_txt);
            return INVALID_TOKEN~;
        }
    } 
    // some other kind of token
    else {
        return data_type(span_txt);
    }
}

// need to process labels BEFORE handling everything else
// pass 0
// fn void? process_labels_pass(String input, List{Span}* spans, HashMap{String, usz}* labels, List{CodeData}* code) {
fn void? process_labels_pass(String input, List{Span}* spans, HashMap{String, Span*}* labels, List{CodeData}* code) {
    List{usz} label_stack;
    List{Span} label_spans;
    List{Span*} spans_stck;
    List{SpanPair} entry_stck;
    label_mode = true;

    usz len = spans.len();
    for LOOP_LABELS: (usz i = 0; i < len; i++) {
        Span* curspan = spans.get_ref(i);
        if (! curspan.is_list) {
            continue LOOP_LABELS;
        }
        TokenType typeof_span = span_type(input, curspan, labels)!;
        if (typeof_span == LABEL) {
            // recursively push stuff into the label spans for later processing
            if (curspan.children.len() != 2) {
                io::printfn("Trying to process label with %d children", curspan.children.len());
                return INCONS_STATE~;
            }
            Span* name_span = spans.get_ref(curspan.children[0]);
            Span* data_span = spans.get_ref(curspan.children[1]);
            Span* iter = data_span;
            name_span.ignore = true;
            curspan.ignore = true;
            String name = input[name_span.fst .. name_span.snd];
            if (labels.set(name, data_span)) {
                io::printfn("WARNING: redefinition of label %s", name);
            }
            // name_span.ignore = true;
            curspan.children.pop_first()!;
            // add data into stack to process later, so that these can be written before the rest of the data
            label_stack.push(curspan.children[0]);
            spans_stck.push(iter);
            while (spans_stck.len() > 0) {
                iter = spans_stck.last()!;
                if (iter.children.len() > 0 && !(iter.ignore)) {
                    foreach (idx : iter.children) {
                        Span* ch = spans.get_ref(idx);
                        spans_stck.push(ch);
                    }
                    iter.ignore = true;
                } else {
                    spans_stck.pop()!;
                    iter.w_off = label_spans.len();

                    Span pp = { 
                        .fst = iter.fst, 
                        .snd = iter.snd, 
                        .section = iter.section,
                        .w_off = -1,
                        .is_list = iter.is_list,
                        .ignore = false};

                    if (iter.children.len() > 0) {
                        foreach (idx : iter.children) {
                            Span* at_idx = spans.get_ref(idx);
                            pp.children.push((usz)at_idx.w_off);
                        }
                    }

                    label_spans.push(pp);

                    // if the stack has been emptied, we're back to the 
                    // entry point of the label, so we need to update the 
                    // write offset of the span in the actual symbol table
                    // so that when we reference the label later, it points to
                    // the correct location in code
                    if (spans_stck.len() == 0) {
                        Span* w_on = label_spans.get_ref(iter.w_off);
                        entry_stck.push((SpanPair){ .real = iter, .copied = w_on });
                    }
                }
            }
        }
    }
    write_constant_data_pass(input, &label_spans, labels, code)!;
    normalize_lists_pass(input, &label_spans, labels, code)!;
    
    foreach (sp : entry_stck) {
        sp.real.w_off = sp.copied.w_off;
    }

    label_mode = false;
}

// pass 1
fn void? write_constant_data_pass(String input, List{Span}* spans, HashMap{String, Span*}* labels, List{CodeData}* code) {
    usz len = spans.len();
    // io::printn("Entering constant data pass phase...");

    List{usz} stck;
    List{int} can_write;

    // scan spans, and initialize stack with isolated sections
    // in reverse order, so that the definition section gets processed 
    // first --> labels are accessible at compilation time of main body
    //
    // set every index in can_print to -1
    //  -1 --> not printed, not allowed to print
    //  0  --> not printed, allowed to print
    //  1  --> printed, not allowed to print
    for (sz i = len - 1; i >= 0; i--) {
        can_print.push(-1);
        if (spans[i].section == 0) {
            stck.push(i);
        }
    }

    for LOOP_CONST_SPANS: (usz i = 0; i < len; i++) {
        Span* curspan = spans.get_ref(i);
        if (curspan.w_off >= 0) {
            continue LOOP_CONST_SPANS;
        }
        if (curspan.ignore) {
            // io::printfn("Ignoring span %s", input[curspan.fst .. curspan.snd]);
            continue LOOP_CONST_SPANS;
        }

        TokenType typeof_span = span_type(input, curspan, labels)!;
        CodeData code_dat = { .tt = typeof_span };

        switch (typeof_span) {
            case LIST_START:
                if (curspan.children.len() > 0) {
                    continue LOOP_CONST_SPANS;
                } else {
                    code_dat.tt = NIL_TOK;
                }
            case LABEL:
                // we have already processed labels, so we ignore them here
                continue LOOP_CONST_SPANS;
            case QUOTE:
                code_dat.str = input[curspan.fst+1 .. curspan.snd-1];
            case INSTR:
                code_dat.str = input[curspan.fst .. curspan.snd];
            case INT_TOK:
                code_dat.iVal = String.to_long(input[curspan.fst .. curspan.snd])!;
            case FLOAT_TOK:
                code_dat.fVal = String.to_double(input[curspan.fst .. curspan.snd])!;
            case REF:
                Span*? ref_span = labels.get(input[curspan.fst+1 .. curspan.snd]);
                if (catch ref_err = ref_span) {
                    return UNDEF_REF~;
                } else if (ref_span.w_off < 0) {
                    return INCONS_STATE~;
                } else {
                    code_dat.str = input[curspan.fst+1 .. curspan.snd];
                    code_dat.arg1 = ref_span.w_off;
                }
            case ATOM:
                // hash this string later, might be useful before finally commiting it
                code_dat.str = input[curspan.fst+1 .. curspan.snd];
            default:
                io::printfn("Got invalid token: %s", typeof_span.name);
                return INVALID_TOKEN~;
        }
        usz write_ind = code.len();
        code.push(code_dat);
        curspan.w_off = (sz)write_ind;
    }
    // io::printn("Finished constant data pass phase...");
}

// pass 2
// dispatch on whether sub-list is a instruction or data list
// list of data -> save as a list
// list where first element is an instruction -> ensure arguments are saved, then 
//      save list as instruction with arg fields set
// 
fn void? normalize_lists_pass(String input, List{Span}* spans, HashMap{String, Span*}* labels, List{CodeData}* code) {
    usz len = spans.len();
    // io::printn("Beginning list normalization pass...");

    for LOOP_LISTS: (usz i = 0; i < len; i++) {
        Span* curspan = spans.get_ref(i);

        if (curspan.is_list && curspan.children.len() > 0) {
            // skip over labels
            if (input[curspan.fst] == '#') {
                continue LOOP_LISTS;
            }
            usz fst_loc = curspan.children.get(0);
            Span* fst_child = spans.get_ref(fst_loc);
            if (fst_child.w_off < 0) {
                if (fst_child.ignore) {
                    continue LOOP_LISTS;
                } else {
                    io::printfn("Hit first incons from %s", input[fst_child.fst .. fst_child.snd]);
                    return INCONS_STATE~;
                }
            } 
            CodeData* fst_code = code.get_ref(fst_child.w_off);
            // if (fst_child.is_list) {}
            if (fst_child.is_list || fst_code.tt != INSTR) {
                // data list
                CodeData list_code = { .tt = LIST_START };
                usz span_len = curspan.children.len();

                Span* c_span = spans.get_ref(curspan.children[0]);
                sz ind = 1;

                // store first item in list in arg1 of list marker
                list_code.arg1 = c_span.w_off;
                // store length of the list in arg2 of list marker
                list_code.arg2 = span_len;

                while (ind < span_len) {
                    // if not at the last element
                    if (ind < span_len) {
                        // get span of next item in list
                        Span* next = spans.get_ref(curspan.children[ind]);
                        // retrieve code data of current item in list
                        CodeData* c_code = code.get_ref(c_span.w_off);
                        // save the write-offset of the next item as the "next" field of the current item
                        c_code.next = next.w_off;
                        // update pointer for next item
                        c_span = next;
                    }
                    // leave the next field blank for the last element, as this will point to the NIL
                    //  at index 0 in the code
                    // else {}
                    ind++;
                }
                curspan.w_off = code.len();
                code.push(list_code);
            }
            else if (fst_code.tt == INSTR) {
                // treat current list as having same write offset as instruction
                curspan.w_off = fst_child.w_off;
                // an instruction will have a max of 2 arguments
                switch (curspan.children.len()) {
                    case 1:
                        // instruction has no arguments
                        continue LOOP_LISTS;
                    case 2:
                        Span* c_one = spans.get_ref(curspan.children[1]);
                        fst_code.arg1 = c_one.w_off;
                    case 3:
                        Span* c_one = spans.get_ref(curspan.children[1]);
                        Span* c_two = spans.get_ref(curspan.children[2]);
                        fst_code.arg1 = c_one.w_off;
                        fst_code.arg2 = c_two.w_off;
                    default:
                        return EXCESSIVE_ARGS~;
                }
            } else {
                io::printfn("Hit some mysterious other state....");
                return INCONS_STATE~;
            }
        } else {
            continue LOOP_LISTS;
        }
    }
    // io::printn("Beginning list normalization pass...");
}

fn void? print_code(HashMap{String, Span*}* labels, List{CodeData}* code) {
    usz len = code.len();
    String[] label_keys = labels.keys(tmem);
    defer free(label_keys);

    for (usz j = 0; j < label_keys.len; j++) {
        Span* l_span = labels.get(label_keys[j])!;
        CodeData* acode = code.get_ref(l_span.w_off);
        io::printfn("Label %05d:\t [%s]=(Type: %s, At: %d)", j, label_keys[j], acode.tt.name, l_span.w_off);
    }
    io::printf("\n\n\n");

    for (usz i = 0; i < len; i++) {
        CodeData* acode = code.get_ref(i);
        io::printf("Code %05d:\t [%s]=(", i, acode.tt.name);
        switch (acode.tt) {
            case LIST_START:
                io::printf("First item = %d, Length = %d), ", acode.arg1, acode.arg2);
            case QUOTE:
                io::printf("%s), ", acode.str);
            case INSTR:
                io::printf("%s, Arg1: %d, Arg2: %d), ", acode.str, acode.arg1, acode.arg2);
            case INT_TOK:
                io::printf("%d), ", acode.iVal);
            case FLOAT_TOK:
                io::printf("%f), ", acode.fVal);
            case REF:
                io::printf("Symbol: %s, Code: %d), ", acode.str, acode.arg1);
            case LABEL:
                io::printf("???), ");
            case ATOM:
                io::printf("Symbol: %s), ", acode.str);
            case NIL_TOK:
                io::printf("NIL), ");
        }
        io::printfn("Next: %d", acode.next);
    }
}

// pass 2a
// all instructions are s-expressions, so the lists that contain that should be treated
// as being written to the same location as the instruction that they wrap
//
// this must happen WITH the data list pass, because lists of data will have their
//  own write offset, and 

// fn void? collapse_instr_list_pass(String input, List{Span}* spans, HashMap{String, usz}* labels, List{CodeData}* code) {
//     usz len = spans.len();
//
//     for LOOP_INSTR_LISTS: (usz i = 0; i < len; i++) {
//         Span* curspan = spans.get_ref(i);
//
//         if (curspan.is_list && curspan.children.len() > 0) {
//             usz fst_loc = curspan.children.get(0);
//             Span* fst_child = spans.get_ref(fst_loc);
//             if (fst_child.w_off < 0) {
//                 return INCONS_STATE~;
//             }
//             CodeData* fst_code = code.get_ref(fst_child.w_off);
//             if (fst_code.tt == INSTR) {
//                 curspan.w_off = fst_child.w_off;
//             } else {
//                 // data list
//                 continue LOOP_INSTR_LISTS;
//             }
//         } else {
//             continue LOOP_INSTR_LISTS;
//         }
//     }
// }
//
// // pass 2b
// // all lists that wrap other lists or wrap data (symbols, strings, numbers, etc)
// // should actually be written to code
// fn void? write_data_lists_pass(String input, List{Span}* spans, HashMap{String, usz}* labels, List{CodeData}* code) {
//     usz len = spans.len();
//
//     for LOOP_DATA_LISTS: (usz i = 0; i < len; i++) {
//         Span* curspan = spans.get_ref(i);
//
//         if (curspan.is_list && curspan.children.len() > 0) {
//             usz fst_loc = curspan.children.get(0);
//             Span* fst_child = spans.get_ref(fst_loc);
//             if (fst_child.w_off < 0) {
//                 return INCONS_STATE~;
//             }
//             CodeData* fst_code = code.get_ref(fst_child.w_off);
//             if (fst_code.tt == INSTR) {
//                 curspan.w_off = fst_child.w_off;
//             } else {
//                 // data list
//                 continue LOOP_DATA_LISTS;
//             }
//         } else {
//             continue LOOP_DATA_LISTS;
//         }
//     }
// }

// fn void process_spans(List{Span} spans, String input) {
//     List{CodeData} codes;
//     HashMap{String, sz} labels;
//
//     codes.init(mem);
//     labels.init(mem);
//
//     usz length = spans.len();
//     // int i = (int)(length - 1);
//     List{sz} stck;
//     List{int} can_print;
//
//     // scan spans, and initialize stack with isolated sections
//     // in reverse order, so that the definition section gets processed 
//     // first --> labels are accessible at compilation time of main body
//     //
//     // set every index in can_print to -1
//     //  -1 --> not printed, not allowed to print
//     //  0  --> not printed, allowed to print
//     //  1  --> printed, not allowed to print
//     for (sz i = length - 1; i >= 0; i--) {
//         can_print.push(-1);
//         if (spans[i].section == 0) {
//             stck.push(i);
//         }
//     }
//     assert(can_print.len() == spans.len());
//
//     while(stck.len() > 0) {
//         // get last thing on stack
//         sz? ind = stck.last();
//         if (catch reason = ind) {
//             io::printf("Nothing on the stack while we expected it");
//             break;
//         }
//         // if it has children, and they haven't been printed yet, then 
//         // add those children to the stack
//         if (spans[ind].children.len() > 0 && can_print[ind] < 0) {
//             foreach (cid : spans[ind].children) {
//                 stck.push(cid);
//             }
//             can_print[ind] = 0;
//         } else if (spans[ind].children.len() == 1 && can_print[ind] == 0) {
//             // replace list with single child
//             Span* single = spans.get_ref(ind);
//             if (is_instruction(input[single.fst .. single.snd])) {
//             }
//         } else if (can_print[ind] != 1) {
//             // if the current span has no children, it will fail on the previous
//             // condition, and fall through to here.
//             // in this case, we don't need to print anything else first, and so we can 
//             // print immediately
//             //
//             // otherwise, if this is a span with children and it's marked as available to
//             // print (it would be caught by the previous condition otherwise), then we 
//             // should print
//             String span_str = input[spans[ind].fst .. spans[ind].snd];
//             // if (input[spans[ind].fst] == '#') {
//             //     span_str = input[spans[ind].fst+2 .. spans[ind].snd-1];
//             // }
//             // else {
//             //     span_str = input[spans[ind].fst+1 .. spans[ind].snd-1];
//             // }
//             if (spans[ind].is_list) {
//                 io::printfn("list %3d:\t%s", ind, span_str);
//             } else {
//                 io::printfn("data %3d:\t%s", ind, span_str);
//             }
//             can_print[ind] = 1;
//             ulong? varname = stck.pop();
//         } else {
//             ulong? varname = stck.pop();
//         }
//     }
// }

fn void print_recurse(String input, List{Span} spans) {
    usz length = spans.len();
    // int i = (int)(length - 1);
    List{usz} stck;
    List{int} can_print;

    // scan spans, and initialize stack with isolated sections
    // in reverse order, so that the definition section gets processed 
    // first --> labels are accessible at compilation time of main body
    //
    // set every index in can_print to -1
    //  -1 --> not printed, not allowed to print
    //  0  --> not printed, allowed to print
    //  1  --> printed, not allowed to print
    for (sz i = length - 1; i >= 0; i--) {
        can_print.push(-1);
        if (spans[i].section == 0) {
            stck.push(i);
        }
    }
    assert(can_print.len() == spans.len());
    
    // stck.push(length - 1);
    // stck.push(0);

    while (stck.len() > 0) {
        // get last thing on stack
        usz? ind = stck.last();
        if (catch reason = ind) {
            io::printf("Nothing on the stack while we expected it");
            break;
        }
        // if it has children, and they haven't been printed yet, then 
        // add those children to the stack
        if (spans[ind].children.len() > 0 && can_print[ind] < 0) {
            foreach (cid : spans[ind].children) {
                stck.push(cid);
            }
            can_print[ind] = 0;
        } else if (can_print[ind] != 1) {
            // if the current span has no children, it will fail on the previous
            // condition, and fall through to here.
            // in this case, we don't need to print anything else first, and so we can 
            // print immediately
            //
            // otherwise, if this is a span with children and it's marked as available to
            // print (it would be caught by the previous condition otherwise), then we 
            // should print
            String span_str = input[spans[ind].fst .. spans[ind].snd];
            // if (input[spans[ind].fst] == '#') {
            //     span_str = input[spans[ind].fst+2 .. spans[ind].snd-1];
            // }
            // else {
            //     span_str = input[spans[ind].fst+1 .. spans[ind].snd-1];
            // }
            if (spans[ind].is_list) {
                io::printfn("list %3d:\t%s", ind, span_str);
            } else {
                io::printfn("data %3d:\t%s", ind, span_str);
            }
            can_print[ind] = 1;
            ulong? varname = stck.pop();
        } else {
            ulong? varname = stck.pop();
        }
    }
}

fn void main(String[] args) {
    String input = "(#(A 37) #(B ((LDC 4)))) ((LDC 33) (LDF ((LD (1 2)) (LDC @A) (MUL) (RET))) (AP) (LDF @B) (AP))";
    // String input = "(#(A 37) #(B ((LDC 4)))) ((LDC 37) (LDF ((LD (1 2)) (LDC 3) (MUL) (RET))) (AP))";
    // String input = "((LDC 37) (LDC \"big chungus\") (LDF ((LD (1 2)) (LDC 3) (MUL) (RET))) (AP))";
    List{Span} myspans = scan_parens(input);
    HashMap{String, usz} labels_inds;
    HashMap{String, Span*} labels;
    labels.init(mem);
    List{CodeData} code;
    code.push((CodeData) { .tt = NIL_TOK });
    code.init(mem);

    io::printf("Processing input: \'%s\'\n\n\n", input);
    
    if (catch reason = process_labels_pass(input, &myspans, &labels, &code)) {
        io::printfn("Processing labels pass failed with exit code: %s", reason);
        return;
    }

    if (catch reason = write_constant_data_pass(input, &myspans, &labels, &code)) {
        io::printfn("Constant data pass failed with exit code: %s", reason);
        return;
    }

    if (catch reason = normalize_lists_pass(input, &myspans, &labels, &code)) {
        io::printfn("List normalization pass failed with exit code: %s", reason);
        return;
    }

    if (catch reason = print_code(&labels, &code)) {
        io::printfn("Printing code failed with exit code: %s", reason);
        return;
    }
    
    // print_recurse(input, myspans);
}
