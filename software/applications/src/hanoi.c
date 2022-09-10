/*=================================================================================
 # hanoi.c
  # Author: Secure, Trusted, and Assured Microelectronics (STAM) Center

 #  Copyright (c) 2022 Trireme (STAM/SCAI/ASU)
 #  Permission is hereby granted, free of charge, to any person obtaining a copy
 #  of this software and associated documentation files (the "Software"), to deal
 #  in the Software without restriction, including without limitation the rights
 #  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 #  copies of the Software, and to permit persons to whom the Software is
 #  furnished to do so, subject to the following conditions:
 #  The above copyright notice and this permission notice shall be included in
 #  all copies or substantial portions of the Software.
 
 #  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 #  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 #  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 #  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 #  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 #  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 #  THE SOFTWARE.
 ==================================================================================*/

int Hanoi(int n,int src,int aux,int dest)
 {
	int moves = 0;
    if(n == 1)
        moves = 1;
    else{
        moves += Hanoi(n-1,src,dest,aux);
        moves += Hanoi(1,src,aux,dest);
        moves += Hanoi(n-1,aux,src,dest);
    }
	return moves;
 }

 int main(void)
 {
    int src,aux,dest;
    int n, answer;

    src= 1;
    aux= 2;
    dest=3;

    n = 4;
	answer = Hanoi(n,src,aux,dest);
    return answer;
 }
