with Ada.Numerics;

package body DSP.Window with SPARK_Mode is
   procedure Hann (Win : out Real_Array) is
      N   : constant Natural := Win'Length;
      Tmp : Real_Array (Win'Range) := (others => 0.0);
   begin
      for I in Tmp'Range loop
         pragma Loop_Invariant
           (for all J in Tmp'Range =>
              (if J < I then Tmp (J) in 0.0 .. 1.0));
         declare
            C : constant Real := Cos
              (2.0 * Ada.Numerics.Pi * Real (I - Tmp'First) / Real (N));
            W : constant Real := 0.5 - 0.5 * C;
         begin
            Tmp (I) := W;
         end;
      end loop;
      Win := Tmp;
   end Hann;
end DSP.Window;
