with Ada.Numerics;
with Interfaces;

package body Demo_Signal is
   procedure Generate (S : out DSP.Real_Array) is
      use Interfaces;
      Two_Pi : constant Long_Float := 2.0 * Ada.Numerics.Pi;
      Rng    : Unsigned_32 := 42;
      U      : Long_Float;
      T      : Long_Float;
      V      : Long_Float;
      On     : Boolean;
      Slot   : Integer;
   begin
      if S'Length /= Sample_Count then
         for I in S'Range loop
            S (I) := 0.0;
         end loop;
         return;
      end if;

      for I in S'Range loop
         T := Long_Float (I - S'First) / Long_Float (Rate);
         V := 0.5 * DSP.Sin (Two_Pi * 50.0 * T);
         V := V + 0.04 * DSP.Sin (Two_Pi * 150.0 * T + 0.3)
                + 0.025 * DSP.Sin (Two_Pi * 250.0 * T + 1.1)
                + 0.01 * DSP.Sin (Two_Pi * 350.0 * T + 2.0)
                + 0.005 * DSP.Sin (Two_Pi * 100.0 * T);

         On := False;
         if T >= 0.5 and then T < 1.0 then
            On := True;
         elsif T >= 1.5 then
            Slot := Integer (Long_Float'Floor ((T - 1.5) / 0.5));
            if Slot >= 0 and then Slot < Telegram'Length then
               On := Telegram (Telegram'First + Slot) = '1';
            end if;
         end if;

         if On then
            V := V + 0.008 * DSP.Sin (Two_Pi * Carrier_Hz * T);
         end if;

         Rng := Rng * 1_664_525 + 1_013_904_223;
         U := Long_Float (Shift_Right (Rng, 8) mod 16_777_216) / 16_777_216.0;
         V := V + 0.004 * (2.0 * U - 1.0);
         S (I) := V;
      end loop;
   end Generate;
end Demo_Signal;
