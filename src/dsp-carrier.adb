package body DSP.Carrier is
   function Bin (Carrier_Hz, Df : Real; Last_Bin : Natural) return Natural is
      K : Integer;
   begin
      if Df <= 0.0 then
         return 0;
      end if;
      K := Integer (Real'Rounding (Carrier_Hz / Df));
      if K < 0 then
         return 0;
      elsif K > Integer (Last_Bin) then
         return Last_Bin;
      else
         return Natural (K);
      end if;
   end Bin;

   function Level_DB (Mag : Real_Array; K : Natural) return Real is
      A : Real := 0.0;
   begin
      if K in Mag'Range then
         A := Mag (K);
      end if;
      if K > 0 and then K - 1 in Mag'Range and then Mag (K - 1) > A then
         A := Mag (K - 1);
      end if;
      if K + 1 in Mag'Range and then Mag (K + 1) > A then
         A := Mag (K + 1);
      end if;
      return To_DBFS (A);
   end Level_DB;

   function Frame_Time
     (Frame : Natural; Hop, Rate, Window_N : Positive) return Real
   is
      Half_T : constant Real := Real (Window_N) / 2.0 / Real (Rate);
   begin
      return Real (Frame * Hop) / Real (Rate) + Half_T;
   end Frame_Time;

   procedure Detect
     (Level     : Real_Array;
      Hop       : Positive;
      Rate      : Positive;
      Window_N  : Positive;
      Threshold : out Real;
      Lo, Hi    : out Real;
      Edges     : out Edge_List;
      Count     : out Natural)
   is
      State  : Boolean := False;
      T0     : Real := 0.0;
      Last_T : Real := 0.0;
      Thr    : Real;
   begin
      Edges := (others => (0.0, 0.0));
      Count := 0;
      if Level'Length = 0 then
         Threshold := 0.0;
         Lo := 0.0;
         Hi := 0.0;
         return;
      end if;

      Lo := Level (Level'First);
      Hi := Level (Level'First);
      for V of Level loop
         if V < Lo then
            Lo := V;
         end if;
         if V > Hi then
            Hi := V;
         end if;
      end loop;
      if Hi - Lo > 6.0 then
         Thr := (Hi + Lo) / 2.0;
      else
         Thr := Hi + 1.0;
      end if;
      Threshold := Thr;

      for Fr in Level'Range loop
         declare
            T  : constant Real :=
              Frame_Time (Fr - Level'First, Hop, Rate, Window_N);
            On : constant Boolean := Level (Fr) > Thr;
         begin
            Last_T := T;
            if On and then not State then
               T0 := T;
            end if;
            if State and then not On and then Count < Max_Edges then
               Count := Count + 1;
               Edges (Count) := (T0, T);
            end if;
            State := On;
         end;
      end loop;

      if State and then Count < Max_Edges then
         Count := Count + 1;
         Edges (Count) := (T0, Last_T);
      end if;
   end Detect;
end DSP.Carrier;
