with Ada.Numerics;

package body DSP.Window is
   procedure Hann (Win : out Real_Array) is
      N : constant Natural := Win'Length;
   begin
      for I in Win'Range loop
         Win (I) := 0.5 - 0.5 * Cos
           (2.0 * Ada.Numerics.Pi * Real (I - Win'First) / Real (N));
      end loop;
   end Hann;
end DSP.Window;
