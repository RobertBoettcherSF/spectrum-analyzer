with Ada.Numerics.Long_Elementary_Functions;
use Ada.Numerics.Long_Elementary_Functions;

package body DSP is
   function Is_Power_Of_Two (N : Natural) return Boolean is
      M : Natural := N;
   begin
      if M = 0 then
         return False;
      end if;
      while M mod 2 = 0 loop
         M := M / 2;
      end loop;
      return M = 1;
   end Is_Power_Of_Two;

   function "+" (L, R : Complex) return Complex is
     ((L.Re + R.Re, L.Im + R.Im));

   function "-" (L, R : Complex) return Complex is
     ((L.Re - R.Re, L.Im - R.Im));

   function "*" (L, R : Complex) return Complex is
     ((L.Re * R.Re - L.Im * R.Im, L.Re * R.Im + L.Im * R.Re));

   function "abs" (C : Complex) return Real is
     (Sqrt (C.Re * C.Re + C.Im * C.Im));

   function Sin (X : Real) return Real is
     (Ada.Numerics.Long_Elementary_Functions.Sin (X));

   function Cos (X : Real) return Real is
     (Ada.Numerics.Long_Elementary_Functions.Cos (X));

   function Sqrt (X : Real) return Real is
     (Ada.Numerics.Long_Elementary_Functions.Sqrt (X));

   function To_DBFS (A : Real) return Real is
   begin
      if A < 1.0E-10 then
         return -200.0;
      end if;
      return 20.0 * Log (A, 10.0);
   end To_DBFS;
end DSP;
