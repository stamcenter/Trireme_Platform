#include <_ansi.h>
#include <_syslist.h>
#include <errno.h>
#include <unistd.h>

#undef errno
extern int errno;

extern void* UART_TX_PORT;

int
_write(int file, char *ptr, int len) {
    char *print_port = (char *) UART_TX_PORT;
    if (file == STDOUT_FILENO || file == STDERR_FILENO) {
        for (int i = 0; i < len; i++)
            *print_port = ptr[i];
        return len;
    } else {
        errno = EBADF;
        return -1;
    }
}

