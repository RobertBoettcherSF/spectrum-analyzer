with Ada.Command_Line;
with Ada.Long_Float_Text_IO;
with Ada.Strings.Fixed;
with Ada.Text_IO;
with Spectrum_API;

--  Native check of the same integer API the browser calls.
--  Frequency gates are tight enough that a bin-centre snap (no parabolic
--  fit) fails. Levels are compared with the plain-Ada CLI demo.
procedure Smoke is
   use Ada.Text_IO;

   Failed : Boolean := False;

   function T (N : Integer) return String is
     (Ada.Strings.Fixed.Trim (Integer'Image (N), Ada.Strings.Both));

   procedure Line (Label : String; N : Integer) is
   begin
      Put_Line (Label & " " & T (N));
   end Line;

   procedure Need (Cond : Boolean; What : String) is
   begin
      if Cond then
         Put_Line ("  ok  " & What);
      else
         Put_Line ("FAIL  " & What);
         Failed := True;
      end if;
   end Need;

   function Peak
     (Hz : Long_Float; Tol_Hz : Long_Float; Lo, Hi : Integer) return Boolean
   is
      Target : constant Integer := Integer (Long_Float'Rounding (Hz * 1.0E6));
      Tol    : constant Integer := Integer (Long_Float'Rounding (Tol_Hz * 1.0E6));
   begin
      for I in 1 .. Spectrum_API.Markers loop
         if abs (Spectrum_API.Marker_UHz (I) - Target) <= Tol
           and then Spectrum_API.Marker_DB10 (I) in Lo .. Hi
         then
            return True;
         end if;
      end loop;
      return False;
   end Peak;

   function Covers (At_S : Long_Float) return Boolean is
      US : constant Integer := Integer (Long_Float'Rounding (At_S * 1.0E6));
   begin
      for I in 1 .. Spectrum_API.Edges loop
         if Spectrum_API.Edge_On_US (I) <= US
           and then Spectrum_API.Edge_Off_US (I) >= US
         then
            return True;
         end if;
      end loop;
      return False;
   end Covers;

   procedure Put_Fixed (X : Long_Float; Aft : Natural) is
   begin
      Ada.Long_Float_Text_IO.Put (X, Fore => 1, Aft => Aft, Exp => 0);
   end Put_Fixed;
begin
   Spectrum_API.Analyze;

   Put_Line ("tone peak/side/far ppm "
     & T (Spectrum_API.Tone_Peak_PPM) & " "
     & T (Spectrum_API.Tone_Side_PPM) & " "
     & T (Spectrum_API.Tone_Far_PPM));
   Line ("rate", Spectrum_API.Rate);
   Line ("fft", Spectrum_API.Fft_N);
   Line ("stft", Spectrum_API.Stft_N);
   Line ("hop", Spectrum_API.Hop);
   Line ("avg", Spectrum_API.Avg_Count);
   Line ("bins", Spectrum_API.Spec_Bins);
   Line ("df_uhz", Spectrum_API.Df_UHz);
   Line ("sdf_uhz", Spectrum_API.Sdf_UHz);
   Line ("rbw_uhz", Spectrum_API.Rbw_UHz);
   Line ("carrier_bin", Spectrum_API.Carrier_Bin);
   Line ("floor_db10", Spectrum_API.Floor_DB10);
   Line ("thr_db10", Spectrum_API.Thr_DB10);
   Line ("lo_db10", Spectrum_API.Lo_DB10);
   Line ("hi_db10", Spectrum_API.Hi_DB10);
   Line ("rows", Spectrum_API.Wf_Rows);
   Line ("cols", Spectrum_API.Wf_Cols);
   Line ("frames", Spectrum_API.Tl_Count);
   Line ("markers", Spectrum_API.Markers);
   Line ("edges", Spectrum_API.Edges);

   for I in 1 .. Spectrum_API.Markers loop
      Put ("  M" & T (I) & " ");
      Put_Fixed (Long_Float (Spectrum_API.Marker_UHz (I)) / 1.0E6, 2);
      Put (" Hz ");
      Put_Fixed (Long_Float (Spectrum_API.Marker_DB10 (I)) / 10.0, 1);
      if Spectrum_API.Marker_Carrier (I) = 1 then
         Put ("  <- CARRIER");
      end if;
      New_Line;
   end loop;

   for I in 1 .. Spectrum_API.Edges loop
      Put ("  ON ");
      Put_Fixed (Long_Float (Spectrum_API.Edge_On_US (I)) / 1.0E6, 2);
      Put (" s .. ");
      Put_Fixed (Long_Float (Spectrum_API.Edge_Off_US (I)) / 1.0E6, 2);
      Put_Line (" s");
   end loop;

   Need (Spectrum_API.Tone_OK = 1, "bin-centred Hann sine is 0 dBFS");
   Need (Spectrum_API.Tone_Peak_PPM in 999_000 .. 1_001_000, "tone peak ~ 1");
   Need (Spectrum_API.Tone_Side_PPM in 490_000 .. 510_000, "Hann shoulder ~ 0.5");
   Need (abs (Spectrum_API.Tone_Far_PPM) < 10_000, "far bin ~ 0");

   Need (Spectrum_API.Rate = 8_000, "sample rate 8000");
   Need (Spectrum_API.Fft_N = 4_096, "FFT 4096");
   Need (Spectrum_API.Stft_N = 1_024, "STFT 1024");
   Need (Spectrum_API.Hop = 256, "hop 256");
   Need (Spectrum_API.Avg_Count = 39, "39 averaged frames");
   Need (Spectrum_API.Spec_Bins = 513, "spectrum bins through 1 kHz");
   Need (Spectrum_API.Wf_Rows = 309, "waterfall rows");
   Need (Spectrum_API.Wf_Cols = 129, "waterfall columns");
   Need (Spectrum_API.Tl_Count = 309, "timeline frames");
   Need (Spectrum_API.Carrier_Bin = 28, "carrier bin 28 (218.75 Hz)");
   Need (Spectrum_API.Duration_US = 10_000_000, "10.000 s");
   Need (Spectrum_API.Rbw_UHz in 2_920_000 .. 2_940_000, "RBW 2.93 Hz");

   Need (Spectrum_API.Markers = 6, "six markers");
   Need (Peak (50.00, 0.20, -70, -50), "50 Hz near -5.9 dBFS");
   Need (Peak (100.00, 0.30, -520, -400), "100 Hz near -46 dBFS");
   Need (Peak (150.00, 0.20, -310, -250), "150 Hz near -28 dBFS");
   Need (Peak (216.67, 0.40, -520, -380), "216.67 Hz carrier peak");
   Need (Peak (250.00, 0.20, -360, -280), "250 Hz near -32 dBFS");
   Need (Peak (350.00, 0.20, -450, -360), "350 Hz near -40 dBFS");

   Need (Spectrum_API.Marker_Carrier (1) = 0, "M1 is not the carrier");
   declare
      Hits : Natural := 0;
   begin
      for I in 1 .. Spectrum_API.Markers loop
         if Spectrum_API.Marker_Carrier (I) = 1 then
            Hits := Hits + 1;
         end if;
      end loop;
      Need (Hits = 1, "exactly one carrier marker");
   end;

   Need (Spectrum_API.Edges = 7, "seven carrier pulses");
   Need (Spectrum_API.Edge_On_US (1) in 300_000 .. 700_000,
         "first pulse opens near 0.5 s");
   Need (Covers (0.70), "start pulse covers 0.70 s");
   Need (Covers (1.70), "bit 1 covers 1.70 s");
   Need (Covers (3.00), "merged 11 covers 3.00 s");
   Need (Covers (5.20), "merged 111 covers 5.20 s");
   Need (Covers (6.75), "bit covers 6.75 s");
   Need (Covers (8.20), "bit covers 8.20 s");
   Need (Covers (9.20), "last 1 covers 9.20 s");
   Need (not Covers (1.20), "gap after the start pulse");
   Need (not Covers (4.10), "gap before the long 111");
   Need (Spectrum_API.Thr_DB10 in -800 .. -450, "threshold between off and on");
   Need (Spectrum_API.Hi_DB10 > Spectrum_API.Thr_DB10, "on level above threshold");
   Need (Spectrum_API.Lo_DB10 < Spectrum_API.Thr_DB10, "off level below threshold");

   declare
      Saved_Wf  : constant Integer := Spectrum_API.Wf (100, 28);
      Saved_Tl  : constant Integer := Spectrum_API.Tl_DB10 (40);
      Saved_Thr : constant Integer := Spectrum_API.Thr_DB10;
      Saved_E   : constant Integer := Spectrum_API.Edges;
      Saved_On  : constant Integer := Spectrum_API.Edge_On_US (1);
      Saved_Off : constant Integer :=
        Spectrum_API.Edge_Off_US (Spectrum_API.Edges);
      On_At     : Integer := -1;
      Off_At    : Integer := -1;
      Total     : Integer;
      Step_I    : Integer;
      Last_I    : Integer := -1;
      On_Spec   : Integer := -2_000;
      Off_Spec  : Integer := -2_000;
   begin
      for I in 0 .. Spectrum_API.Tl_Count - 1 loop
         if On_At < 0 and then Spectrum_API.Tl_On (I) = 1 then
            On_At := I;
         end if;
         if On_At >= 0 and then I > On_At + 5
           and then Spectrum_API.Tl_On (I) = 0
         then
            Off_At := I;
            exit;
         end if;
      end loop;
      Need (On_At >= 0 and then Off_At > On_At,
            "an on hop and a later off hop");

      Total := Spectrum_API.Live_Begin;
      Need (Total = 309, "live begin is 309 hops");
      Need (Spectrum_API.Live_Index = -1, "live index before the first hop");
      Need (Spectrum_API.Markers = 0, "streaming clears the averaged markers");
      Need (Spectrum_API.Live_Step = 0, "first hop is frame 0");
      loop
         Step_I := Spectrum_API.Live_Step;
         exit when Step_I < 0;
         if Step_I = On_At then
            On_Spec := Spectrum_API.Spec_DB10 (Spectrum_API.Carrier_Bin);
         elsif Step_I = Off_At then
            Off_Spec := Spectrum_API.Spec_DB10 (Spectrum_API.Carrier_Bin);
         end if;
         Last_I := Step_I;
      end loop;

      Need (Last_I = 308, "live plays every hop");
      Need (Spectrum_API.Live_Step = -1, "a step past the end stops");
      Need (Spectrum_API.Live_Index = 308, "live index is the last hop");
      Need (On_Spec > Off_Spec + 60,
            "live spectrum falls when the carrier drops");
      Need (Spectrum_API.Wf_Rows = 309, "live waterfall has every hop");
      Need (Spectrum_API.Wf_Cols = 129, "live waterfall columns");
      Need (Spectrum_API.Spec_Bins = 129, "live spectrum is one STFT frame");
      Need (Spectrum_API.Wf (100, 28) = Saved_Wf,
            "live waterfall matches the one-shot");
      Need (Spectrum_API.Tl_DB10 (40) = Saved_Tl,
            "live carrier level matches the one-shot");
      Need (Spectrum_API.Tl_On (On_At) = 1, "that on hop is still on");
      Need (Spectrum_API.Tl_On (Off_At) = 0, "that off hop is still off");
      Need (Spectrum_API.Edges = Saved_E, "live edges match the one-shot");
      Need (Spectrum_API.Edge_On_US (1) = Saved_On, "live first edge");
      Need (Spectrum_API.Edge_Off_US (Spectrum_API.Edges) = Saved_Off,
            "live last edge");
      Need (Spectrum_API.Thr_DB10 = Saved_Thr, "live threshold matches");
      Need (Spectrum_API.Tone_OK = 1, "tone check still holds after streaming");
   end;

   if Failed then
      Ada.Command_Line.Set_Exit_Status (Ada.Command_Line.Failure);
      Put_Line ("SMOKE FAILED");
   else
      Put_Line ("SMOKE PASSED");
   end if;
end Smoke;
