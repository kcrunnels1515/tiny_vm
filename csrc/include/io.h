#ifndef IO_H_
#define IO_H_
#include <sys/types.h>
#include <stdint.h>

typedef enum {
    RDONLY = O_RDONLY,
    WRONLY = O_WRONLY,
    RDWR   = O_RDWR,
    APPEND = O_APPEND,
    CREAT  = O_CREAT,
    TRUNC  = O_TRUNC,
} OpenOpt;

int vm_open(const char * filename, int flags);
ssize_t vm_write(int fd, void* bytes, size_t write_len);
ssize_t vm_read(int fd, void* buf, size_t read_len);
int vm_close(int fd);
int64_t vm_seek_set(int fd, size_t offset);
int64_t vm_seek_cur(int fd, ssize_t offset);
int64_t vm_seek_end(int fd, ssize_t offset);

#endif
