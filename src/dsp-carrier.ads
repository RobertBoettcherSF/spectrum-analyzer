--  Carrier level at one STFT bin, and the on/off edges of that track.
--  The tone rarely sits on a bin centre, so the level is the strongest
--  of the nearest bin and its two neighbours. The threshold is the
--  midpoint of the track when the swing exceeds 6 dB (otherwise just
--  above the maximum, which reports the carrier as off).
--
--  SPARK proves the bin clamp, the neighbour indexes, the edge-list
--  bound and that Frame_Time's integer product does not overflow inside
--  the contracted ranges (frames ≤ 2048, hop ≤ 4096, rates the page
--  accepts). The comparison that picks the threshold is ordinary float
--  arithmetic on levels contracted to ±10_000.
package DSP.Carrier with SPARK_Mode is
   Max_Edges : constant := 32;
   --  Same cap as DSP.STFT.Max_Rows. A track longer than this is outside
   --  the proof; the pipeline never builds one.
   Max_Frames : constant := 2_048;

   type Edge is record
      T0, T1 : Real := 0.0;
   end record;

   type Edge_List is array (1 .. Max_Edges) of Edge;

   function Bin (Carrier_Hz, Df : Real; Last_Bin : Natural) return Natural
   with
     Global => null,
     Pre => Last_Bin <= DSP.Max_FFT / 2
       and then (Df <= 0.0
                 or else (Df >= 1.0
                          and then Carrier_Hz in -1.0e6 .. 1.0e6)),
     Post => Bin'Result <= Last_Bin;

   function Level_DB (Mag : Real_Array; K : Natural) return Real with
     Global => null,
     Post => Level_DB'Result in -80_000.0 .. 80_000.0;

   function Frame_Time
     (Frame : Natural; Hop, Rate, Window_N : Positive) return Real
   with
     Global => null,
     Pre => Frame < Max_Frames
       and then Hop <= DSP.Max_FFT
       and then Window_N <= DSP.Max_FFT;
   --  Time at the centre of frame number Frame (0-based).

   procedure Detect
     (Level     : Real_Array;
      Hop       : Positive;
      Rate      : Positive;
      Window_N  : Positive;
      Threshold : out Real;
      Lo, Hi    : out Real;
      Edges     : out Edge_List;
      Count     : out Natural)
   with
     Global => null,
     Pre => Level'Length <= Max_Frames
       and then Hop <= DSP.Max_FFT
       and then Window_N <= DSP.Max_FFT
       and then (for all V of Level => V in -10_000.0 .. 10_000.0),
     Post => Count <= Max_Edges;
   --  Level is dBFS, one sample per STFT frame, Level'First = 0.
   --  An edge is a rising crossing followed by a falling crossing.
   --  A pulse still on at the last frame is closed at that frame's time.
end DSP.Carrier;
