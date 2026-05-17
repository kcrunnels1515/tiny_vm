module tiny_vm::parse;

// import tiny_vm::opers;

import std::io;
import std::collections::list;
import std::collections::linkedlist;
import std::collections::map;
import std::core::mem::allocator;

faultdef 
    ARRAY_OVERFLOW,
    INVALID_TOKEN,
    INCONS_STATE,
    NO_TAG;

enum TokenType : char {
    LIST_START,
    QUOTE,
    INSTR,
    INT_TOK,
    FLOAT_TOK,
    REF,
    LABEL,
    ATOM,
    NIL_TOK,
}

struct Pair
{
    usz fst; 
    usz snd;
}

struct Span {
    usz fst;
    usz snd;
    int section;
    isz w_off;
    bool is_list;
    List{usz} children;
}

struct CodeData {
    TokenType tt;
    // bool initialized;
    union {
        String str;
        long iVal;
        double fVal;
    }
    isz arg1;
    isz arg2;
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
            } else {
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

fn TokenType? span_type(String input, Span* curspan, HashMap{String, usz}* labels) {
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
fn void? process_labels_pass(String input, List{Span}* spans, HashMap{String, usz}* labels, List{CodeData}* code) {}

// pass 1
fn void? write_constant_data_pass(String input, List{Span}* spans, HashMap{String, usz}* labels, List{CodeData}* code) {
    usz len = spans.len();

    for LOOP_CONST_SPANS: (usz i = 0; i < len; i++) {
        Span* curspan = spans.get_ref(i)!;

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
                // @TODO: need to add stuff for this
                continue LOOP_CONST_SPANS;
            case QUOTE:
                code_dat.str = input[curspan.fst+1 .. curspan.snd-1];
            case INSTR:
                code_dat.str = input[curspan.fst .. curspan.snd];
            case INT_TOK:
                code_dat.iVal = string::to_long(input[curspan.fst .. curspan.snd])!;
            case FLOAT_TOK:
                code_dat.fVal = string::to_double(input[curspan.fst .. curspan.snd])!;
            case REF:
                usz refd_ind = labels.get(input[curspan.fst+1 .. curspan.snd])!;
                code_dat.arg1 = (isz)refd_ind;
            case ATOM:
                // hash this string later, might be useful before finally commiting it
                code_dat.str = input[curspan.fst+1 .. curspan.snd];
        }
        usz write_ind = code.len();
        code.push(code_dat);
        curspan.w_off = (isz)write_ind;
    }
}

// pass 2a
// all instructions are s-expressions, so the lists that contain that should be treated
// as being written to the same location as the instruction that they wrap
//
// this must happen WITH the data list pass, because lists of data will have their
//  own write offset, and 

fn void? collapse_instr_list_pass(String input, List{Span}* spans, HashMap{String, usz}* labels, List{CodeData}* code) {
    usz len = spans.len();

    for LOOP_INSTR_LISTS: (usz i = 0; i < len; i++) {
        Span* curspan = spans.get_ref(i)!;

        if (curspan.is_list && curspan.children.len() > 0) {
            usz fst_loc = curspan.children.get(0)!;
            Span* fst_child = spans.get_ref(fst_loc);
            if (fst_child.w_off < 0) {
                return INCONS_STATE~;
            }
            CodeData* fst_code = code.get_ref(fst_child.w_off)!;
            if (fst_code.tt == INSTR) {
                curspan.w_off = fst_child.w_off;
            } else {
                // data list
                continue LOOP_INSTR_LISTS;
            }
        } else {
            continue LOOP_INSTR_LISTS;
        }
    }
}

// pass 2b
// all lists that wrap other lists or wrap data (symbols, strings, numbers, etc)
// should actually be written to code
fn void? write_data_lists_pass(String input, List{Span}* spans, HashMap{String, usz}* labels, List{CodeData}* code) {
    usz len = spans.len();

    for LOOP_DATA_LISTS: (usz i = 0; i < len; i++) {
        Span* curspan = spans.get_ref(i)!;

        if (curspan.is_list && curspan.children.len() > 0) {
            usz fst_loc = curspan.children.get(0)!;
            Span* fst_child = spans.get_ref(fst_loc);
            if (fst_child.w_off < 0) {
                return INCONS_STATE~;
            }
            CodeData* fst_code = code.get_ref(fst_child.w_off)!;
            if (fst_code.tt == INSTR) {
                curspan.w_off = fst_child.w_off;
            } else {
                // data list
                continue LOOP_DATA_LISTS;
            }
        } else {
            continue LOOP_DATA_LISTS;
        }
    }
}

fn void process_spans(List{Span} spans, String input) {
    List{CodeData} codes;
    HashMap{String, isz} labels;

    codes.init(mem);
    labels.init(mem);

    usz length = spans.len();
    // int i = (int)(length - 1);
    List{sz} stck;
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

    while(stck.len() > 0) {
        // get last thing on stack
        sz? ind = stck.last();
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
        } else if (spans[ind].children.len() == 1 && can_print[ind] == 0) {
            // replace list with single child
            Span* single = spans.get_ref(ind);
            if (is_instruction(input[single.fst .. single.snd])) {
            }
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
    // String input = "(#(A 37) #(B ((LDC 4)))) ((LDC 37) (LDF ((LD (1 2)) (LDC 3) (MUL) (RET))) (AP))";
    String input = "((LDC 37) (LDC \"big chungus\") (LDF ((LD (1 2)) (LDC 3) (MUL) (RET))) (AP))";
    List{Span} myspans = scan_parens(input);
    print_recurse(input, myspans);
    
    // String test_pref = "LDC 5";
    // String[] chunks = String.tsplit(test_pref, " ", test_pref.len, true);
    // for (int i = 0; i < chunks.len; i++) {
    //     bool isInstr = is_instruction(chunks[i]);
    //     if (isInstr) {
    //         io::printfn("Instruction %d: %s", i+1, chunks[i]);
    //     } else {
    //         io::printfn("Non-instruction %d: %s", i+1, chunks[i]);
    //     }
    // }

    // usz length = myspans.len();
    // int i = (int)(length - 1);
    //
    // while (i >= 0) {
    //     Span myspan = myspans[i];
    //     String span_str = input[myspan.fst .. myspan.snd];
    //     io::printfn("span %d:\t%s", i, span_str);
    //     if (myspan.children.len() > 0) {
    //         io::printf("\tChildren: ");
    //         foreach (cid : myspan.children) {
    //             io::printf("%d ", cid);
    //         }
    //         io::printf("\n");
    //     }
    //     i--;
    //     // i++;
    // }
}

// fn void main(String[] args) {
//     String input = "(LDC 37) (LDF ((LD (1 2)) (LDC 3) (MUL) (RET))) (AP)";
//     List{Pair} myspans = scan_parens(input);
//     usz length = myspans.len();
//     // int i = (int)(length - 1);
//     int i = 0;
//     while (i < (int)length) {
//         String span = input[myspans[i].fst .. myspans[i].snd];
//         io::printfn("span %d\t(%d, %d):\t%s", i, myspans[i].fst, myspans[i].snd, span);
//         // i--;
//         i++;
//     }
// }
