--  In-place iterative radix-2 decimation-in-time FFT.
--  Length must be a power of two. Twiddles are e^{-2 π i k / N}
--  (forward transform). Bit reversal, then butterflies of length
--  2, 4, ... N. This is the same algorithm as the plain-Ada CLI analyzer.
package DSP.FFT is
   procedure Transform (X : in out Complex_Array);
end DSP.FFT;
