module tiny_vm::opers;

import std::io;
import std::core::mem::allocator;
import std::collections::list;
import std::collections::linkedlist;

faultdef INVALID_INSTR;
faultdef INVALID_DATA;

enum OpCode : char
{
    NIL  = 0,
    LD   = 1,
    LDC  = 2,
    LDF  = 3,
    SEL  = 4,
    JOIN = 5,
    AP   = 6,
    RET  = 7,
    DUM  = 8,
    RAP  = 9,
    PUTC = 10,
    GETC = 11,
    SYSC = 12,
}

enum ValueTag : char
{
    NIL = 0,
    INT = 1,
    STR = 2,
    FLOAT = 3,
    OPER = 4,
    LIST = 5,
}

bitstruct Code : char[10] @overlap
{
    // type of data stored in Code
    char type : 0..2;
    // instruction ID, if an instruction
    char op   : 3..6;
    // for values, so that instead of creating new values
    // when refering to them in stack/env/etc we can just refer
    // to the location where its defined and not create a new one
    // this is set to false for constant in the Control stack and 
    // new values created through operations on the stack, and false
    // for constant values placed on the stack during execution
    bool ref  : 7;
    // 4-byte indices of arguments for INSTR Codes, 
    // the first element of the string stores the length of the string
    // in bytes in arg1, and the length of the string in Codes in arg2.
    // then following Codes are cast to char arrays.
    isz  arg1 : 8..39;
    isz  arg2 : 40..71;
    // other is for storing integers and floats, so it overlaps
    // arg1 and arg2
    ulong other : 8..71;
}

macro long intValue(#oper_bs) {
    return (long)#oper_bs.other;
}

