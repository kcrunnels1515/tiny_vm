#include "./io.h"
#include <stdint.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/types.h>


int vm_open(const char * filename, int flags){
    return open(filename, flags, 0644);
}

ssize_t vm_write(int fd, void* bytes, size_t write_len){
    return write(fd, bytes, write_len);
}

ssize_t vm_read(int fd, void* buf, size_t read_len){
    return read(fd, buf, read_len);
}

int vm_close(int fd){
    return close(fd);
}

int64_t vm_seek_set(int fd, size_t offset){
    return (int64_t)lseek(fd, offset, SEEK_SET);
}

int64_t vm_seek_cur(int fd, ssize_t offset){
    return (int64_t)lseek(fd, offset, SEEK_CUR);
}

int64_t vm_seek_end(int fd, ssize_t offset){
    return (int64_t)lseek(fd, offset, SEEK_END);
}
