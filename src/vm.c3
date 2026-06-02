module tiny_vm::vm;

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
    FAIL_POP_STACK;

struct Closure {
    usz fn_off;
    usz env_off;
    usz env_len;
}

struct SecdVM {
    char* data;

    StackManager stack;
    CodeManager  code;
    EnvManager   env;
    Dump         dump;
}

struct VMState {
    CodeReg c_reg;
    StackReg s_reg;
    EnvReg e_reg;
}

struct CodeReg {
    usz offset;
    usz ip;
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
    EvReg cur;
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
        self.expand_data(self);
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

    usz env_off = self.push_data(env);
    func.next = env_off;
    usz func_off = self.push_data(func);
    closure = serialize::list_val(func_off, 2);
    usz res_off = self.push_data(closure);
    return off_res;
}

fn Code? StackManager.pop_data(&self) {
    Code res;
    if (self.cur.len == 0) {
        return FAIL_POP_DATA~;
    }
    self.len--;
    self.cur.len--;
    res = self.s_ptr[self.cur.len];
    return res;
}

// @TODO
// should probably take as arguments
// - envmanager
// - codemanager
// - dumpmanager
fn Code? StackManager.pop_closure(&self) {
    Code res;
    if (self.cur.len == 0) {
        return FAIL_POP_DATA~;
    }
    self.len--;
    self.cur.len--;
    res = self.s_ptr[self.cur.len];
    return res;
}

fn void StackManager.destroy(&self) {
    mem::free(self.s_ptr);
}

// we assume that we are given the pointer to the beginning of the code,
// not the initial pointer to the beginning of the file, and we are also 
// given the offset of the entry point
fn CodeManager* CodeManager.init(&self, char[] input_data, usz entry) {
    self.c_ptr = (Code*)input_data;
    self.len = input_data/parse::CHUNKLEN;
    self.cur = { .c_buf = self.c_ptr, .ip = entry };
    return self;
}

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

fn void EnvManager.new_env(&self, StackManager stck_reg) {
    
}
