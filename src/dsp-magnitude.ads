--  One windowed frame to a normalised magnitude spectrum.
--  Bins 0 .. N/2 are returned. Scaling is 2 |X[k]| / sum(window), so a
--  full-scale bin-centred sine has magnitude 1.0 (0 dBFS) on its bin.
package DSP.Magnitude is
   Max_FFT : constant := 4096;

   procedure Frame
     (S     : Real_Array;
      Start : Natural;
      Win   : Real_Array;
      Mag   : out Real_Array);
   --  Mag'Length must be Win'Length / 2 + 1.
   --  Samples past S'Last are zero (the last averaged frame may overhang).
end DSP.Magnitude;
