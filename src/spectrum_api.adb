with Analysis;
with Interfaces;
with System.Storage_Elements;

package body Spectrum_API is
   --  The wasm runtime's last-chance handler prints through this hook and
   --  then executes `unreachable`. Nothing is printed; the trap is enough.
   procedure Put_Exception
     (Msg  : System.Address;
      Size : Interfaces.Unsigned_32;
      Line : Interfaces.Unsigned_32)
   with Export, Convention => C, External_Name => "__gnat_put_exception";

   procedure Put_Exception
     (Msg  : System.Address;
      Size : Interfaces.Unsigned_32;
      Line : Interfaces.Unsigned_32)
   is
      pragma Unreferenced (Msg, Size, Line);
   begin
      null;
   end Put_Exception;

   function DB10 (X : Long_Float) return Integer is
   begin
      if X < -400.0 then
         return -4_000;
      elsif X > 100.0 then
         return 1_000;
      end if;
      return Integer (Long_Float'Rounding (X * 10.0));
   end DB10;

   function UHz (X : Long_Float) return Integer is
   begin
      --  2147 Hz * 1e6 still fits in a 32-bit integer. The PCM plot
      --  stops at 2 kHz, which has to be reportable.
      if X <= 0.0 or else X > 2_147.0 then
         return 0;
      end if;
      return Integer (Long_Float'Rounding (X * 1.0E6));
   end UHz;

   function US (X : Long_Float) return Integer is
   begin
      if X <= 0.0 or else X > 100.0 then
         return 0;
      end if;
      return Integer (Long_Float'Rounding (X * 1.0E6));
   end US;

   function PPM (X : Long_Float) return Integer is
   begin
      if X < -2.0 or else X > 2.0 then
         return 0;
      end if;
      return Integer (Long_Float'Rounding (X * 1.0E6));
   end PPM;

   function Flag (B : Boolean) return Integer is
     (if B then 1 else 0);

   procedure Analyze is
   begin
      Analysis.Run;
   end Analyze;

   type Sample_Buffer is
     array (0 .. Analysis.Max_Samples - 1) of Interfaces.Integer_16
     with Alignment => 8;

   PCM : Sample_Buffer;

   function PCM_Cap return Integer is (Analysis.Max_Samples);
   function PCM_Min return Integer is (Analysis.Min_Samples);
   function PCM_Min_Rate return Integer is (Analysis.Min_Rate);
   function PCM_Max_Rate return Integer is (Analysis.Max_Rate);
   function PCM_FMax_UHz return Integer is (UHz (Analysis.PCM_F_Max));

   function PCM_Ptr return Integer is
      use System.Storage_Elements;
      A : constant Integer_Address := To_Integer (PCM'Address);
   begin
      --  The page needs a wasm32 offset. On a 64-bit host the address
      --  may not fit in Integer; the native test writes via Store.
      if A > Integer_Address (Integer'Last) then
         return 0;
      end if;
      return Integer (A);
   end PCM_Ptr;

   procedure Store (Index : Integer; Value : Integer) is
   begin
      if Index < 0 or else Index >= Analysis.Max_Samples then
         return;
      end if;
      if Value < Integer (Interfaces.Integer_16'First) then
         PCM (Index) := Interfaces.Integer_16'First;
      elsif Value > Integer (Interfaces.Integer_16'Last) then
         PCM (Index) := Interfaces.Integer_16'Last;
      else
         PCM (Index) := Interfaces.Integer_16 (Value);
      end if;
   end Store;

   function Analyze_PCM (Rate, Count, Carrier_UHz : Integer) return Integer is
      Hz : Long_Float;
   begin
      if Rate < Analysis.Min_Rate or else Rate > Analysis.Max_Rate then
         return PCM_Bad_Rate;
      end if;
      if Count < Analysis.Min_Samples then
         return PCM_Too_Short;
      end if;
      if Count > Analysis.Max_Samples then
         return PCM_Too_Long;
      end if;
      if Carrier_UHz <= 0 then
         return PCM_Bad_Carrier;
      end if;
      Hz := Long_Float (Carrier_UHz) / 1.0E6;
      if Hz >= Analysis.PCM_F_Max or else Hz >= Long_Float (Rate) / 2.0 then
         return PCM_Bad_Carrier;
      end if;
      for I in 0 .. Count - 1 loop
         Analysis.Put_PCM (I, Long_Float (PCM (I)) / 32_768.0);
      end loop;
      Analysis.Run_PCM (Rate, Count, Hz);
      return PCM_OK;
   end Analyze_PCM;

   function Ready return Integer is (Flag (Analysis.Ready));
   function Tone_OK return Integer is (Flag (Analysis.Tone_OK));
   function Tone_Peak_PPM return Integer is (PPM (Analysis.Tone_Peak));
   function Tone_Side_PPM return Integer is (PPM (Analysis.Tone_Side));
   function Tone_Far_PPM return Integer is (PPM (Analysis.Tone_Far));

   function Rate return Integer is (Analysis.Sample_Rate);
   function Fft_N return Integer is (Analysis.Fft_Size);
   function Stft_N return Integer is (Analysis.Stft_Size);
   function Hop return Integer is (Analysis.Hop_Size);
   function Avg_Count return Integer is (Analysis.Avg_Count);
   function Spec_Bins return Integer is (Analysis.Spec_Bins);
   function Df_UHz return Integer is (UHz (Analysis.Df));
   function Sdf_UHz return Integer is (UHz (Analysis.Sdf));
   function Fmax_UHz return Integer is (UHz (Analysis.F_Max));
   function Carrier_UHz return Integer is (UHz (Analysis.Carrier_Hz));
   function Carrier_Bin return Integer is (Analysis.Carrier_Bin);
   function Duration_US return Integer is (US (Analysis.Duration));
   function Floor_DB10 return Integer is (DB10 (Analysis.Floor_DB));
   function Thr_DB10 return Integer is (DB10 (Analysis.Threshold_DB));
   function Lo_DB10 return Integer is (DB10 (Analysis.Lo_DB));
   function Hi_DB10 return Integer is (DB10 (Analysis.Hi_DB));
   function Rbw_UHz return Integer is (UHz (Analysis.Rbw));

   function Spec_DB10 (K : Integer) return Integer is
   begin
      if K < 0 or else K >= Analysis.Spec_Bins then
         return -2_000;
      end if;
      return DB10 (Analysis.Spec_DB (Natural (K)));
   end Spec_DB10;

   function Markers return Integer is (Analysis.Marker_Count);

   function Marker_UHz (I : Integer) return Integer is
   begin
      if I < 1 or else I > Analysis.Marker_Count then
         return 0;
      end if;
      return UHz (Analysis.Marker_Hz (Positive (I)));
   end Marker_UHz;

   function Marker_DB10 (I : Integer) return Integer is
   begin
      if I < 1 or else I > Analysis.Marker_Count then
         return -2_000;
      end if;
      return DB10 (Analysis.Marker_DB (Positive (I)));
   end Marker_DB10;

   function Marker_Carrier (I : Integer) return Integer is
   begin
      if I < 1 or else I > Analysis.Marker_Count then
         return 0;
      end if;
      return Flag (Analysis.Marker_Is_Carrier (Positive (I)));
   end Marker_Carrier;

   function Wf_Rows return Integer is (Analysis.Waterfall_Rows);
   function Wf_Cols return Integer is (Analysis.Waterfall_Cols);

   function Wf (Row, Col : Integer) return Integer is
   begin
      if Row < 0 or else Col < 0
        or else Row >= Analysis.Waterfall_Rows
        or else Col >= Analysis.Waterfall_Cols
      then
         return 0;
      end if;
      return Analysis.Waterfall (Natural (Row), Natural (Col));
   end Wf;

   function Tl_Count return Integer is (Analysis.Timeline_Count);

   function Tl_US (I : Integer) return Integer is
   begin
      if I < 0 or else I >= Analysis.Timeline_Count then
         return 0;
      end if;
      return US (Analysis.Timeline_T (Natural (I)));
   end Tl_US;

   function Tl_DB10 (I : Integer) return Integer is
   begin
      if I < 0 or else I >= Analysis.Timeline_Count then
         return -2_000;
      end if;
      return DB10 (Analysis.Timeline_DB (Natural (I)));
   end Tl_DB10;

   function Tl_On (I : Integer) return Integer is
   begin
      if I < 0 or else I >= Analysis.Timeline_Count then
         return 0;
      end if;
      return Flag (Analysis.Timeline_On (Natural (I)));
   end Tl_On;

   function Edges return Integer is (Analysis.Edge_Count);

   function Edge_On_US (I : Integer) return Integer is
   begin
      if I < 1 or else I > Analysis.Edge_Count then
         return 0;
      end if;
      return US (Analysis.Edge_On (Positive (I)));
   end Edge_On_US;

   function Edge_Off_US (I : Integer) return Integer is
   begin
      if I < 1 or else I > Analysis.Edge_Count then
         return 0;
      end if;
      return US (Analysis.Edge_Off (Positive (I)));
   end Edge_Off_US;

   function Source_Len return Integer is (Analysis.Source_Length);

   function Source_Char (I : Integer) return Integer is
   begin
      if I < 1 or else I > Analysis.Source_Length then
         return 0;
      end if;
      return Character'Pos (Analysis.Source_Character (I));
   end Source_Char;

   function Live_Begin return Integer is
     (Integer (Analysis.Live_Begin));

   function Live_Step return Integer is (Analysis.Live_Step);

   function Live_Index return Integer is (Analysis.Live_Index);

   function Live_Total return Integer is (Integer (Analysis.Live_Total));
end Spectrum_API;
