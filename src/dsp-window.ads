--  Hann window. w(i) = 0.5 - 0.5 cos(2 π i / N), i = 0 .. N-1.
--  Periodic form (divisor N, not N-1), so a bin-centred tone lands on
--  exactly three FFT bins and the coherent-gain normalisation in
--  DSP.Magnitude is exact.
--  The loop and the range of each coefficient are SPARK. Cos is the
--  trusted platform bound from DSP.
package DSP.Window with SPARK_Mode is
   procedure Hann (Win : out Real_Array) with
     Pre => Win'Length <= DSP.Max_FFT,
     Post => (for all I in Win'Range => Win (I) in 0.0 .. 1.0),
     Global => null;
end DSP.Window;
