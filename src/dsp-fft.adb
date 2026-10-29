with Ada.Numerics;

package body DSP.FFT is
   procedure Transform (X : in out Complex_Array) is
      N    : constant Natural := X'Length;
      Base : constant Natural := X'First;
      J    : Natural := 0;
      Len  : Natural := 2;
      Bit  : Natural;
      Tmp  : Complex;
      Ang  : Real;
      WL   : Complex;
      W    : Complex;
      I    : Natural;
      U    : Complex;
      V    : Complex;
   begin
      if N < 2 or else not Is_Power_Of_Two (N) then
         return;
      end if;

      for I_Rev in 1 .. N - 1 loop
         Bit := N / 2;
         while J >= Bit and then Bit > 0 loop
            J := J - Bit;
            Bit := Bit / 2;
         end loop;
         J := J + Bit;
         if I_Rev < J then
            Tmp := X (Base + I_Rev);
            X (Base + I_Rev) := X (Base + J);
            X (Base + J) := Tmp;
         end if;
      end loop;

      while Len <= N loop
         Ang := -2.0 * Ada.Numerics.Pi / Real (Len);
         WL := (Cos (Ang), Sin (Ang));
         I := 0;
         while I < N loop
            W := (1.0, 0.0);
            for K in 0 .. Len / 2 - 1 loop
               U := X (Base + I + K);
               V := X (Base + I + K + Len / 2) * W;
               X (Base + I + K) := U + V;
               X (Base + I + K + Len / 2) := U - V;
               W := W * WL;
            end loop;
            I := I + Len;
         end loop;
         Len := Len * 2;
      end loop;
   end Transform;
end DSP.FFT;
