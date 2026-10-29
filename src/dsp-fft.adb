with Ada.Numerics;

package body DSP.FFT with SPARK_Mode is
   procedure Lemma_Half (N : Natural) with
     Ghost,
     Pre => N >= 2 and then Is_Power_Of_Two (N),
     Post => N mod 2 = 0
       and then Is_Power_Of_Two (N / 2)
       and then 2 * (N / 2) = N,
     Global => null;

   procedure Lemma_Half (N : Natural) is
   begin
      pragma Assert (N mod 2 = 0);
      pragma Assert (Is_Power_Of_Two (N / 2));
      pragma Assert (2 * (N / 2) = N);
   end Lemma_Half;

   --  Halving a positive power of two. Bit = 1 produces 0.
   procedure Lemma_Shift (Bit : Natural) with
     Ghost,
     Pre => Bit > 0 and then Is_Power_Of_Two (Bit),
     Post => Bit / 2 < Bit
       and then (if Bit = 1 then Bit / 2 = 0
                 else Is_Power_Of_Two (Bit / 2)),
     Global => null;

   procedure Lemma_Shift (Bit : Natural) is
   begin
      if Bit = 1 then
         pragma Assert (Bit / 2 = 0);
      else
         pragma Assert (Bit >= 2);
         pragma Assert (Bit mod 2 = 0);
         pragma Assert (Is_Power_Of_Two (Bit / 2));
         pragma Assert (Bit / 2 < Bit);
      end if;
   end Lemma_Shift;

   procedure Lemma_Block (I, Len, N : Natural) with
     Ghost,
     Pre => Len >= 2
       and then I < N
       and then I mod Len = 0
       and then N mod Len = 0,
     Post => I + Len <= N,
     Global => null;

   procedure Lemma_Block (I, Len, N : Natural) is
   begin
      pragma Assert (I + Len <= N);
   end Lemma_Block;

   --  2^E for E in 0 .. 12. Written out so the bound is a literal.
   function Pow2 (E : Natural) return Natural with
     Ghost,
     Pre => E <= 12,
     Post => Pow2'Result >= 1 and then Pow2'Result <= DSP.Max_FFT,
     Global => null;

   function Pow2 (E : Natural) return Natural is
     (case E is
         when 0 => 1,
         when 1 => 2,
         when 2 => 4,
         when 3 => 8,
         when 4 => 16,
         when 5 => 32,
         when 6 => 64,
         when 7 => 128,
         when 8 => 256,
         when 9 => 512,
         when 10 => 1_024,
         when 11 => 2_048,
         when others => 4_096);

   function Exp_Of (N : Natural) return Natural with
     Ghost,
     Pre => N in 1 .. DSP.Max_FFT and then Is_Power_Of_Two (N),
     Post => Exp_Of'Result <= 12 and then Pow2 (Exp_Of'Result) = N,
     Global => null;

   function Exp_Of (N : Natural) return Natural is
      E : Natural := 0;
      X : Natural := N;
   begin
      while X > 1 loop
         pragma Loop_Invariant (Is_Power_Of_Two (X));
         pragma Loop_Invariant (E <= 12);
         pragma Loop_Invariant (X * Pow2 (E) = N);
         pragma Loop_Variant (Decreases => X);
         Lemma_Half (X);
         X := X / 2;
         E := E + 1;
      end loop;
      pragma Assert (X = 1);
      pragma Assert (Pow2 (E) = N);
      return E;
   end Exp_Of;

   procedure Lemma_Double (Len, N : Natural) with
     Ghost,
     Pre => Is_Power_Of_Two (Len)
       and then Is_Power_Of_Two (N)
       and then Len in 2 .. DSP.Max_FFT
       and then N in 2 .. DSP.Max_FFT
       and then Len <= N / 2
       and then N mod Len = 0,
     Post => Is_Power_Of_Two (2 * Len)
       and then 2 * Len <= N
       and then N mod (2 * Len) = 0,
     Global => null;

   procedure Lemma_Double (Len, N : Natural) is
      EL   : constant Natural := Exp_Of (Len);
      Left : Natural := N;
      K    : Natural := 0;
   begin
      pragma Assert (Pow2 (EL) = Len);
      pragma Assert (2 * Len <= N);
      pragma Assert (EL < 12);
      while K < EL + 1 loop
         pragma Loop_Invariant (K <= EL + 1);
         pragma Loop_Invariant (Is_Power_Of_Two (Left) and then Left >= 2);
         pragma Loop_Invariant (Left * Pow2 (K) = N);
         pragma Loop_Variant (Increases => K);
         Lemma_Half (Left);
         Left := Left / 2;
         K := K + 1;
      end loop;
      pragma Assert (Pow2 (K) = 2 * Len);
      pragma Assert (Left * (2 * Len) = N);
      pragma Assert (N mod (2 * Len) = 0);
      pragma Assert (Is_Power_Of_Two (2 * Len));
   end Lemma_Double;

   function Twiddle (Len : Natural) return Complex with
     Pre => Len >= 2,
     Global => null;

   function Twiddle (Len : Natural) return Complex with SPARK_Mode => Off is
      Ang : constant Real := -2.0 * Ada.Numerics.Pi / Real (Len);
   begin
      return (Cos (Ang), Sin (Ang));
   end Twiddle;

   function Next_W (W, WL : Complex) return Complex with
     Global => null;

   function Next_W (W, WL : Complex) return Complex with SPARK_Mode => Off is
   begin
      return W * WL;
   end Next_W;

   procedure Butterfly
     (X : in out Complex_Array; Lo, Hi : Natural; W : Complex)
   with
     Pre => Lo in X'Range and then Hi in X'Range,
     Global => null;

   procedure Butterfly
     (X : in out Complex_Array; Lo, Hi : Natural; W : Complex)
   with SPARK_Mode => Off
   is
      U : constant Complex := X (Lo);
      V : constant Complex := X (Hi) * W;
   begin
      X (Lo) := U + V;
      X (Hi) := U - V;
   end Butterfly;

   procedure Transform (X : in out Complex_Array) is
      N    : constant Natural := X'Length;
      Base : constant Natural := X'First;
      J    : Natural := 0;
      Len  : Natural := 2;
   begin
      if N < 2 or else not Is_Power_Of_Two (N) then
         return;
      end if;

      Lemma_Half (N);

      for I_Rev in 1 .. N - 1 loop
         pragma Loop_Invariant (J < N);
         declare
            Bit : Natural := N / 2;
         begin
            while J >= Bit and then Bit > 0 loop
               pragma Loop_Invariant (J < N);
               pragma Loop_Invariant (Bit <= N / 2);
               pragma Loop_Invariant (J >= Bit);
               pragma Loop_Invariant
                 (Is_Power_Of_Two (Bit) and then N mod Bit = 0);
               pragma Loop_Variant (Decreases => Bit);
               Lemma_Shift (Bit);
               J := J - Bit;
               Bit := Bit / 2;
            end loop;

            pragma Assert (Bit = 0 or else J < Bit);
            pragma Assert (Bit <= N / 2);
            J := J + Bit;
         end;

         pragma Assert (J < N);
         if I_Rev < J then
            declare
               Tmp : constant Complex := X (Base + I_Rev);
            begin
               X (Base + I_Rev) := X (Base + J);
               X (Base + J) := Tmp;
            end;
         end if;
      end loop;

      while Len <= N loop
         pragma Loop_Invariant
           (Is_Power_Of_Two (Len) and then Len >= 2 and then Len <= N);
         pragma Loop_Invariant (N mod Len = 0);
         pragma Loop_Variant (Increases => Len);

         declare
            WL : constant Complex := Twiddle (Len);
            I  : Natural := 0;
         begin
            while I < N loop
               pragma Loop_Invariant (I <= N and then I mod Len = 0);
               pragma Loop_Invariant (N mod Len = 0 and then Len >= 2);
               pragma Loop_Variant (Increases => I);
               Lemma_Block (I, Len, N);

               declare
                  W : Complex := (1.0, 0.0);
               begin
                  for K in 0 .. Len / 2 - 1 loop
                     pragma Loop_Invariant (I + Len <= N);
                     declare
                        Lo : constant Natural := Base + I + K;
                        Hi : constant Natural := Base + I + K + Len / 2;
                     begin
                        Butterfly (X, Lo, Hi, W);
                        W := Next_W (W, WL);
                     end;
                  end loop;
               end;
               I := I + Len;
            end loop;
         end;

         exit when Len > N / 2;
         Lemma_Double (Len, N);
         Len := 2 * Len;
      end loop;
   end Transform;
end DSP.FFT;
