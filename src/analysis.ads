with DSP;

--  Runs one buffer end to end and keeps the results the page reads.
--  Pipeline: Hann, power-averaged radix-2 spectrum, peak pick, STFT
--  waterfall, carrier track and on/off edges. Run uses the built-in
--  demonstration waveform. Run_PCM uses samples the page loaded.
--  A bin-centred sine is measured first so a broken FFT cannot hide
--  behind a plausible drawing.
package Analysis is
   --  One FFT frame, up to about 10 s at 48 kHz. Every accepted length
   --  fits in DSP.STFT.Max_Rows, so the carrier track is not truncated.
   Min_Samples : constant := 4_096;
   Max_Samples : constant := 524_288;
   Min_Rate    : constant := 8_000;
   Max_Rate    : constant := 192_000;
   --  Microhertz fields are 32-bit. 2 kHz keeps a 1 kHz tone inside the
   --  plot with neighbour bins, and stays under that ceiling. The demo
   --  plot still stops at 1 kHz.
   PCM_F_Max   : constant DSP.Real := 2_000.0;

   procedure Run;

   procedure Put_PCM (Index : Natural; Amplitude : DSP.Real);
   --  One sample in about -1 .. 1. Index is 0-based.

   procedure Run_PCM
     (Rate       : Positive;
      Count      : Positive;
      Carrier_Hz : DSP.Real);
   --  Samples 0 .. Count-1 were stored with Put_PCM.

   function Source_Length return Natural;
   function Source_Character (Index : Positive) return Character;

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

   function Live_Begin return Natural;
   --  Arms the built-in 10 s demo for one play-through. Returns how many
   --  STFT hops that take is (every hop, no stride). Markers are cleared
   --  and the waterfall starts empty. The one-shot path is Run.

   function Live_Step return Integer;
   --  Computes the next hop in Ada: Hann STFT, one waterfall row, the
   --  carrier level, and the on/off edges of the track so far. Returns
   --  the 0-based frame just stored, or -1 when the take is finished
   --  or Begin was not called.

   function Live_Index return Integer;
   --  Last frame Live_Step stored, or -1 before the first hop.

   function Live_Total return Natural;
   --  Frame count from the latest Live_Begin, otherwise 0.
end Analysis;
