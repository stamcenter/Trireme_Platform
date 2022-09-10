#include <sys/time.h>
#include <errno.h>
#undef errno

extern int errno;

int 
gettimeofday (struct timeval *__restrict __p,
	       void *__restrict __tz)
{
	errno = ENOSYS; // not implemented yet
	return -1;
}
