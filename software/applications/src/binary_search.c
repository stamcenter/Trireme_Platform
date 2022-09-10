/*=================================================================================
 # binary_search.c
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


//Binary Search Algorithm.
 int binary_search(int *data, int item, int start, int end)
 {
    int mid = start + (end - start)/2;
    if (start > end)
       return -1;
    else if (data[mid] == item)
       return mid;
    else if (data[mid] > item)
       return binary_search(data, item, start, mid-1);
    else
       return binary_search(data, item, mid+1, end);
 }

 int search(int *data, int item, int count)
 {
    return binary_search(data, item, 0, count-1);
 }

 int sort(int *data, int count)
 {
   int i, j, temp;
	for(i = 0; i < count-1; i++) {
		for(j = 0; j < count-i-1; j++){
		  if (data[j+1] < data[j]){
			temp = data[j];
			data[j] = data[j+1];
			data[j+1] = temp;
		  }
		}
	}
 }

 int main(void)
 {
	int n[8] = {0, 6, 8, 4, 3, 9, 7, 5};
	int answer;

  sort(n, 8);
	answer = search(n, 8, 8);
    return answer;
 }
