# Copyright (c) 1998 Cygnus Support
#
# The authors hereby grant permission to use, copy, modify, distribute,
# and license this software and its documentation for any purpose, provided
# that existing copyright notices are retained in all copies and that this
# notice is included verbatim in any distributions. No written agreement,
# license, or royalty fee is required for any of the authorized uses.
# Modifications to this software may be copyrighted by their authors
# and need not follow the licensing terms described here, provided that
# the new terms are clearly indicated on the first page of each file where
# they apply.

SHELL =	/bin/bash

prefix?=/opt/riscv
bin_prefix=${prefix}/bin
target_triplet=riscv32-unknown-elf
lib_prefix?=${prefix}/${target_triplet}/lib
tools_prefix=${bin_prefix}/${target_triplet}

# Defining riscv tools
CC      = ${tools_prefix}-gcc
AS      = ${tools_prefix}-as
AR      = ${tools_prefix}-ar
LD      = ${tools_prefix}-ld
RANLIB  = ${tools_prefix}-ranlib
OBJDUMP = ${tools_prefix}-objdump
OBJCOPY = ${tools_prefix}-objcopy

# object files needed
OBJS = chown.o close.o environ.o errno.o execve.o fork.o fstat.o \
	getpid.o gettod.o isatty.o kill.o link.o lseek.o open.o \
	read.o readlink.o sbrk.o stat.o symlink.o times.o unlink.o \
	wait.o write.o _exit.o gettimeofday.o

# Object files specific to particular targets.
EVALOBJS = ${OBJS}

CFLAGS = -g
BSP    = libnosys_trireme32.a

OUTPUTS = $(BSP)

.PHONY: all
all: ${OUTPUTS}

${BSP}: $(EVALOBJS)
	${AR} ${ARFLAGS} $@ $(EVALOBJS)
	${RANLIB} $@

clean mostlyclean:
	rm -f $(OUTPUTS) *.i *~ *.o *-test *.srec *.dis *.map *.x

.PHONY: install 
install:
	cp ${BSP} ${lib_prefix}
