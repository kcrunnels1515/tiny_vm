module tiny_vm::vm_state;

import std::io;
import std::collections::list;
import std::collections::linkedlist;
import std::collections::map;
import std::core::mem::allocator;
import std::io::file;
import std::hash::md5;
import libc;

import tiny_vm::serialize;

/*
*  Reg structs represent the state of a particular register, while Manager structs 
*    directly manage the underlying implementation of the registers
*  We pass a StackReg struct around to represent the state of the stack currently,
*    so that where the frame/stack pointers are is kept track of, but we push/pop
*    from the stack via the StackManager, which actually handles resizing the stack
*
* The Reg structs must keep an offset instead of a pointer, because resizing arrays
*  could cause some pointers to be invalid
*
*
*/

faultdef 
    FAIL_POP_STACK,
    STACK_UNDERFLOW;

struct Closure {
    usz fn_off;
    usz env_off;
    usz env_len;
}

struct VMState {
    CodeReg c_reg;
    StackReg s_reg;
    EnvReg e_reg;
}

struct CodeReg {
    usz offset;
    sz ip;
}

struct CodeManager {
    Code* c_ptr;
    CodeReg cur;
    usz len;
}

struct StackReg {
    usz offset;
    List{usz} closures;
    usz len;
}

struct StackManager {
    Code* s_ptr;
    StackReg cur;
    usz len;
    usz cap;
}

struct EnvEntry {
    Code* e_buf;
    usz len;
    bool dummy;
}

struct EnvReg {
    usz offset;
    usz len;
}

struct EnvManager {
    EnvEntry* e_ptr;
    EnvReg cur;
    usz len;
    usz cap;
}

struct Dump {
    List{VMState} states;
}

fn StackManager* StackManager.init(&self) {
    self.s_ptr = mem::malloc(256 * Code::size);
    self.s_ptr[0] = serialize::nil_val();
    self.len = 1;
    self.cap = 256;
    self.cur = { .offset = 0, .len = self.len };
    return self;
}

fn void StackManager.expand_data(&self) {
    usz new_cap = self.cap+256;
    self.s_ptr = mem::realloc(self.s_ptr, new_cap);
    self.cap = new_cap;
}

macro StackManager.@expand(&self) {
    if (self.len > self.cap - 8) {
        self.expand_data();
    }
}

// return offset of pushed data
fn usz StackManager.push_data(&self, Code* code) {
    usz off_res = -1;
    StackManager.@expand(self);
    self.s_ptr[self.len] = *code;
    off_res = self.len;
    self.len++;
    self.cur.len++;
    return off_res;
}

fn usz StackManager.push_closure(&self, usz fn_offset, EnvReg cur_env) {
    StackManager.@expand(self);
    Code func = serialize::fn_val(fn_offset);
    Code env  = serialize::env_val(cur_env.offset, cur_env.len);
    Code closure;

    usz env_off = self.push_data(&env);
    func.next = env_off;
    usz func_off = self.push_data(&func);
    closure = serialize::list_val(func_off, 2);
    usz res_off = self.push_data(&closure);
    return res_off;
}

fn Code? StackManager.pop_data(&self) {
    Code res;
    if (self.cur.len == 0) {
        return FAIL_POP_STACK~;
    }
    self.len--;
    self.cur.len--;
    res = self.s_ptr[self.cur.len];
    return res;
}

// returns old stack frame
fn StackReg StackManager.new_frame(&self) {
    StackReg old = self.cur;
    self.@expand();

    self.s_ptr[self.len] = serialize::nil_val();
    self.cur = { .offset = self.len, .len = 1 };
    self.len++;

    return old;
}

fn StackReg? StackManager.restore_frame(&self, StackReg reg) {
    StackReg old_reg = self.cur;

    if (self.cur.offset == 0) {
        return STACK_UNDERFLOW~;
    }
    self.cur = reg;
    return old_reg;
}

