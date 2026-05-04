module tiny_vm::parse;

// import tiny_vm::opers;

import std::io;
import std::collections::list;
import std::collections::linkedlist;
import std::core::mem::allocator;

faultdef ARRAY_OVERFLOW;
faultdef INVALID_TOKEN;
faultdef NO_TAG;

enum TokenType : char {
    LPAREN,
    RPAREN,
    QUOTE,
    INSTR,
    INT_TOK,
    FLOAT_TOK,
    REF,
    DEFDATA,
    DEFCONST,
    LABEL,
}

struct Pair
{
    usz fst; 
    usz snd;
}

struct Span {
    usz fst;
    usz snd;
    List{usz} children;
}

fn List{Span} scan_parens(String input) {
    List{Span} oStck;
    List{Span} spans;

    for (usz i = 0; i < input.len; i++) {
        if (input[i] == '(') {
            Span open = { .fst = i, .snd = 0 };
            oStck.push(open);
        } else if (input[i] == ')') {
            Span? own = oStck.pop();
            if (catch reason = own) {
                io::printfn("Nothing in open paren stack");
                break;
            } else {
                own.snd = i;
                spans.push(own);

                if (oStck.len() > 0) {
                    oStck[oStck.len() - 1].children.push(spans.len() - 1);
                }
            }
        }
    }
    return spans;
}

fn void print_recurse(String input, List{Span} spans) {
    usz length = spans.len();
    // int i = (int)(length - 1);
    List{usz} stck;
    List{bool} can_print;

    for (usz i = 0; i < length; i++) {
        can_print.push(false);
    }
    
    stck.push(length - 1);

    while (stck.len() > 0) {
        // get last thing on stack
        usz? ind = stck.last();
        if (catch reason = ind) {
            io::printf("Nothing on the stack while we expected it");
            break;
        }
        // if it has children, and they haven't been printed yet, then 
        // add those children to the stack
        if (spans[ind].children.len() > 0 && ! can_print[ind]) {
            foreach (cid : spans[ind].children) {
                stck.push(cid);
            }
            can_print[ind] = true;
        } else {
            String span_str = input[spans[ind].fst .. spans[ind].snd];
            io::printfn("span %d:\t%s", ind, span_str);
            ulong? varname = stck.pop();
        }
    }
}

fn void main(String[] args) {
    String input = "((LDC 37) (LDF ((LD (1 2)) (LDC 3) (MUL) (RET))) (AP))";
    List{Span} myspans = scan_parens(input);
    print_recurse(input, myspans);

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
