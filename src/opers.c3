module tiny_vm::opers;

import std::io;
import std::core::mem::allocator;
import std::collections::list;
import std::collections::linkedlist;


enum ValueTag {
    FLOAT,
    INT,
    STR,
    NIL,
    OPER,
    LIST
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
        Oper oper;
        Value val;
        List{Data} list;
    }
    ValueTag tag;
}

fn Data ofValue(Value value) {
    return (Data){ .val = value, .tag = value.tag };
}

fn Data ofOper(Oper op) {
    return (Data){ .oper = op, .tag = OPER };
}

fn Data ofList(List{Data} lst) {
    return (Data){ .list = lst, .tag = LIST };
}

typedef Stack = inline List{Data};

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

enum Oper : char (Operation opFn)
{
    NIL     { &nilOper  },
    LD      { &ldOper   },
    LDC     { &ldcOper  },
    LDF     { &ldfOper  },
    SEL     { &selOper  },
    JOIN    { &joinOper },
    AP      { &apOper   },
    RET     { &retOper  },
    DUM     { &dumOper  },
    RAP     { &rapOper  },
}
