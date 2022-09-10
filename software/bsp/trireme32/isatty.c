#include <_ansi.h>
#include <_syslist.h>
#include <errno.h>
#include <unistd.h>
#undef errno
extern int errno;

int
_isatty (int file)
{
    if (file == STDOUT_FILENO || file == STDERR_FILENO)
        return 1;
    else {
        errno = EBADF;
        return -1;
    }
}

