--  Hann window. w(i) = 0.5 - 0.5 cos(2 π i / N), i = 0 .. N-1.
--  Periodic form (divisor N, not N-1), so a bin-centred tone lands on
--  exactly three FFT bins and the coherent-gain normalisation in
--  DSP.Magnitude is exact.
package DSP.Window is
   procedure Hann (Win : out Real_Array);
end DSP.Window;
