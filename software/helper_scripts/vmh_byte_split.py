#!/usr/bin/env python3

#==========================================================================
#   @module : vmh-byte-split.py
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
#==========================================================================

# This script reads a .vmh file and splits it into separtate vmh files. One vmh
# file is created for each byte in a memory word. Output files will have the
# file name and an appended number representing thier byte index. This script is
# useful for generating memory initialization files for byte-enabled BRAMs that
# have separate BRAMS for each byte under the hood.
#
# Example:
# ./vmh-byte-split.py file.vmh
#
# Assuming file.vmh is made up of 32-bit (4byte) words, the program will write:
# 0file.vmh, 1file.vmh, 2file.vmh, 3file.vmh, where the prefixed number is the
# index of the byte for each word.


import sys

file_name = sys.argv[1]
bytes_per_word = 4

with open(file_name) as f:
    lines = f.readlines()

vmh_bytes = [[] for i in range(bytes_per_word)]

for l in lines:
    # lines that start with "@" are addresses, put in every file
    if l[0] == '@':
        for i in range(bytes_per_word):
            # First line should remain the same
            vmh_bytes[i].append(l)

    else:

        line_word = l.split(' ');
        for word in line_word:
            for i in range(bytes_per_word-1, -1,-1):
                new_byte = word[0:2]
                new_byte += " "
                vmh_bytes[i].append(new_byte)
                word = word[2:]

        for i in range(bytes_per_word-1, -1,-1):
            vmh_bytes[i].append("\n")



base_file_name = file_name.split(".vmh")[0]

for i in range(bytes_per_word):
    name = str(i)+base_file_name+".vmh"
    with open(name, 'w') as f:
        f.writelines(vmh_bytes[i])