macro double floatValue(#oper_bs) {
    double* fptr = (double*)(((char*)&#oper_bs) + 1);
    return *fptr;
}

fn Code[] stringValue(String str) {
    isz sLen = str.len;
    isz opLen = (sLen + 9) / 10;
    Code[] ops = mem::new_array(Code, opLen + 1);
    ops[0].type = STR;
    ops.arg1 = sLen;
    ops.arg2 = opLen;
    char* cArr = &ops[1];
    mem::copy(cArr, str, sLen);
    return ops;
}

fn String? getString(Code* ops) {
    if (ops[0].type != STR) {
        return INVALID_DATA~;
    }
    isz str_len = ops[0].arg1;
    isz op_len = ops[0].arg2;

    char[] newStr = mem::new_array(char, str_len);
    mem::copy(&ops[1], newStr, str_len);
    return (String)newStr;
}

macro Code makeInt(#oper_bs, #iVal) {
    Code oper_bs;
    oper_bs.type = INT;
    char* cptr = (char*)(&oper_bs);
    cptr++;
    long i = #iVal;
    mem::copy(cptr, &i, 8);
    return oper_bs;
}

macro Code makeFloat(#fVal) {
    Code oper_bs;
    oper_bs.type = FLOAT;
    char* cptr = (char*)(&oper_bs);
    cptr++;
    double f = #fVal;
    mem::copy(cptr, &f, 8);
    return oper_bs;
}

macro Code makeString(#strIdx) {
    Code oper_bs;
    oper_bs.type = STR;
    oper_bs.arg1 = #strIdx;
    return oper_bs;
}

macro Code makeInstr(#oper_bs, $opType) {
    Code opVal;
    opVal.type = OPER;
    opVal.op = $opType;
    return opVal;
}

struct Value {
    union {
        float f;
        int i;
        String str;
    }
    ValueTag tag;
}

fn Value ofStr(String str) {
    Value val = { .str = str.copy(mem), .tag = STR };
    return val;
}
fn Value ofInt(int iVal) {
    Value val = { .i = iVal, .tag = INT };
    return val;
}

fn Value ofFloat(float fVal) {
    Value val = { .f = fVal, .tag = FLOAT };
    return val;
}

fn Value ofNil() {
    return (Value){ .tag = NIL };
}

struct Data {
    union {
        Code oper;
        Value val;
        List{Data} list;
    }
    ValueTag tag;
}

fn Data ofValue(Value value) {
    return (Data){ .val = value, .tag = value.tag };
}

fn Data ofOper(Code op) {
    return (Data){ .oper = op, .tag = OPER };
}

fn Data ofList(List{Data} lst) {
    return (Data){ .list = lst, .tag = LIST };
}

struct Stack {
    Code* arr;
    isz len;
    isz cap;
    isz base;
}

fn Stack* Stack.init(&self) {
    self.arr = mem::malloc(256 * Code.sizeof);
    self.len = 0;
    self.cap = 256;
    self.base = 0;
}

fn void Stack.resize(&self) {
    isz frame_cap = self.cap - self.base;
    if ( frame_cap - self.len < 20) {
        // expand
        self.arr = mem::realloc(self.arr, self.cap + 256);
        self.cap = self.cap + 256;
    } else if ( frame_cap - self.len > 300 ) {
        // shrink
        self.arr = mem::realloc(self.arr, self.cap - 256);
        self.cap = self.cap - 256;
    }
}

// return location of last base
fn isz Stack.new_frame(&self) {
    isz old_base = self.base;
    self.base = self.len;
    self.len = 0;
    self.resize();
    return old_base;
}

fn void Stack.recall_frame(&self, isz old_base) {
    self.len = self.base;
    self.base = old_base;
    self.resize();
}

// fn void Stack.push_ref(&self, Oper* ops, isz index) {
// }

typedef Env = inline List{List{Data}};

struct Control {
    List{Data} data;
    List{usz} head;
}

fn Control* Control.init(&self, Allocator allocator = mem, List{Data}* copy_from = null) 
{
    if (copy_from != null) {
        self.data = copy_from;
    } else {
        self.data = List{Data}.init(allocator);
    }
    self.head = List{usz}.init(allocator);
    self.head.push(0);
    return self;
}

struct DumpElem {
    Control* ctrl;
    Stack* stck;
    Env* env;
}

typedef Dump = inline List{DumpElem};

struct Secd {
    Stack stck;
    Control ctrl;
    Dump dump;
    Env env;
}

fn Secd* Secd.init(&self, Allocator allocator = mem, List{Data}* copy_from = null) {
    self.stck = List{Data}.init(allocator);
    self.ctrl = Control.init(allocator, copy_from);
    self.dump = List{DumpElem}.init(allocator);
    self.env = List{List{Data}}.init(allocator);
    return self;
}

fn int Secd.run(&self) {
    Data* start = self.ctrl.getNext();
    assert(start.tag == OPER);
    return start.oper.opFN(0, &self.ctrl, &self.stck, &self.env, &self.dump);
}

alias Operation = fn int(usz ip, Control* ctrl, Stack* stck, Env* env, Dump* dmp);

fn Data* Control.getNext(&self) {
    usz idx = ctrl.head[0];
    Data* cur = ctrl.data.get_ref(idx);
    for (int i = 1; i < ctrl.head.len; i++) {
        assert(cur.tag == LIST);
        idx = ctrl.head[i];
        cur = cur.list.get_ref(idx);
    }
    ctrl.head[ctrl.head.len - 1] += 1;
    return cur;
}

fn int nilOper(usz ip, Control* ctrl, Stack* stck, Env* env, Dump* dmp) {
    Data nilVal = ofValue(ofNil());
    List.push(stck, nilVal);
    usz next_ip = ip+1;
    Data next = List.get(ctrl, next_ip);

    assert(next.tag == OPER);

    return next.oper.opFN(next_ip, ctrl, stck, env, dmp);
}

fn int ldOper(usz ip, Control* ctrl, Stack* stck, Env* env, Dump* dmp) {
    return 0;
}

fn int ldcOper(usz ip, Control* ctrl, Stack* stck, Env* env, Dump* dmp) {
    Data constVal = List.get(ctrl, ip+1);
    assert(next.tag != OPER && next.tag != LIST);
    List.push(stck, constVal);
    usz next_ip = ip+2;
    Data next = List.get(ctrl, next_ip);

    assert(next.tag == OPER);

    return next.oper.opFN(next_ip, ctrl, stck, env, dmp);
}

fn int ldfOper(usz ip, Control* ctrl, Stack* stck, Env* env, Dump* dmp) {
    Data funcVal = List.get(ctrl, ip+1);
    assert(next.tag == LIST);
    List.push(stck, funcVal);
    usz next_ip = ip+2;
    Data next = List.get(ctrl, next_ip);

    assert(next.tag == OPER);

    return next.oper.opFN(next_ip, ctrl, stck, env, dmp);
}

fn int selOper(usz ip, Control* ctrl, Stack* stck, Env* env, Dump* dmp) {
    Data nilVal = ofValue(ofNil());
    List.push(stck, nilVal);
    usz next_ip = ip+1;
    Data next = ctrl[next_ip];

    assert(next.tag == OPER);

    return next.oper.opFN(next_ip, ctrl, stck, env, dmp);
}

fn int joinOper(usz ip, Control* ctrl, Stack* stck, Env* env, Dump* dmp) {
    Data nilVal = ofValue(ofNil());
    List.push(stck, nilVal);
    usz next_ip = ip+1;
    Data next = ctrl[next_ip];

    assert(next.tag == OPER);

    return next.oper.opFN(next_ip, ctrl, stck, env, dmp);
}

fn int apOper(usz ip, Control* ctrl, Stack* stck, Env* env, Dump* dmp) {
    Data nilVal = ofValue(ofNil());
    List.push(stck, nilVal);
    usz next_ip = ip+1;
    Data next = ctrl[next_ip];

    assert(next.tag == OPER);

    return next.oper.opFN(next_ip, ctrl, stck, env, dmp);
}

fn int retOper(usz ip, Control* ctrl, Stack* stck, Env* env, Dump* dmp) {
    Data nilVal = ofValue(ofNil());
    List.push(stck, nilVal);
    usz next_ip = ip+1;
    Data next = ctrl[next_ip];

    assert(next.tag == OPER);

    return next.oper.opFN(next_ip, ctrl, stck, env, dmp);
}

fn int dumOper(usz ip, Control* ctrl, Stack* stck, Env* env, Dump* dmp) {
    Data nilVal = ofValue(ofNil());
    List.push(stck, nilVal);
    usz next_ip = ip+1;
    Data next = ctrl[next_ip];

    assert(next.tag == OPER);

    return next.oper.opFN(next_ip, ctrl, stck, env, dmp);
}

fn int rapOper(usz ip, Control* ctrl, Stack* stck, Env* env, Dump* dmp) {
    Data nilVal = ofValue(ofNil());
    List.push(stck, nilVal);
    usz next_ip = ip+1;
    Data next = ctrl[next_ip];

    assert(next.tag == OPER);

    return next.oper.opFN(next_ip, ctrl, stck, env, dmp);
}

Operation[10] opfns = {
    &nilOper,
    &ldOper,
    &ldcOper,
    &ldfOper,
    &selOper,
    &joinOper,
    &apOper,
    &retOper,
    &dumOper,
    &rapOper,
};

