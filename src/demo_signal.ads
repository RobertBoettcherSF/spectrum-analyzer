with DSP;

--  The item-1 demonstration waveform.
--  10 s at 8 kHz: 50 Hz mains at amplitude 0.5, harmonics at 150 / 250 /
--  350 / 100 Hz, a little uniform noise, and a 216.67 Hz ripple-control
--  carrier. The carrier is keyed by a 0.5 s start pulse at t = 0.5 s and
--  then by 16 bits of 0.5 s starting at t = 1.5 s. A '1' turns the carrier on.
package Demo_Signal is
   Rate         : constant Positive := 8_000;
   Sample_Count : constant Positive := 80_000;
   Telegram     : constant String := "1011001110100101";
   Carrier_Hz   : constant Long_Float := 216.67;

   Description : constant String :=
     "DEMO: 50 Hz mains + harmonics + noise + 216.67 Hz ripple telegram "
     & "(start pulse + bits " & Telegram & ")";

   procedure Generate (S : out DSP.Real_Array);
   --  S'Length must be Sample_Count. Sample 0 is t = 0.
end Demo_Signal;
