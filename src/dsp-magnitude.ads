--  One windowed frame to a normalised magnitude spectrum.
--  Bins 0 .. N/2 are returned. Scaling is 2 |X[k]| / sum(window), so a
--  full-scale bin-centred sine has magnitude 1.0 (0 dBFS) on its bin.
--
--  SPARK proves the framing (indexes, the window sum, termination).
--  The scale 2 |X| / Σw is SPARK_Mode Off, same formula, measured by the
--  tone test. A coefficient outside 0 .. 1, or a sample outside ±1000,
--  is not a value Hann or the PCM path produces; the frame ignores it.
--  Every demo, WAV and self-test sample sits inside those bounds.
package DSP.Magnitude with
  SPARK_Mode,
  Abstract_State => (Work_State),
  Initializes => Work_State
is
   Max_FFT : constant := DSP.Max_FFT;

   procedure Frame
     (S     : Real_Array;
      Start : Natural;
      Win   : Real_Array;
      Mag   : out Real_Array)
   with
     Global => (In_Out => Work_State),
     Pre => Win'Length <= Max_FFT and then Mag'Length <= Max_FFT;
   --  Mag'Length must be at least Win'Length / 2 + 1.
   --  Samples past S'Last are zero (the last averaged frame may overhang).
end DSP.Magnitude;
