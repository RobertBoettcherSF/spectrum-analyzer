with DSP;

--  Runs the demonstration end to end and keeps the results the page reads.
--  Pipeline: demo signal, Hann, power-averaged radix-2 spectrum, peak pick,
--  STFT waterfall, carrier track and on/off edges. A bin-centred sine is
--  measured first so a broken FFT cannot hide behind a plausible drawing.
package Analysis is
   procedure Run;

   function Ready return Boolean;
   function Tone_OK return Boolean;
   function Tone_Peak return DSP.Real;
   function Tone_Side return DSP.Real;
   function Tone_Far return DSP.Real;

   function Sample_Rate return Positive;
   function Fft_Size return Positive;
   function Stft_Size return Positive;
   function Hop_Size return Positive;
   function Avg_Count return Natural;
   function Spec_Bins return Natural;
   function Df return DSP.Real;
   function Sdf return DSP.Real;
   function F_Max return DSP.Real;
   function Carrier_Hz return DSP.Real;
   function Carrier_Bin return Natural;
   function Duration return DSP.Real;
   function Floor_DB return DSP.Real;
   function Threshold_DB return DSP.Real;
   function Lo_DB return DSP.Real;
   function Hi_DB return DSP.Real;
   function Rbw return DSP.Real;

   function Spec_DB (K : Natural) return DSP.Real;

   function Marker_Count return Natural;
   function Marker_Hz (I : Positive) return DSP.Real;
   function Marker_DB (I : Positive) return DSP.Real;
   function Marker_Is_Carrier (I : Positive) return Boolean;

   function Waterfall_Rows return Natural;
   function Waterfall_Cols return Natural;
   function Waterfall (Row, Col : Natural) return Natural;

   function Timeline_Count return Natural;
   function Timeline_T (I : Natural) return DSP.Real;
   function Timeline_DB (I : Natural) return DSP.Real;
   function Timeline_On (I : Natural) return Boolean;

   function Edge_Count return Natural;
   function Edge_On (I : Positive) return DSP.Real;
   function Edge_Off (I : Positive) return DSP.Real;
end Analysis;
