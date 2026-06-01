module tiny_vm::io;

import std::collections::list;
import std::collections::linkedlist;
import std::collections::map;
import std::core::mem::allocator;
import libc;


extern fn CInt vm_open(char*, CInt);
extern fn sz vm_write(CInt, void*, usz);
extern fn sz vm_read(CInt, void*, usz);
extern fn CInt vm_close(CInt);
extern fn long vm_seek_set(CInt, usz);
extern fn long vm_seek_cur(CInt, sz);
extern fn long vm_seek_end(CInt, sz);

constdef OpenOpt 
{
    RDONLY = 0,
    WRONLY = 1,
    RDWR   = 2,
    CREAT  = 64,
    TRUNC  = 512,
    APPEND = 1024,
}

enum SeekWhence {
    SEEK_CUR,
    SEEK_SET,
    SEEK_END,
}

typedef Fd = inline CInt;

faultdef 
    FAIL_OPEN,
    FAIL_WRITE,
    FAIL_READ,
    FAIL_CLOSE,
    FAIL_SEEK;

fn Fd? open(String filename, OpenOpt flags) {
    ZString file_zstr = filename.zstr_tcopy();
    CInt fd = vm_open(file_zstr, (CInt)flags);
    if (fd < 0) {
        return FAIL_OPEN~;
    }
    return (Fd)fd;
}

fn usz? write(Fd fd, any data) {
    sz res_sz = vm_write((CInt)fd, data.ptr, data.type.size);
    if (res_sz < 0) {
        return FAIL_WRITE~;
    }
    return (usz)res_sz;
}

fn usz? read(Fd fd, any buffer) {
    sz res_sz = vm_read((CInt)fd, buffer.ptr, buffer.type.size);
    if (res_sz < 0) {
        return FAIL_READ~;
    }
    return (usz)res_sz;
}

fn void? close(Fd fd) {
    CInt res = vm_close((CInt)fd);
    if (res < 0) {
        return FAIL_CLOSE~;
    }
}

fn usz? seek(Fd fd, sz off, SeekWhence seek_whence) {
    long res;
    switch (seek_whence) {
        case SEEK_CUR:
            res = vm_seek_cur((CInt)fd, off);
        case SEEK_SET:
            res = vm_seek_set((CInt)fd, (usz)off);
        case SEEK_END:
            res = vm_seek_end((CInt)fd, off);
    }
    if (res < 0) {
        return FAIL_SEEK~;
    }
    return (usz)res;
}
