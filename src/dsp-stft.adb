with DSP.Carrier;

package body DSP.STFT with
  SPARK_Mode,
  Refined_State => (Hop_Scratch => Scratch)
is
   Scratch : Real_Array (0 .. 512) := (others => 0.0);

   function Quantize (A : Real) return Integer is
      DB : constant Real := To_DBFS (A);
      Q  : Real;
   begin
      --  Same clamp as (dB + 120) * 99 / 120 limited to 0 .. 99.
      --  Outside -120 .. 0 the limited value is exactly the endpoint,
      --  so the multiply is only done where it cannot overflow.
      if DB <= -120.0 then
         return 0;
      elsif DB >= 0.0 then
         return 99;
      end if;
      Q := (DB + 120.0) * 99.0 / 120.0;
      Q := Real'Max (0.0, Real'Min (99.0, Q));
      return Integer (Q);
   end Quantize;

   function Count_Frames
     (Length : Natural; Window, Hop : Positive) return Natural
   is
      N : Natural;
   begin
      if Length < Window then
         N := 1;
      else
         N := (Length - Window) / Hop + 1;
      end if;
      if N > Max_Rows then
         return Max_Rows;
      end if;
      return N;
   end Count_Frames;

   procedure Measure_Frame
     (S           : Real_Array;
      Start       : Natural;
      Win         : Real_Array;
      Rate        : Positive;
      F_Max       : Real;
      Carrier_Hz  : Real;
      Mag         : out Real_Array;
      Cols        : out Natural;
      Df          : out Real;
      Carrier_Bin : out Natural;
      Level       : out Real)
   is
      N     : constant Natural := Win'Length;
      Half  : constant Natural := N / 2;
      Df_S  : Real;
      K_Max : Natural;
      CK    : Natural;
   begin
      Cols := 0;
      Df := 0.0;
      Carrier_Bin := 0;
      Level := -200.0;
      for K in Mag'Range loop
         Mag (K) := 0.0;
      end loop;

      if N < 2
        or else N > 1_024
        or else not Is_Power_Of_Two (N)
        or else Mag'Length < Half + 1
      then
         return;
      end if;

      Df_S := Real (Rate) / Real (N);
      pragma Assert (N <= 1_024);
      pragma Assert (Rate >= 8_000);
      pragma Assert (Df_S >= 7.0);
      pragma Assert (F_Max <= 2_000.0);
      if F_Max <= 0.0 or else Df_S <= 0.0 then
         K_Max := 0;
      elsif F_Max / Df_S >= Real (Half) then
         K_Max := Half;
      else
         K_Max := Natural (F_Max / Df_S);
         if K_Max > Half then
            K_Max := Half;
         end if;
      end if;
      DSP.Magnitude.Frame (S, Start, Win, Mag);
      CK := DSP.Carrier.Bin (Carrier_Hz, Df_S, Half);
      pragma Assert (K_Max <= Half and then Half <= 512);
      Cols := K_Max + 1;
      Df := Df_S;
      Carrier_Bin := CK;
      Level := DSP.Carrier.Level_DB (Mag, CK);
   end Measure_Frame;

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
   with Refined_Global => (In_Out => (Scratch, DSP.Magnitude.Work_State))
   is
      N       : constant Natural := Win'Length;
      Half    : constant Natural := N / 2;
      Frame_N : Natural;
      Stride  : Natural;
      Row     : Natural := 0;
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

      Frame_N := Count_Frames (S'Length, N, Hop);

      Stride := Frame_N / 400;
      if Stride < 1 then
         Stride := 1;
      end if;

      for Fr in 0 .. Frame_N - 1 loop
         pragma Loop_Invariant (Row <= Max_Rows);
         pragma Loop_Invariant (Stride >= 1);
         pragma Loop_Invariant (Frame_N in 1 .. Max_Rows);
         declare
            Got   : Natural;
            Df_F  : Real;
            Bin_F : Natural;
            Lv    : Real;
         begin
            Measure_Frame
              (S           => S,
               Start       => S'First + Fr * Hop,
               Win         => Win,
               Rate        => Rate,
               F_Max       => F_Max,
               Carrier_Hz  => Carrier_Hz,
               Mag         => Scratch (0 .. Half),
               Cols        => Got,
               Df          => Df_F,
               Carrier_Bin => Bin_F,
               Level       => Lv);
            Level (Fr) := Lv;
            Df := Df_F;
            Carrier_Bin := Bin_F;
            Cols := Got;
            if Got > 0 and then Fr mod Stride = 0 and then Row <= WF'Last (1) then
               for K in 0 .. Got - 1 loop
                  pragma Loop_Invariant (Got <= Max_Cols);
                  WF (Row, K) := Quantize (Scratch (K));
               end loop;
               Row := Row + 1;
            end if;
         end;
      end loop;

      Frames := Frame_N;
      Rows := Row;
   end Build;
end DSP.STFT;
