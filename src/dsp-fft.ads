--  In-place iterative radix-2 decimation-in-time FFT.
--  Length must be a power of two and at most DSP.Max_FFT for the proof.
--  Twiddles are e^{-2 π i k / N} (forward transform). Bit reversal, then
--  butterflies of length 2, 4, ... N. Same arithmetic as before.
--
--  SPARK proves the index plan and that the loops terminate. The complex
--  butterfly and the sin/cos twiddle are SPARK_Mode Off (measured by the
--  bin-centred tone, not by GNATprove).
package DSP.FFT with SPARK_Mode is
   procedure Transform (X : in out Complex_Array) with
     Pre => X'First = 0 and then X'Length in 2 .. DSP.Max_FFT,
     Global => null;
end DSP.FFT;
