/*=================================================================================
 # short_mandelbrot.c
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


//#define DESKTOP 1

//#define EXPECTED_CHECKSUM 0x731fd35a // max_iter = 255
//#define EXPECTED_CHECKSUM 0x342c66a0 // max_iter = 10
#define EXPECTED_CHECKSUM 0x0018ba60 // max_iter = 3, 8x8
//#define EXPECTED_CHECKSUM 0x00011ce6// max_iter = 1, 2x2
//#define EXPECTED_CHECKSUM 0x00016976 // max_iter = 2, 2x2
//#define EXPECTED_CHECKSUM 0x00000000 // wrong value to test fail condition
#define H_RES 8
#define V_RES 8

#define OUTPUT_FILE "short_mandelbrot.pbm"
#define WHITE 0
#define BLACK 1

#define DELTA 0x00000400 //  20 integer points, 12 binary points 0.25
#define FOUR 0x00004000
#define X_START 0xFFFFE04F // -1.9807...
#define Y_START 0x000011D0 // 1.125

#ifdef DESKTOP
#include <stdlib.h>
#include <stdio.h>
#endif /* DESKTOP */


struct complex_num {
    int re;
    int im;
};
typedef struct complex_num Complex_Num;

void complex_add(Complex_Num *a, Complex_Num *b, Complex_Num *s);
void complex_mult(Complex_Num *a, Complex_Num *b, Complex_Num *s);
void complex_square(Complex_Num *a, Complex_Num*sq);
void mandelbrot_iter(Complex_Num *Z, Complex_Num *C);
int complex_magnitude(Complex_Num *a);
int complex_magnitude(Complex_Num *a);
unsigned int multu(unsigned int a, unsigned int b);
int mult(int a, int b);

int main(void)
{
  // Mandelbrot variables
  int max_iter;
  unsigned int pixel_mag;
  unsigned int color;

  unsigned int checksum;

  //unsigned int *pixels = (void *)0x0000200;

  Complex_Num Zn;
  Complex_Num C;

  //max_iter = 255; // slow but will produce the mandelbrot set
  //max_iter = 10; // this is faster but does not look like the mandelbrot set
  max_iter = 3; // super short version for test version

  checksum = 0;

#ifdef DESKTOP
  FILE *output_file;
  output_file = fopen(OUTPUT_FILE, "w");
  fprintf(output_file, "P1\n%d %d\n", H_RES, V_RES);
#endif /* DESKTOP */

  C.im = Y_START;
  for( int i=0; i<V_RES; i++ ) {

    C.re = X_START;
    for( int j=0; j<H_RES; j++) {
      color = BLACK;
      Zn.re = 0;
      Zn.im = 0;

      for(int k=0; k<max_iter; k++) {
        mandelbrot_iter(&Zn, &C);
        pixel_mag = complex_magnitude(&Zn);
        checksum += pixel_mag;
        if(  pixel_mag > FOUR) {
          color = WHITE;
          break;
        }
      }



      C.re += DELTA;
      #ifdef DESKTOP
      printf("Pixel Magnitude: 0x%08x\n", pixel_mag);
      fprintf(output_file, "%d ", color);
      #endif /* DESKTOP */

    }
    C.im -= DELTA;
    #ifdef DESKTOP
    fprintf(output_file, "\n");
    #endif /* DESKTOP */
  }

  //*pixels = checksum;

#ifdef DESKTOP
  fclose(output_file);
  printf("Checksum Value: 0x%08x\n", checksum);
  printf("Expected Value: 0x%08x\n", EXPECTED_CHECKSUM);
#endif /* DESKTOP */

  // Check Checksum
  if(checksum == EXPECTED_CHECKSUM) {
    return 2;
  }
  else {
    return 1;
  }

}

void complex_add(Complex_Num *a, Complex_Num *b, Complex_Num *s) {
  s->re = a->re + b->re;
  s->im = a->im + b->im;

}

void complex_mult(Complex_Num *a, Complex_Num *b, Complex_Num *p) {
  int reProduct32, imProduct32;

  reProduct32 = mult(a->re, b->re) - mult(a->im, b->im);
  imProduct32 = mult(a->re, b->im) + mult(a->im, a->re);
  p->re = reProduct32 >> 12;
  p->im = imProduct32 >> 12;
}


void complex_square(Complex_Num *a, Complex_Num *sq) {
  complex_mult(a, a, sq);
}

// Zn1 = Zn^2 + C
void mandelbrot_iter(Complex_Num *Z, Complex_Num *C) {
    complex_square(Z, Z);
    complex_add(Z, C, Z);

}

int complex_magnitude(Complex_Num *a) {
  int mag32 = mult(a->re, a->re) + mult(a->im, a->im);
  return mag32 >> 12;
}

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




