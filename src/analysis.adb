with Demo_Signal;
with DSP.Window;
with DSP.Magnitude;
with DSP.Peaks;
with DSP.STFT;
with DSP.Carrier;
with Ada.Numerics;

package body Analysis is
   FFT_N  : constant Positive := 4_096;
   STFT_N : constant Positive := 1_024;
   Hop    : constant Positive := STFT_N / 4;
   FMax   : constant DSP.Real := 1_000.0;

   Signal   : DSP.Real_Array (0 .. Demo_Signal.Sample_Count - 1);
   Win_F    : DSP.Real_Array (0 .. FFT_N - 1);
   Win_S    : DSP.Real_Array (0 .. STFT_N - 1);
   Power    : DSP.Real_Array (0 .. FFT_N / 2);
   Spec     : DSP.Real_Array (0 .. FFT_N / 2);
   Mag_Buf  : DSP.Real_Array (0 .. FFT_N / 2);
   WF       : DSP.STFT.Image;
   Track    : DSP.STFT.Level_List;
   TL_T     : DSP.Real_Array (0 .. DSP.STFT.Max_Rows - 1);
   TL_DB    : DSP.Real_Array (0 .. DSP.STFT.Max_Rows - 1);
   TL_On    : array (0 .. DSP.STFT.Max_Rows - 1) of Boolean;
   Marks    : DSP.Peaks.Peak_List;
   Mark_Car : array (1 .. DSP.Peaks.Max_Peaks) of Boolean;
   Edges_V  : DSP.Carrier.Edge_List;

   Ready_Flag : Boolean := False;
   Tone_Flag  : Boolean := False;
   Tone_P     : DSP.Real := 0.0;
   Tone_S     : DSP.Real := 0.0;
   Tone_F     : DSP.Real := 0.0;
   Avg_N      : Natural := 0;
   Bins_N     : Natural := 0;
   Df_V       : DSP.Real := 0.0;
   Sdf_V      : DSP.Real := 0.0;
   Bin_V      : Natural := 0;
   Floor_V    : DSP.Real := -200.0;
   Thr_V      : DSP.Real := 0.0;
   Lo_V       : DSP.Real := 0.0;
   Hi_V       : DSP.Real := 0.0;
   Mark_N     : Natural := 0;
   Rows_N     : Natural := 0;
   Cols_N     : Natural := 0;
   Frames_N   : Natural := 0;
   Edge_N     : Natural := 0;

   procedure Check_Tone is
      Freq : constant DSP.Real :=
        32.0 * DSP.Real (Demo_Signal.Rate) / DSP.Real (FFT_N);
   begin
      for I in 0 .. FFT_N - 1 loop
         Signal (I) := DSP.Sin
           (2.0 * Ada.Numerics.Pi * Freq * DSP.Real (I)
            / DSP.Real (Demo_Signal.Rate));
      end loop;
      DSP.Window.Hann (Win_F);
      DSP.Magnitude.Frame (Signal, 0, Win_F, Mag_Buf);
      Tone_P := Mag_Buf (32);
      Tone_S := Mag_Buf (31);
      Tone_F := Mag_Buf (64);
      Tone_Flag := abs (Tone_P - 1.0) < 1.0E-3
        and then abs (Tone_S - 0.5) < 1.0E-2
        and then abs (Mag_Buf (33) - 0.5) < 1.0E-2
        and then abs (Tone_F) < 1.0E-2;
   end Check_Tone;

   procedure Run is
      Half  : constant Natural := FFT_N / 2;
      Pos   : Natural := 0;
      Acc   : Natural := 0;
      Sum   : DSP.Real := 0.0;
      K_Max : Natural;
      Found : Natural;
   begin
      Ready_Flag := False;
      Check_Tone;

      Demo_Signal.Generate (Signal);
      DSP.Window.Hann (Win_F);
      DSP.Window.Hann (Win_S);

      for K in Power'Range loop
         Power (K) := 0.0;
      end loop;

      Df_V := DSP.Real (Demo_Signal.Rate) / DSP.Real (FFT_N);
      K_Max := Natural'Min (Half, Natural (FMax / Df_V));

      loop
         DSP.Magnitude.Frame (Signal, Pos, Win_F, Mag_Buf);
         for K in Power'Range loop
            Power (K) := Power (K) + Mag_Buf (K) * Mag_Buf (K);
         end loop;
         Acc := Acc + 1;
         exit when Pos + FFT_N >= Signal'Length;
         Pos := Pos + Half;
      end loop;

      for K in Power'Range loop
         Spec (K) := DSP.To_DBFS (DSP.Sqrt (Power (K) / DSP.Real (Acc)));
      end loop;

      for K in 1 .. K_Max loop
         Sum := Sum + Spec (K);
      end loop;
      Floor_V := Sum / DSP.Real (Natural'Max (1, K_Max));
      Avg_N := Acc;
      Bins_N := K_Max + 1;

      DSP.Peaks.Find (Spec (0 .. K_Max), Df_V, Floor_V, Marks, Found);
      Mark_N := Found;
      for I in Marks'Range loop
         Mark_Car (I) := I <= Found
           and then abs (Marks (I).F - Demo_Signal.Carrier_Hz) < 3.0 * Df_V;
      end loop;

      DSP.STFT.Build
        (S           => Signal,
         Win         => Win_S,
         Hop         => Hop,
         Rate        => Demo_Signal.Rate,
         F_Max       => FMax,
         Carrier_Hz  => Demo_Signal.Carrier_Hz,
         WF          => WF,
         Rows        => Rows_N,
         Cols        => Cols_N,
         Level       => Track,
         Frames      => Frames_N,
         Df          => Sdf_V,
         Carrier_Bin => Bin_V);

      if Frames_N > 0 then
         DSP.Carrier.Detect
           (Level     => Track (0 .. Frames_N - 1),
            Hop       => Hop,
            Rate      => Demo_Signal.Rate,
            Window_N  => STFT_N,
            Threshold => Thr_V,
            Lo        => Lo_V,
            Hi        => Hi_V,
            Edges     => Edges_V,
            Count     => Edge_N);
         for Fr in 0 .. Frames_N - 1 loop
            TL_T (Fr) := DSP.Carrier.Frame_Time
              (Fr, Hop, Demo_Signal.Rate, STFT_N);
            TL_DB (Fr) := Track (Fr);
            TL_On (Fr) := Track (Fr) > Thr_V;
         end loop;
      else
         Thr_V := 0.0;
         Lo_V := 0.0;
         Hi_V := 0.0;
         Edge_N := 0;
      end if;

      Ready_Flag := True;
   end Run;

   function Ready return Boolean is (Ready_Flag);
   function Tone_OK return Boolean is (Tone_Flag);
   function Tone_Peak return DSP.Real is (Tone_P);
   function Tone_Side return DSP.Real is (Tone_S);
   function Tone_Far return DSP.Real is (Tone_F);

   function Sample_Rate return Positive is (Demo_Signal.Rate);
   function Fft_Size return Positive is (FFT_N);
   function Stft_Size return Positive is (STFT_N);
   function Hop_Size return Positive is (Hop);
   function Avg_Count return Natural is (Avg_N);
   function Spec_Bins return Natural is (Bins_N);
   function Df return DSP.Real is (Df_V);
   function Sdf return DSP.Real is (Sdf_V);
   function F_Max return DSP.Real is (FMax);
   function Carrier_Hz return DSP.Real is (Demo_Signal.Carrier_Hz);
   function Carrier_Bin return Natural is (Bin_V);
   function Duration return DSP.Real is
     (DSP.Real (Demo_Signal.Sample_Count) / DSP.Real (Demo_Signal.Rate));
   function Floor_DB return DSP.Real is (Floor_V);
   function Threshold_DB return DSP.Real is (Thr_V);
   function Lo_DB return DSP.Real is (Lo_V);
   function Hi_DB return DSP.Real is (Hi_V);
   function Rbw return DSP.Real is (1.5 * Df_V);

   function Spec_DB (K : Natural) return DSP.Real is
     (if Ready_Flag and then K <= FFT_N / 2 then Spec (K) else -200.0);

   function Marker_Count return Natural is (Mark_N);

   function Marker_Hz (I : Positive) return DSP.Real is
     (if Ready_Flag and then I <= Mark_N then Marks (I).F else 0.0);

   function Marker_DB (I : Positive) return DSP.Real is
     (if Ready_Flag and then I <= Mark_N then Marks (I).D else -200.0);

   function Marker_Is_Carrier (I : Positive) return Boolean is
     (Ready_Flag and then I <= Mark_N and then Mark_Car (I));

   function Waterfall_Rows return Natural is (Rows_N);
   function Waterfall_Cols return Natural is (Cols_N);

   function Waterfall (Row, Col : Natural) return Natural is
   begin
      if Ready_Flag
        and then Row < Rows_N
        and then Col < Cols_N
      then
         return Natural (WF (Row, Col));
      end if;
      return 0;
   end Waterfall;

   function Timeline_Count return Natural is (Frames_N);

   function Timeline_T (I : Natural) return DSP.Real is
     (if Ready_Flag and then I < Frames_N then TL_T (I) else 0.0);

   function Timeline_DB (I : Natural) return DSP.Real is
     (if Ready_Flag and then I < Frames_N then TL_DB (I) else -200.0);

   function Timeline_On (I : Natural) return Boolean is
     (Ready_Flag and then I < Frames_N and then TL_On (I));

   function Edge_Count return Natural is (Edge_N);

   function Edge_On (I : Positive) return DSP.Real is
     (if Ready_Flag and then I <= Edge_N then Edges_V (I).T0 else 0.0);

   function Edge_Off (I : Positive) return DSP.Real is
     (if Ready_Flag and then I <= Edge_N then Edges_V (I).T1 else 0.0);
end Analysis;
