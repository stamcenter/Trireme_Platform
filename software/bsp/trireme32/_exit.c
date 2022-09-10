#include <_ansi.h>
#include <_syslist.h>

void
_exit (int rc)
{
  /* Convince GCC that this function never returns.  */
  for (;;)
    ;
}
