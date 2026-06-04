module tiny_vm::vm;

import std::io;
import std::collections::list;
import std::collections::linkedlist;
import std::collections::map;
import std::core::mem::allocator;
import std::io::file;
import std::io::file_mmap;
import std::hash::md5;
import libc;

import tiny_vm::serialize;
import tiny_vm::vm_state;

faultdef
    NO_ENTRY;

struct SecdVM {
    char* data;

    StackManager stack;
    CodeManager  code;
    EnvManager   env;
    Dump         dump;
}

alias InstrFn = fn void?(SecdVM*, sz, sz);

fn SecdVM* SecdVM.init(&self, void* file_ptr, sz file_sz) {
    Header code_h = *((Header*) file_ptr);
    Code* code_d = (Code*)((char*)file_ptr + code_h.code_off);
    usz code_sz = (usz)(file_sz - code_h.code_off);
    sz entry = (code_h.entry < 0) ? -1 : code_h.entry - code_h.code_off;

    self.data = (char*)file_ptr;
    self.code.init(code_d, entry, code_sz);
    self.stach.init();
    self.env.init();
    self.dump.init();
    return self;
}

fn void? SecdVM.exec(&self) {
    if (self.code.cur.ip < 0) {
        return NO_ENTRY~;
    }
    Code instr = self.code.read_instr();
    InstrFn tocall = instrs[instr.op];
    tocall(self, instr.arg1, instr.arg2)!;
}

fn char[] read_string(SecdVM* secd, usz loc, usz len) {
    char[] str = secd.data[loc..(loc+len)];
    return str;
}


fn void? instr_nil(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_ld(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_ldc(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_ldf(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_sel(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_join(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_ap(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_ret(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_dum(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_rap(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_car(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_cdr(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_cons(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_atom(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_eq(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_stop(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_add(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_sub(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_mul(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_div(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_mod(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_leq(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_geq(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_lt(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_gt(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_vec(SecdVM* secd, sz arg1, sz arg2) {
}

fn void? instr_sysc(SecdVM* secd, sz arg1, sz arg2) {
}

InstrFn[] instrs = {
	&instr_nil,
	&instr_ld,
	&instr_ldc,
	&instr_ldf,
	&instr_sel,
	&instr_join,
	&instr_ap,
	&instr_ret,
	&instr_dum,
	&instr_rap,
	&instr_car,
	&instr_cdr,
	&instr_cons,
	&instr_atom,
	&instr_eq,
	&instr_stop
	&instr_add,
	&instr_sub,
	&instr_mul,
	&instr_div,
	&instr_mod,
	&instr_leq,
	&instr_geq,
	&instr_lt,
	&instr_gt,
	&instr_vec,
	&instr_sysc,
};

fn void main(String[] args) {
    SecdVM secd;

    if (args.len < 2) {
        io::printfn("Usage: %s <inputfile>", args[0]);
        return;
    }
    File? input = file::open(args[1], "r");
    if (catch reason = input) {
        io::printfn("Failed to open file: %s", reason);
        return;
    }

    FileMmap? mmaped = file_mmap::mmap_file(input);

    if (catch reason = mmaped) {
        io::printfn("Failed to mmap file: %s", reason);
        return;
    }

    secd.init(mmaped.ptr, mmaped.size);
    if (catch reason = self.exec()) {
        io::printfn("Execution error: %s", reason);
        return;
    }
}


