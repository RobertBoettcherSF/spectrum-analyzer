with Analysis;
with Demo_Signal;
with Interfaces;
with System;

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
      if X <= 0.0 or else X > 2_000.0 then
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

   function Source_Len return Integer is (Demo_Signal.Description'Length);

   function Source_Char (I : Integer) return Integer is
   begin
      if I < Demo_Signal.Description'First
        or else I > Demo_Signal.Description'Last
      then
         return 0;
      end if;
      return Character'Pos (Demo_Signal.Description (I));
   end Source_Char;

   function Live_Begin return Integer is
     (Integer (Analysis.Live_Begin));

   function Live_Step return Integer is (Analysis.Live_Step);

   function Live_Index return Integer is (Analysis.Live_Index);

   function Live_Total return Integer is (Integer (Analysis.Live_Total));
end Spectrum_API;
