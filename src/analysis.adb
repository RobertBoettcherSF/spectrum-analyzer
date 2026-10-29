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

   Signal   : DSP.Real_Array (0 .. Max_Samples - 1);
   Win_F    : DSP.Real_Array (0 .. FFT_N - 1);
   Win_S    : DSP.Real_Array (0 .. STFT_N - 1);
   Power    : DSP.Real_Array (0 .. FFT_N / 2);
   Spec     : DSP.Real_Array (0 .. FFT_N / 2);
   Mag_Buf  : DSP.Real_Array (0 .. FFT_N / 2);
   Tone_Buf : DSP.Real_Array (0 .. FFT_N - 1);
   WF       : DSP.STFT.Image;
   Track    : DSP.STFT.Level_List;
   TL_T     : DSP.Real_Array (0 .. DSP.STFT.Max_Rows - 1);
   TL_DB    : DSP.Real_Array (0 .. DSP.STFT.Max_Rows - 1);
   TL_On    : array (0 .. DSP.STFT.Max_Rows - 1) of Boolean;
   Marks    : DSP.Peaks.Peak_List;
   Mark_Car : array (1 .. DSP.Peaks.Max_Peaks) of Boolean;
   Edges_V   : DSP.Carrier.Edge_List;
   Live_Spec : DSP.Real_Array (0 .. STFT_N / 2);
   Stft_Mag  : DSP.Real_Array (0 .. STFT_N / 2);

   type Kind is (Idle, Streaming, Frozen);
   Kind_Now : Kind := Idle;
   Next_Fr  : Natural := 0;
   Total_Fr : Natural := 0;

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
   Rate_V     : Positive := Demo_Signal.Rate;
   Count_V    : Positive := Demo_Signal.Sample_Count;
   Carrier_V  : DSP.Real := Demo_Signal.Carrier_Hz;
   FMax_V     : DSP.Real := FMax;
   Source_Buf : String (1 .. 160) := (others => ' ');
   Source_N   : Natural := 0;

   --  Fixed buffers only. A function that returns String, or "&",
   --  would use the secondary stack, and this runtime's allocator is
   --  not linked into the WebAssembly module.
   procedure Set_Source (Text : String) is
   begin
      Source_N := 0;
      for I in Text'Range loop
         exit when Source_N >= Source_Buf'Length;
         Source_N := Source_N + 1;
         Source_Buf (Source_N) := Text (I);
      end loop;
   end Set_Source;

   procedure Append_Char (C : Character) is
   begin
      if Source_N < Source_Buf'Length then
         Source_N := Source_N + 1;
         Source_Buf (Source_N) := C;
      end if;
   end Append_Char;

   procedure Append (Text : String) is
   begin
      for I in Text'Range loop
         Append_Char (Text (I));
      end loop;
   end Append;

   procedure Append_Digits (N : Natural) is
      Buf : String (1 .. 10) := (others => '0');
      V   : Natural := N;
      P   : Natural := Buf'Last;
   begin
      if N = 0 then
         Append_Char ('0');
         return;
      end if;
      while V > 0 and then P >= Buf'First loop
         Buf (P) := Character'Val (Character'Pos ('0') + V mod 10);
         V := V / 10;
         if V > 0 then
            P := P - 1;
         end if;
      end loop;
      for I in P .. Buf'Last loop
         Append_Char (Buf (I));
      end loop;
   end Append_Digits;

   procedure Check_Tone is
      Freq : constant DSP.Real :=
        32.0 * DSP.Real (Demo_Signal.Rate) / DSP.Real (FFT_N);
   begin
      for I in Tone_Buf'Range loop
         Tone_Buf (I) := DSP.Sin
           (2.0 * Ada.Numerics.Pi * Freq * DSP.Real (I)
            / DSP.Real (Demo_Signal.Rate));
      end loop;
      DSP.Window.Hann (Win_F);
      DSP.Magnitude.Frame (Tone_Buf, 0, Win_F, Mag_Buf);
      Tone_P := Mag_Buf (32);
      Tone_S := Mag_Buf (31);
      Tone_F := Mag_Buf (64);
      Tone_Flag := abs (Tone_P - 1.0) < 1.0E-3
        and then abs (Tone_S - 0.5) < 1.0E-2
        and then abs (Mag_Buf (33) - 0.5) < 1.0E-2
        and then abs (Tone_F) < 1.0E-2;
   end Check_Tone;

   procedure Refresh_Track (Through : Natural) is
   begin
      if Through = 0 then
         Thr_V := 0.0;
         Lo_V := 0.0;
         Hi_V := 0.0;
         Edge_N := 0;
         Frames_N := 0;
         return;
      end if;

      DSP.Carrier.Detect
        (Level     => Track (0 .. Through - 1),
         Hop       => Hop,
         Rate      => Rate_V,
         Window_N  => STFT_N,
         Threshold => Thr_V,
         Lo        => Lo_V,
         Hi        => Hi_V,
         Edges     => Edges_V,
         Count     => Edge_N);
      Frames_N := Through;
      for Fr in 0 .. Through - 1 loop
         TL_T (Fr) := DSP.Carrier.Frame_Time (Fr, Hop, Rate_V, STFT_N);
         TL_DB (Fr) := Track (Fr);
         TL_On (Fr) := Track (Fr) > Thr_V;
      end loop;
   end Refresh_Track;

   procedure Compute
     (Rate      : Positive;
      Count     : Positive;
      Carrier   : DSP.Real;
      F_Display : DSP.Real)
   is
      Half  : constant Natural := FFT_N / 2;
      Pos   : Natural := 0;
      Acc   : Natural := 0;
      Sum   : DSP.Real := 0.0;
      K_Max : Natural;
      Found : Natural;
      View  : DSP.Real_Array renames Signal (0 .. Count - 1);
   begin
      Ready_Flag := False;
      Kind_Now := Idle;
      Next_Fr := 0;
      Total_Fr := 0;
      Rate_V := Rate;
      Count_V := Count;
      Carrier_V := Carrier;
      FMax_V := F_Display;
      Check_Tone;

      DSP.Window.Hann (Win_F);
      DSP.Window.Hann (Win_S);

      for K in Power'Range loop
         Power (K) := 0.0;
      end loop;

      Df_V := DSP.Real (Rate) / DSP.Real (FFT_N);
      K_Max := Natural'Min (Half, Natural (F_Display / Df_V));

      loop
         DSP.Magnitude.Frame (View, Pos, Win_F, Mag_Buf);
         for K in Power'Range loop
            Power (K) := Power (K) + Mag_Buf (K) * Mag_Buf (K);
         end loop;
         Acc := Acc + 1;
         exit when Pos + FFT_N >= View'Length;
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
           and then abs (Marks (I).F - Carrier) < 3.0 * Df_V;
      end loop;

      DSP.STFT.Build
        (S           => View,
         Win         => Win_S,
         Hop         => Hop,
         Rate        => Rate,
         F_Max       => F_Display,
         Carrier_Hz  => Carrier,
         WF          => WF,
         Rows        => Rows_N,
         Cols        => Cols_N,
         Level       => Track,
         Frames      => Frames_N,
         Df          => Sdf_V,
         Carrier_Bin => Bin_V);

      Refresh_Track (Frames_N);
      Kind_Now := Frozen;
      Ready_Flag := True;
   end Compute;

   procedure Run is
   begin
      Demo_Signal.Generate (Signal (0 .. Demo_Signal.Sample_Count - 1));
      Set_Source (Demo_Signal.Description);
      Compute
        (Demo_Signal.Rate, Demo_Signal.Sample_Count,
         Demo_Signal.Carrier_Hz, FMax);
   end Run;

   procedure Put_PCM (Index : Natural; Amplitude : DSP.Real) is
   begin
      if Index < Max_Samples then
         Signal (Index) := Amplitude;
      end if;
   end Put_PCM;

   procedure Run_PCM
     (Rate       : Positive;
      Count      : Positive;
      Carrier_Hz : DSP.Real)
   is
      Span : DSP.Real;
   begin
      if Count > Max_Samples then
         return;
      end if;
      Span := DSP.Real'Min (PCM_F_Max, DSP.Real (Rate) / 2.0);
      Source_N := 0;
      Append ("PCM: 16-bit mono, ");
      Append_Digits (Rate);
      Append (" Hz, ");
      Append_Digits (Count);
      Append (" samples");
      Compute (Rate, Count, Carrier_Hz, Span);
   end Run_PCM;

   function Live_Begin return Natural is
      N : Natural;
   begin
      Ready_Flag := False;
      Kind_Now := Idle;
      Check_Tone;
      Demo_Signal.Generate (Signal (0 .. Demo_Signal.Sample_Count - 1));
      Set_Source (Demo_Signal.Description);
      DSP.Window.Hann (Win_S);

      N := DSP.STFT.Count_Frames (Demo_Signal.Sample_Count, STFT_N, Hop);
      Total_Fr := N;
      Next_Fr := 0;
      Rows_N := 0;
      Cols_N := 0;
      Frames_N := 0;
      Edge_N := 0;
      Mark_N := 0;
      Avg_N := 0;
      Bins_N := 0;
      Thr_V := 0.0;
      Lo_V := 0.0;
      Hi_V := 0.0;
      Floor_V := -200.0;
      Rate_V := Demo_Signal.Rate;
      Count_V := Demo_Signal.Sample_Count;
      Carrier_V := Demo_Signal.Carrier_Hz;
      FMax_V := FMax;
      for I in Mark_Car'Range loop
         Mark_Car (I) := False;
      end loop;
      for K in Live_Spec'Range loop
         Live_Spec (K) := -200.0;
      end loop;
      for I in Track'Range loop
         Track (I) := -200.0;
      end loop;
      for R in 0 .. DSP.STFT.Max_Rows - 1 loop
         for C in 0 .. DSP.STFT.Max_Cols - 1 loop
            WF (R, C) := 0;
         end loop;
      end loop;

      if N = 0 then
         return 0;
      end if;

      --  Same bin geometry Measure_Frame publishes, before the first hop.
      Df_V := DSP.Real (Demo_Signal.Rate) / DSP.Real (STFT_N);
      Sdf_V := Df_V;
      Bin_V := DSP.Carrier.Bin (Carrier_V, Df_V, STFT_N / 2);
      Cols_N := Natural'Min (STFT_N / 2, Natural (FMax / Df_V)) + 1;
      Bins_N := Cols_N;
      Kind_Now := Streaming;
      Ready_Flag := True;
      return N;
   end Live_Begin;

   function Live_Step return Integer is
      Fr   : Natural;
      Cols : Natural;
      Df   : DSP.Real;
      Bin  : Natural;
      Lv   : DSP.Real;
   begin
      if Kind_Now /= Streaming or else Next_Fr >= Total_Fr then
         return -1;
      end if;

      Fr := Next_Fr;
      DSP.STFT.Measure_Frame
        (S           => Signal (0 .. Demo_Signal.Sample_Count - 1),
         Start       => Fr * Hop,
         Win         => Win_S,
         Rate        => Demo_Signal.Rate,
         F_Max       => FMax,
         Carrier_Hz  => Demo_Signal.Carrier_Hz,
         Mag         => Stft_Mag,
         Cols        => Cols,
         Df          => Df,
         Carrier_Bin => Bin,
         Level       => Lv);
      if Cols = 0 then
         return -1;
      end if;

      Track (Fr) := Lv;
      for K in 0 .. Cols - 1 loop
         WF (Fr, K) := DSP.STFT.Quantize (Stft_Mag (K));
         Live_Spec (K) := DSP.To_DBFS (Stft_Mag (K));
      end loop;
      Rows_N := Fr + 1;
      Cols_N := Cols;
      Bins_N := Cols;
      Df_V := Df;
      Sdf_V := Df;
      Bin_V := Bin;
      Refresh_Track (Fr + 1);
      Next_Fr := Fr + 1;
      return Integer (Fr);
   end Live_Step;

   function Live_Index return Integer is
     (if Next_Fr = 0 then -1 else Integer (Next_Fr - 1));

   function Live_Total return Natural is (Total_Fr);

   function Ready return Boolean is (Ready_Flag);
   function Tone_OK return Boolean is (Tone_Flag);
   function Tone_Peak return DSP.Real is (Tone_P);
   function Tone_Side return DSP.Real is (Tone_S);
   function Tone_Far return DSP.Real is (Tone_F);

   function Sample_Rate return Positive is (Rate_V);
   function Fft_Size return Positive is (FFT_N);
   function Stft_Size return Positive is (STFT_N);
   function Hop_Size return Positive is (Hop);
   function Avg_Count return Natural is (Avg_N);
   function Spec_Bins return Natural is (Bins_N);
   function Df return DSP.Real is (Df_V);
   function Sdf return DSP.Real is (Sdf_V);
   function F_Max return DSP.Real is (FMax_V);
   function Carrier_Hz return DSP.Real is (Carrier_V);
   function Carrier_Bin return Natural is (Bin_V);
   function Duration return DSP.Real is
     (DSP.Real (Count_V) / DSP.Real (Rate_V));

   function Source_Length return Natural is (Source_N);

   function Source_Character (Index : Positive) return Character is
     (if Index <= Source_N then Source_Buf (Index) else ' ');
   function Floor_DB return DSP.Real is (Floor_V);
   function Threshold_DB return DSP.Real is (Thr_V);
   function Lo_DB return DSP.Real is (Lo_V);
   function Hi_DB return DSP.Real is (Hi_V);
   function Rbw return DSP.Real is (1.5 * Df_V);

   function Spec_DB (K : Natural) return DSP.Real is
   begin
      if not Ready_Flag then
         return -200.0;
      elsif Kind_Now = Streaming then
         if K < Bins_N and then K <= STFT_N / 2 then
            return Live_Spec (K);
         end if;
         return -200.0;
      elsif K <= FFT_N / 2 then
         return Spec (K);
      else
         return -200.0;
      end if;
   end Spec_DB;

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
