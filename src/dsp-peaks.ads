--  Peak picker for a dBFS spectrum.
--  A bin is a peak when it is strictly above its ±2 neighbours on the
--  low side and at least as high on the high side, and more than 15 dB
--  above the mean bin level. The top Max_Peaks survive. Each survivor is
--  refined by a parabolic fit through the three log-magnitude samples
--  around the bin, which is what places 50 Hz at 49.98 rather than on
--  the 1.95 Hz bin grid.
package DSP.Peaks is
   Max_Peaks : constant := 10;

   type Peak is record
      F : Real := 0.0;
      D : Real := -999.0;
   end record;

   type Peak_List is array (1 .. Max_Peaks) of Peak;

   procedure Find
     (Spectrum : Real_Array;
      Df       : Real;
      Floor_DB : Real;
      Peaks    : out Peak_List;
      Found    : out Natural);
   --  Spectrum is dBFS, one entry per bin. Bin 0 is Spectrum'First.
   --  Peaks (1 .. Found) come back sorted by increasing frequency.
end DSP.Peaks;
