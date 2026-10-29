--  Shared numeric types for the analyzer.
--  Real is IEEE-754 double (Long_Float on both the native and wasm32 targets).
--
--  SPARK covers this package and the window, FFT, magnitude, STFT and
--  carrier units. Silver is the absence of run-time errors in that subset.
--  Sin, Cos, Sqrt and the logarithm used by To_DBFS are the platform
--  elementary functions: their posts are bounds the proof may use, and
--  their bodies are not proved. Complex arithmetic is the same (bodies
--  not in SPARK). Neither is a stand-in for a fixed-point model.
package DSP with SPARK_Mode is
   subtype Real is Long_Float;

   --  Largest FFT the proved index arithmetic covers. The pipeline never
   --  asks for a longer transform (Magnitude refuses it).
   Max_FFT : constant := 4_096;

   type Real_Array is array (Natural range <>) of Real;

   type Complex is record
      Re, Im : Real;
   end record;

   type Complex_Array is array (Natural range <>) of Complex;

   function Is_Power_Of_Two (N : Natural) return Boolean with
     Global => null,
     Subprogram_Variant => (Decreases => N),
     Post => Is_Power_Of_Two'Result =
       (if N = 0 then False
        elsif N = 1 then True
        else N mod 2 = 0 and then Is_Power_Of_Two (N / 2));

   function "+" (L, R : Complex) return Complex with Global => null;
   function "-" (L, R : Complex) return Complex with Global => null;
   function "*" (L, R : Complex) return Complex with Global => null;
   function "abs" (C : Complex) return Real with Global => null;

   --  Trusted bounds of the platform functions, not proofs of them.
   function Sin (X : Real) return Real with
     Global => null,
     Post => Sin'Result in -1.0 .. 1.0;
   function Cos (X : Real) return Real with
     Global => null,
     Post => Cos'Result in -1.0 .. 1.0;
   function Sqrt (X : Real) return Real with
     Pre => X >= 0.0,
     Global => null,
     Post => Sqrt'Result >= 0.0;

   function To_DBFS (A : Real) return Real with
     Global => null,
     Post => To_DBFS'Result in -80_000.0 .. 80_000.0;
   --  20 log10(A). Amplitudes below 1e-10 map to -200 so an empty bin
   --  cannot dominate a mean or a minimum.
end DSP;
