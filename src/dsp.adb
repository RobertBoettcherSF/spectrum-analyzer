with Ada.Numerics.Long_Elementary_Functions;

package body DSP with SPARK_Mode is
   function Is_Power_Of_Two (N : Natural) return Boolean is
     (if N = 0 then False
      elsif N = 1 then True
      else N mod 2 = 0 and then Is_Power_Of_Two (N / 2));

   function "+" (L, R : Complex) return Complex with SPARK_Mode => Off is
   begin
      return (L.Re + R.Re, L.Im + R.Im);
   end "+";

   function "-" (L, R : Complex) return Complex with SPARK_Mode => Off is
   begin
      return (L.Re - R.Re, L.Im - R.Im);
   end "-";

   function "*" (L, R : Complex) return Complex with SPARK_Mode => Off is
   begin
      return (L.Re * R.Re - L.Im * R.Im, L.Re * R.Im + L.Im * R.Re);
   end "*";

   function "abs" (C : Complex) return Real with SPARK_Mode => Off is
   begin
      return Sqrt (C.Re * C.Re + C.Im * C.Im);
   end "abs";

   function Sin (X : Real) return Real with SPARK_Mode => Off is
   begin
      return Ada.Numerics.Long_Elementary_Functions.Sin (X);
   end Sin;

   function Cos (X : Real) return Real with SPARK_Mode => Off is
   begin
      return Ada.Numerics.Long_Elementary_Functions.Cos (X);
   end Cos;

   function Sqrt (X : Real) return Real with SPARK_Mode => Off is
   begin
      return Ada.Numerics.Long_Elementary_Functions.Sqrt (X);
   end Sqrt;

   --  Platform log10. The post is a bound, not a proof of the function.
   function Log10 (X : Real) return Real with
     Pre => X > 0.0,
     Post => Log10'Result in -4_000.0 .. 4_000.0,
     Global => null;

   function Log10 (X : Real) return Real with SPARK_Mode => Off is
   begin
      return Ada.Numerics.Long_Elementary_Functions.Log (X, 10.0);
   end Log10;

   function To_DBFS (A : Real) return Real is
   begin
      if A < 1.0E-10 then
         return -200.0;
      end if;
      return 20.0 * Log10 (A);
   end To_DBFS;
end DSP;
