module tiny_vm::io;

import std::io;
import std::collections::list;
import std::collections::linkedlist;
import std::collections::map;
import std::core::mem::allocator;
import std::io::file;


macro char[] @to_bytes($Type, #value) {
    char[] bytes = (char[$Type::size]*)&#value;
    return bytes;
}