fn void StackManager.destroy(&self) {
    mem::free(self.s_ptr);
}

// @TODO
// should probably take as arguments
// - envmanager
// - codemanager
// - dumpmanager
fn Code? StackManager.pop_closure(&self) {
    Code res;
    if (self.cur.len == 0) {
        return FAIL_POP_STACK~;
    }
    self.len--;
    self.cur.len--;
    res = self.s_ptr[self.cur.len];
    return res;
}

fn void StackManager.print(&self) {
    io::printfn("TODO");
}

// we assume that we are given the pointer to the beginning of the code,
// not the initial pointer to the beginning of the file, and we are also 
// given the offset of the entry point
fn CodeManager* CodeManager.init(&self, Code* input_data, sz entry, usz len) {
    self.c_ptr = input_data;
    self.len = len;
    self.cur = { .offset = 0, .ip = entry };
    return self;
}

fn CodeReg CodeManager.set_ip(&self, CodeReg c_reg) {
    CodeReg res = self.cur;
    self.cur = c_reg;
    return res;
}

fn Code CodeManager.read_instr(&self) {
    Code cur_instr = self.c_ptr[self.cur.ip];
    self.cur.ip = cur_instr.next;
    return cur_instr;
}


// fn void CodeManager.set_ip(&self, usz off) {
//     self.cur.ip = off;
// }

/*
*
* Environment Managemant
*
*/

fn EnvEntry* EnvEntry.init(&self, usz envsize, bool is_dummy = false) {
    self.dummy = is_dummy;
    if (!is_dummy) {
        self.len = envsize;
        self.e_buf = mem::malloc(envsize * Code::size);
    } else {
        self.len = 0;
        self.e_buf = null;
    }
    return self;
}

fn void EnvEntry.replace(&self, usz envsize, Code* c_ptr) {
    if (self.e_buf != null) {
        mem::free(self.e_buf);
    }
    self.dummy = false;
    self.len = envsize;
    self.e_buf = mem::malloc(envsize * Code::size);
    libc::memcpy(self.e_buf, c_ptr, envsize * Code::size);
}

fn EnvManager* EnvManager.init(&self) {
    self.e_ptr = mem::malloc(16 * EnvEntry::size);
    self.cap = 16;
    self.len = 0;
    self.dummy_env();
    self.cur = { .offset = 0, .len = 0 };
    return self;
}

fn void EnvManager.resize(&self) {
    if (self.len < self.cap) { return; }
    
    sz new_sz = (self.cap * EnvEntry::size) + (16 * EnvEntry::size);
    self.e_ptr = mem::realloc(self.e_ptr, new_sz);
    self.cap = (usz)new_sz;
}

fn void EnvManager.dummy_env(&self) {
    self.resize();
    self.e_ptr[self.len].init(envsize: 0, is_dummy: true);
    self.cur = { .offset = self.len, .len = 0 };
    self.len++;
}

fn void EnvManager.new_env(&self, StackManager stck_reg) { }

fn EnvReg EnvManager.restore_env(&self, EnvReg env_reg) {
    EnvReg res = self.cur;
    self.cur = env_reg;
    return res;
}

/*
    Dump manager code
*/

fn Dump* Dump.init(&self, Allocator a = mem) {
    self.states.init(a);
    return self;
}

fn void Dump.push(&self, CodeManager* c, StackManager* s, EnvManager* e) {
    VMState st = { .c_reg = c.cur, .s_reg = s.cur, .e_reg = e.cur };
    self.states.push(st);
}

fn VMState? Dump.pop(&self, CodeManager* c, StackManager* s, EnvManager* e) {
    VMState st = self.states.pop()!;
    VMState res_st;
    res_st.s_reg = s.restore_frame(st.s_reg)!;
    res_st.e_reg = e.restore_env(st.e_reg);
    res_st.c_reg = c.set_ip(st.c_reg);
    return res_st;
}
