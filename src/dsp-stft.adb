with DSP.Magnitude;
with DSP.Carrier;

package body DSP.STFT is
   Scratch : Real_Array (0 .. 512);

   function Quantize (A : Real) return Integer is
      DB : constant Real := To_DBFS (A);
      Q  : constant Real :=
        Real'Max (0.0, Real'Min (99.0, (DB + 120.0) * 99.0 / 120.0));
   begin
      return Integer (Q);
   end Quantize;

   procedure Build
     (S           : Real_Array;
      Win         : Real_Array;
      Hop         : Positive;
      Rate        : Positive;
      F_Max       : Real;
      Carrier_Hz  : Real;
      WF          : out Image;
      Rows        : out Natural;
      Cols        : out Natural;
      Level       : out Level_List;
      Frames      : out Natural;
      Df          : out Real;
      Carrier_Bin : out Natural)
   is
      N       : constant Natural := Win'Length;
      Half    : constant Natural := N / 2;
      Df_S    : Real;
      K_Max   : Natural;
      Frame_N : Natural;
      Stride  : Natural;
      Row     : Natural := 0;
      CK      : Natural;
   begin
      Rows := 0;
      Cols := 0;
      Frames := 0;
      Df := 0.0;
      Carrier_Bin := 0;
      for R in WF'Range (1) loop
         for C in WF'Range (2) loop
            WF (R, C) := 0;
         end loop;
      end loop;
      for I in Level'Range loop
         Level (I) := -200.0;
      end loop;

      if N < 2 or else N > 1024 or else not Is_Power_Of_Two (N) then
         return;
      end if;

      Df_S := Real (Rate) / Real (N);
      Df := Df_S;
      K_Max := Natural'Min (Half, Natural (F_Max / Df_S));
      if S'Length < N then
         Frame_N := 1;
      else
         Frame_N := (S'Length - N) / Hop + 1;
      end if;
      if Frame_N > Level'Length then
         Frame_N := Level'Length;
      end if;

      Stride := Frame_N / 400;
      if Stride < 1 then
         Stride := 1;
      end if;

      CK := DSP.Carrier.Bin (Carrier_Hz, Df_S, Half);
      Carrier_Bin := CK;

      for Fr in 0 .. Frame_N - 1 loop
         DSP.Magnitude.Frame
           (S, S'First + Fr * Hop, Win, Scratch (0 .. Half));
         Level (Fr) := DSP.Carrier.Level_DB (Scratch (0 .. Half), CK);
         if Fr mod Stride = 0 and then Row <= WF'Last (1) then
            for K in 0 .. K_Max loop
               WF (Row, K) := Quantize (Scratch (K));
            end loop;
            Row := Row + 1;
         end if;
      end loop;

      Frames := Frame_N;
      Rows := Row;
      Cols := K_Max + 1;
   end Build;
end DSP.STFT;
