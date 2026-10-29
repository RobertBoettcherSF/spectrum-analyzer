with DSP.FFT;

package body DSP.Magnitude is
   Work : Complex_Array (0 .. Max_FFT - 1);

   procedure Frame
     (S     : Real_Array;
      Start : Natural;
      Win   : Real_Array;
      Mag   : out Real_Array)
   is
      N     : constant Natural := Win'Length;
      Sum_W : Real := 0.0;
   begin
      if N < 2
        or else not Is_Power_Of_Two (N)
        or else N > Max_FFT
        or else Mag'Length < N / 2 + 1
      then
         for K in Mag'Range loop
            Mag (K) := 0.0;
         end loop;
         return;
      end if;

      for I in 0 .. N - 1 loop
         if I <= S'Last and then Start <= S'Last - I then
            Work (I) := (S (Start + I) * Win (Win'First + I), 0.0);
         else
            Work (I) := (0.0, 0.0);
         end if;
         Sum_W := Sum_W + Win (Win'First + I);
      end loop;

      if Sum_W = 0.0 then
         Sum_W := 1.0;
      end if;

      DSP.FFT.Transform (Work (0 .. N - 1));

      for K in 0 .. N / 2 loop
         Mag (Mag'First + K) := 2.0 * abs (Work (K)) / Sum_W;
      end loop;
   end Frame;
end DSP.Magnitude;
