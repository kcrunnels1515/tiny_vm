module tiny_vm::serialize;

import std::io;
import std::collections::list;
import std::collections::linkedlist;
import std::collections::map;
import std::core::mem::allocator;
import std::io::file;
import libc;

import tiny_vm::parse;

macro char[] @to_bytes($Type, #value) {
    char[] bytes = (char[$Type::size]*)&#value;
    return bytes;
}

enum OpCode : char (String codename)
{
    // Core instructions
    // Arithmetic instructions
    // Comparison instructions
    // Other instructions
    // vectorizes a list
    // makes a system call, takes arguments as a list
    NIL   { "NIL"},
    LD    { "LD"},
    LDC   { "LDC"},
    LDF   { "LDF"},
    SEL   { "SEL"},
    JOIN  { "JOIN"},
    AP    { "AP"},
    RET   { "RET"},
    DUM   { "DUM"},
    RAP   { "RAP"},
    CAR   { "CAR"},
    CDR   { "CDR"},
    CONS  { "CONS"},
    ATOM  { "ATOM"},
    EQ    { "EQ"},
    STOP  { "STOP"},
    ADD   { "ADD"},
    SUB   { "SUB"},
    MUL   { "MUL"},
    DIV   { "DIV"},
    MOD   { "MOD"},
    LEQ   { "LEQ"},
    GEQ   { "GEQ"},
    LT    { "LT"},
    GT    { "GT"},
    VEC   { "VEC"},
    SYSC  { "SYSC"},
}

enum ValueTag : char
{
    NIL   = 0,
    INT   = 1,
    STR   = 2,
    FLOAT = 3,
    INSTR = 4,
    LIST  = 5,
    SYMB  = 6,
}

const CHUNKLEN = 15;

bitstruct Code : char[CHUNKLEN] @overlap
{
    // type of data stored in Code
    char type : 0..7;
    // instruction ID, if an instruction
    char op   : 8..15;
    // for values, so that instead of creating new values
    // when refering to them in stack/env/etc we can just refer
    // to the location where its defined and not create a new one
    // this is set to false for constant in the Control stack and 
    // new values created through operations on the stack, and false
    // for constant values placed on the stack during execution
    // 
    // bits 16 through 23 are flags on the code
    // bit 16: is code chunk a reference to an existing code element?
    bool ref   : 16;
    // bit 17: is this code chunk part of a vector data type?
    //      --> strings, vectors of atoms, etc
    // bool vec   : 17;
    // // bit 18: if this code chunk is part of a vector data type, this 
    // // marks the last element
    // bool term  : 18;

    // 4-byte indices of arguments for INSTR Codes, 
    // the first element of the string stores the length of the string
    // in bytes in arg1, and the length of the string in Codes in arg2.
    // then following Codes are cast to char arrays.
    sz  arg1 : 24..55;
    sz  arg2 : 56..87;

    // other is for storing integers and floats, so it overlaps
    // arg1 and arg2
    // if this is an ATOM (symbol value) this contains a hash of the string
    ulong other : 24..87;
    // index of next item in list containing data
    sz  next : 88..119;
}

/* FORMAT OF SERIALIZED FILE:
    - Header
    - String table
        - all strings in code will already know the offset and length
            of their corresponding string at the time they are written
    - Label table
        - pairs of (char[32], usz) indicate label name (for export), 
            and their indices
    - Code
    
*/
bitstruct Header : char[20] {
    // number of labeled code chunks
    uint labels  : 0..31;
    // offset of entry point, if it exists
    // value of -1 if this is a library (no entry point)
    sz entry     : 32..95;
    // number of labels
    uint l_len   : 96..127;
    // offset of label table
    uint l_tbl   : 128..159;
}

struct Label {
    String name;
    usz loc;
}

struct Serial {
    // WriteBuffer wb;
    File output;
    usz count;
    usz strs_len;
    usz labels_len;
    usz label_off;
}

fn Code data_to_code(CodeData* cd, usz off) {
    Code tw;
    switch (cd.tt) {
        case TokenType.LIST_START:
            tw.type = LIST;
        case TokenType.QUOTE:
            tw.type = STR;
        case TokenType.INSTR:
            tw.type = INSTR;
            tw.op = @enum_lookup(OpCode, "name", cd.str);
            tw.arg1 = cd.arg1 + off;
            tw.arg2 = cd.arg2 + off;
            tw.next = cd.next + off;
        case TokenType.INT_TOK:
            tw.type = INT;
            tw.other = cd.iVal;
            tw.next = cd.next + off;
        case TokenType.FLOAT_TOK:
            tw.type = FLOAT;
            tw.other = cd.fVal;
            tw.next = cd.next + off;
        case TokenType.REF:  
            assert(0 && "Unreachable");
        case TokenType.LABEL:
            assert(0 && "Unreachable");
        case TokenType.ATOM:
            tw.type = SYMB;
        case TokenType.NIL_TOK:
            tw.type = NIL;
    }
}

fn Serial*? Serial.init(&self, String output, char[] buf) {
    self.output = file::open(output, "w+")!;
    // self.wb.init(&(self.output), buf)!;
    self.count = 0;
    self.strs_len = 0;
    self.labels_len = 0;
    self.labels_off = 0;
    return self;
}

// return offset of data beginning
fn usz? Serial.write(&self, char[] data) {
    usz start = self.count;
    sz w = self.output.write(data)!;
    assert(w >= 0);
    self.count += w;
    return start;
}

fn void? Serial.write_header(&self, Header h) {
    self.output.seek(0)!;
    char[] bytes = @to_bytes(Header, h);
    self.output.write(bytes)!;
    // return to original position of writing
    self.output.seek(self.count)!;
}

fn void? Serial.write_strings(&self, StrTable strs) {
    usz len = strs.len();
    usz cur_count = self.count;
    for (usz i = 0; i < len; i++) {
        CodeData* c = strs.get(i);
        String str = c.str;
        c.arg1 = self.count;
        c.arg2 = str.len;
        sz str_len = self.output.write(str)!;
        self.count += (usz)str_len;
    }
    self.strs_len = (self.count - cur_count);
}

fn void? Serial.write_labels(&self, CodeMeta* code) {
    self.labels_off = self.count;

    HashMap{String, usz}.@each(code.labels; String name, usz loc) {
        char[32] name_buf = { 0 };
        libc::memcpy(&name_buf, &name, name.len);
        char[] loc_bytes = @to_bytes(usz, loc);
        sz nm_sz = self.output.write(&name_buf)!;
        sz loc_sz = self.output.write(loc_bytes)!;
        self.count += (usz)(nm_sz + loc_sz);
        self.labels_len += 1;
    }
}

fn void? Serial.write_code(&self, CodeMeta* code) {
    usz len = code.code.len();

    for (usz i = 0; i < len; i++) {
        CodeData* c = code.code.get_ref(i);
    }
}

typedef StrTable = inline List{CodeData*};

fn void? StrTable.save(&self, Serial* wb) {
    usz len = self.len();
    for (usz i = 0; i < len; i++) {
        CodeData* c = self.get(i);
        String str = c.str;
    }
}

fn StrTable build_string_table(CodeMeta code) {
    usz len = code.code.len();
    StrTable strs;
    strs.init();

    for (usz i = 0; i < len; i++) {
        CodeData* c_dat = code.code.get_ref(i);
        if (c_dat.tt == QUOTE) {
            strs.push(c_dat);
        }
    }
    return strs;
}


