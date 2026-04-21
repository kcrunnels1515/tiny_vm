module tiny_vm::parser;

import tiny_vm::opers;

import std::io;
import std::collections::list;
import std::collections::linkedlist;
import std::core::mem::allocator;
import std::libc::libc;

faultdef ARRAY_OVERFLOW;
faultdef INVALID_TOKEN;

enum TokenType : char {
    LPAREN,
    RPAREN,
    QUOTE,
    INSTR,
    INT_TOK,
    FLOAT_TOK
}

struct Token {
    TokenType type;
    Data dat;
    usz idx;
}

fn Token? new_tok(TokenType tt, String str, usz start) {
    Token tok;
    tok.type = tt;
    tok.idx = start;
    
    switch (tt) {
        case LPAREN:
            if (str.len == 1 && str[0] == '(') {
                tok.dat = (Data){ .list = List{Data}.init(mem), .tag = LIST };
                return tok;
            } else {
                return INVALID_TOKEN~;
            }
        case RPAREN:
            if (str.len == 1 && str[0] == ')') {
                tok.dat = (Data){ .tag = NIL };
                return tok;
            } else {
                return INVALID_TOKEN~;
            }
        case QUOTE:
            if (str.len >= 2 && str[0] == '\"' && str[str.len-1] == '\"') {
                String str_data = str[1 .. str.len - 1];
                tok.dat = ofValue(ofStr(str_data));
                return tok;
            } else {
                return INVALID_TOKEN~;
            }
        case INSTR:
            Oper opCode;
            switch (str) {
				case "NIL":
                    opCode = NIL;
                    break;
				case "LD":
                    opCode = LD;
                    break;
				case "LDC":
                    opCode = LDC;
                    break;
				case "LDF":
                    opCode = LDF;
                    break;
				case "SEL":
                    opCode = SEL;
                    break;
				case "JOIN":
                    opCode = JOIN;
                    break;
				case "AP":
                    opCode = AP;
                    break;
				case "RET":
                    opCode = RET;
                    break;
				case "DUM":
                    opCode = DUM;
                    break;
				case "RAP":
                    opCode = RAP;
                    break;
				default:
                    return INVALID_TOKEN~;
            }
            tok.dat = opers::ofOper(opCode);
            return tok;
        case INT_TOK:
            int iVal = str.to_int();
            tok.dat = opers::ofValue(ofInt(iVal));
            return tok;
        case FLOAT_TOK:
            float fVal = str.to_float();
            tok.dat = opers::ofValue(ofFloat(fVal));
            return tok;
    }
}

struct Context {
    usz idx;
    usz len;
    char[*] str_buf;
}

fn char? Context.get(Context* ctx, usz ind) {
    if (ind + ctx.idx >= ctx.str_buf.len) {
        return ctx.str_buf[ind + ctx.idx];
    } else {
        return ARRAY_OVERFLOW~;
    }
}

fn char? Context.peek(Context* ctx) {
    if (ctx.idx < ctx.str_buf.len) {
        return ctx.str_buf[ctx.idx];
    } else {
        return ARRAY_OVERFLOW~;
    }
}

fn char? Context.peekNext(Context* ctx) {
    if (ctx.idx + 1 < ctx.str_buf.len) {
        return ctx.str_buf[ctx.idx + 1];
    } else {
        return ARRAY_OVERFLOW~;
    }
}

fn void Context.skip(Context* ctx) {
    ctx.len = 0;
}

fn void Context.advance(Context* ctx) {
    ctx.len++;
    ctx.idx++;
}

fn bool Context.hasOffset(Context* ctx, usz offset) {
    return ctx.idx + offset < ctx.str_buf.len;
}

fn Token Context.emit(Context* ctx, TokenType tt) {
    usz start = ctx.idx - ctx.len;
    Context.skip(ctx);
    
    return new_tok(tt, ctx.str_buf[start .. ctx.idx], start);
}

fn List{Token}? process_tokens(String input) {
    List{Token} tok_list = List{Token}.init(mem);
    Context ctx = { .idx = 0, .len = 0, .str_buf = input.copy(mem) };
    while LEX_LOOP: (true) {
        char? nextChar = ctx.peek();
        if (catch excuse = nextChar) {
            break LEX_LOOP;
        }
        switch (ctx.peek())  {
            case '\n':
            case '\t':
            case ' ':
                ctx.skip();
            case '\"':
                ctx.advance();
                while (ctx.peek() != '\"') {
                    ctx.advance();
                }
                Token tok = ctx.emit(QUOTE);
                tok_list.push(tok);
            case '(':
                ctx.advance();
                Token tok = ctx.emit(LPAREN);
                tok_list.push(tok);
            case ')':
                ctx.advance();
                Token tok = ctx.emit(RPAREN);
                tok_list.push(tok);
			case 'N':
			case 'L':
			case 'S':
			case 'J':
			case 'A':
			case 'R':
			case 'D':
                ctx.advance();
                char? nextChar = ctx.peek();
                if (catch excuse = nextChar) {
                    break LEX_LOOP;
                }
                while (next != ' ' && next != '\n' && next != '\t') {
                    ctx.advance();
                    next = ctx.peek();
                }
                Token tok = ctx.emit(INSTR);
                tok_list.push(tok);
            case '+':
            case '-':
			case '0':
			case '1':
			case '2':
			case '3':
			case '4':
			case '6':
			case '7':
			case '8':
			case '9':
                bool is_float = false;
                bool cont = true;
                while NUM_LOOP: (true) {
                    ctx.advance();
                    switch (ctx.peek()) {
						case '0':
						case '1':
						case '2':
						case '3':
						case '4':
						case '6':
						case '7':
						case '8':
						case '9':
						    ctx.advance();
                        case 'e':
                            char? next = ctx.peek();
                            if (catch excuse = nextChar) {
                                break LEX_LOOP;
                            }
                            if (next == '+' || next == '-') {
                                is_float = true;
						        ctx.advance();
                            } else {
                                return INVALID_TOKEN~;
                            }
                        case '.':
                            char? next = ctx.peek();
                            if (catch excuse = nextChar) {
                                break LEX_LOOP;
                            }
                            if (next >= '0' && next <= '9') {
                                is_float = true;
						        ctx.advance();
                            } else {
                                return INVALID_TOKEN~;
                            }
						case '\n':
						case '\t':
						case ' ':
                            if (is_float) {
                                Token tok = ctx.emit(FLOAT_TOK);
                                tok_list.push(tok);
                            } else {
                                Token tok = ctx.emit(INT_TOK);
                                tok_list.push(tok);
                            }
                            break NUM_LOOP;
                    }
                }
        }
    }
    return tok_list;
}

fn List{Data}? parse(String input) {
    List{Data} new_ctrl = List{Data}.init(mem);
    List{Data*} list_stack = List{Data*}.init(mem);
    List{Token} tokens = process_tokens(input);

    Data* top_level = malloc(Data.sizeof);
    top_level.list = List{Data}.init(mem);
    top_level.tag = LIST;
    list_stack.push(top_level);
    
    for(int i = 0; i < tokens.len; i++)
    {   
        Token* tok = tokens[i];
        TokenType tt = tok.type;
        switch (tt) {
			case LPAREN:
                new_ctrl.push(tok.dat);
                list_stack.push(&(tok.dat));
			case RPAREN:
                Data* last_list = list_stack.pop();
			case QUOTE:
			case INT_TOK:
			case FLOAT_TOK:
			case INSTR:
                new_ctrl.push(tok.dat);
        }
    }
    
    return new_ctrl;
}
