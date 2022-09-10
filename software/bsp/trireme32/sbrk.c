/* Version of sbrk for no operating system.  */

#include <errno.h>
#include <_syslist.h>
#undef errno
extern int errno;

void *
_sbrk (int incr)
{
   extern char   end; /* Set by linker.  */
   extern char   stack_end; /* Set by linker. */
   static char * heap_end = 0; 
   char *        prev_heap_end = 0;

   if (heap_end == 0)
     heap_end = &end;
   // check if user is asking for a sane break value
   if ((heap_end + incr) > &stack_end) {
	   errno = ENOMEM;
	   return (void *) -1;
   }  
   if ((heap_end + incr) < &end) {
	   errno = EINVAL;
	   return (void *) -1;
   }
   prev_heap_end = heap_end;
   heap_end += incr;
   return (void *) prev_heap_end;
}
