with DSP.FFT;

package body DSP.Magnitude with
  SPARK_Mode,
  Refined_State => (Work_State => Work)
is
   Work : Complex_Array (0 .. Max_FFT - 1) := (others => (0.0, 0.0));

   --  Start is inside First .. Last - I, so Start + I is an index.
   procedure Lemma_Offset (Start, I, First, Last : Natural) with
     Ghost,
     Pre => I <= Last
       and then Start >= First
       and then Start <= Last - I,
     Post => Start + I >= First
       and then Start + I <= Last
       and then Start <= Natural'Last - I,
     Global => null;

   procedure Lemma_Offset (Start, I, First, Last : Natural) is null;

   function Windowed (Sample, Coeff : Real) return Real with
     Pre => Sample in -1_000.0 .. 1_000.0 and then Coeff in 0.0 .. 1.0,
     Post => Windowed'Result in -1_000.0 .. 1_000.0,
     Global => null;

   function Windowed (Sample, Coeff : Real) return Real is
     (Sample * Coeff);

   function Scaled_Mag (C : Complex; Sum_W : Real) return Real with
     Pre => Sum_W > 0.0,
     Global => null;

   function Scaled_Mag (C : Complex; Sum_W : Real) return Real
     with SPARK_Mode => Off
   is
   begin
      return 2.0 * abs (C) / Sum_W;
   end Scaled_Mag;

   procedure Frame
     (S     : Real_Array;
      Start : Natural;
      Win   : Real_Array;
      Mag   : out Real_Array)
   with Refined_Global => (In_Out => Work)
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
         declare
            Coeff : Real := Win (Win'First + I);
         begin
            --  Hann's proved range is 0 .. 1. A coefficient outside that
            --  is not a window this pipeline builds.
            if Coeff < 0.0 then
               Coeff := 0.0;
            elsif Coeff > 1.0 then
               Coeff := 1.0;
            end if;
            if S'Length > 0
              and then I <= S'Last
              and then Start >= S'First
              and then Start <= S'Last - I
            then
               Lemma_Offset (Start, I, S'First, S'Last);
               declare
                  Idx : constant Natural := Start + I;
               begin
                  pragma Assert (Idx in S'Range);
                  if S (Idx) in -1_000.0 .. 1_000.0 then
                     Work (I) := (Windowed (S (Idx), Coeff), 0.0);
                  else
                     Work (I) := (0.0, 0.0);
                  end if;
               end;
            else
               Work (I) := (0.0, 0.0);
            end if;
         end;
      end loop;

      for I in 0 .. N - 1 loop
         pragma Loop_Invariant (Sum_W >= 0.0);
         pragma Loop_Invariant (Sum_W <= 2.0 * Real (I) + 2.0);
         declare
            Coeff : Real := Win (Win'First + I);
         begin
            if Coeff < 0.0 then
               Coeff := 0.0;
            elsif Coeff > 1.0 then
               Coeff := 1.0;
            end if;
            Sum_W := Sum_W + Coeff;
         end;
      end loop;

      if Sum_W = 0.0 then
         Sum_W := 1.0;
      end if;

      pragma Assert (Sum_W > 0.0);
      pragma Assert (N in 2 .. Max_FFT);
      DSP.FFT.Transform (Work (0 .. N - 1));

      for K in Mag'Range loop
         if K <= Mag'First + N / 2 then
            Mag (K) := Scaled_Mag (Work (K - Mag'First), Sum_W);
         else
            Mag (K) := 0.0;
         end if;
      end loop;
   end Frame;
end DSP.Magnitude;
