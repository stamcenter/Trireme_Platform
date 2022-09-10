/*=================================================================================
 # prime_number_counter.c
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

/*******************************************************************************
 * Description: Counts the number of prime numbers less than a given number.
*******************************************************************************/

#define NUM_CORES 4
#define WORDS_PER_LINE 4
#define LINE_WIDTH (WORDS_PER_LINE*4) //in Bytes

//placing locks on separate cache lines.
#define LOCK_0_1 0x00004000
#define DATA_0_1 (LOCK_0_1+LINE_WIDTH)
#define LOCK_0_2 (DATA_0_1+LINE_WIDTH)
#define DATA_0_2 (LOCK_0_2+LINE_WIDTH)
#define LOCK_0_3 (DATA_0_2+LINE_WIDTH)
#define DATA_0_3 (LOCK_0_3+LINE_WIDTH)

#define LOCK_1_0 (DATA_0_3+LINE_WIDTH)
#define DATA_1_0 (LOCK_1_0+LINE_WIDTH)

#define LOCK_2_0 (DATA_1_0+LINE_WIDTH)
#define DATA_2_0 (LOCK_2_0+LINE_WIDTH)

#define LOCK_3_0 (DATA_2_0+LINE_WIDTH)
#define DATA_3_0 (LOCK_3_0+LINE_WIDTH)


//functions
unsigned int multu(unsigned int a, unsigned int b) {
  unsigned int product;
  product = 0;

  for(int i=0; i<32; i++) {
    if(0x00000001 & (a>>i) ) {
      product = product + (b << i);
    }
  }
  return product;
}


int mult(int a, int b) {
  int product;
  int sign_a, sign_b;
  sign_a = a >> 31;
  sign_b = b >> 31;

  if(sign_a) a = (~a) + 1; // Flip sign
  if(sign_b) b = (~b) + 1; // Flip sign

  product = (signed int)multu( (unsigned int)a, (unsigned int)b );

  if( sign_a^sign_b ) product = (~product) + 1; // Flip sign;

  return product; 
}


int division(int a, int b) {
  int temp = 1;
  int quotient = 0;

  while (b <= a) {
    b <<= 1;
    temp <<= 1;
  }

  while (temp > 1) {
    b >>= 1;
    temp >>= 1;

    if (a >= b) {
      a -= b;
      quotient += temp;
    }
  }
  return quotient;
}


int getRemainder(int a, int b) {
  int temp = 1;

  while (b <= a) {
    b <<= 1;
    temp <<= 1;
  }

  while (temp > 1) {
    b >>= 1;
    temp >>= 1;

    if (a >= b) {
      a -= b;
    }
  }
  return a;
}


//square root
int floorSqrt(int x) 
{ 
  // Base cases 
  if (x == 0 || x == 1) 
  return x; 
  
  // Staring from 1, try all numbers until 
  // i*i is greater than or equal to x. 
  int i = 1, result = 1; 
  while (result <= x) 
  { 
    i++; 
    result = mult(i, i); 
  } 
  return i - 1; 
}


void delay(int n){
  int i = 0;
  while(i<n){
    i++;
  }
}


int check_prime(int a){
  int isPrime = 0;
  int sqrt = floorSqrt(a);
  int remainder = 0;

  if(a < 2){
    return 0;
  }
  else if(a == 2 || a == 3){
    return 1;
  }
  else{
    for(int i=2; i<=sqrt; i++){
      remainder = getRemainder(a, i);
      if(remainder == 0){
        return 0;
      }
    }
    return 1;
  }
}



int main(void){

int lower_bound = 0;
int upper_bound = 50; //counts prime numbers from 0 to 50.
int primes = 0;
int isPrime;

for(int i=lower_bound; i<=upper_bound; i++){
  isPrime = check_prime(i);
  if(isPrime){
    primes++;
  }
}


return primes; //returns 15 as the answer.


}










