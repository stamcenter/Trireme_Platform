#!/usr/bin/env python3


#   @module : pad_binary.py
#   @author : Secure, Trusted, and Assured Microelectronics (STAM) Center
#
#   Copyright (c) 2022 Trireme (STAM/SCAI/ASU)
#   Permission is hereby granted, free of charge, to any person obtaining a copy
#   of this software and associated documentation files (the "Software"), to deal
#   in the Software without restriction, including without limitation the rights
#   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#   copies of the Software, and to permit persons to whom the Software is
#   furnished to do so, subject to the following conditions:
#   The above copyright notice and this permission notice shall be included in
#   all copies or substantial portions of the Software.

#   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
#   THE SOFTWARE.
#


# A python script to append zeros to a binary image so it can be uploaded with
# the UART + bootloader program.
#
# The first argument is the binary name. The second argument is the size of the
# file (in bytes) after pading. Remember that the bootloader or bootwait program
# will take up space too, meaning the binary should not be padded to whe full
# size of the memory. Currently the booloader starts writing the loaded program
# at address 0x300 (768) of the local memory. For a 4096 byte memory, the
# program should be padded to 3328 bytes.
#
# Example Usage:
# ./pad_binary gcd 3556

import sys

bin_file = sys.argv[1]
size     = int(sys.argv[2])

with open(bin_file, mode='rb') as f:
    file_content = f.read();

file_len = len(file_content)
len_diff = size-file_len
pad = "\0"*len_diff
file_content += pad.encode('utf-8')

with open(bin_file, mode='wb') as f:
    f.write(file_content);

