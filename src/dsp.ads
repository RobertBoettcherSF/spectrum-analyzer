--  Shared numeric types for the analyzer.
--  Real is IEEE-754 double (Long_Float on both the native and wasm32 targets).
--  The transform itself is the radix-2 FFT in DSP.FFT; this package only holds
--  the sample type, complex arithmetic, and the dBFS conversion.
package DSP is
   subtype Real is Long_Float;

   type Real_Array is array (Natural range <>) of Real;

   type Complex is record
      Re, Im : Real;
   end record;

   type Complex_Array is array (Natural range <>) of Complex;

   function Is_Power_Of_Two (N : Natural) return Boolean;

   function "+" (L, R : Complex) return Complex;
   function "-" (L, R : Complex) return Complex;
   function "*" (L, R : Complex) return Complex;
   function "abs" (C : Complex) return Real;

   function Sin (X : Real) return Real;
   function Cos (X : Real) return Real;
   function Sqrt (X : Real) return Real;

   function To_DBFS (A : Real) return Real;
   --  20 log10(A). Amplitudes below 1e-10 map to -200 so an empty bin
   --  cannot dominate a mean or a minimum.
end DSP;
