--  Carrier level at one STFT bin, and the on/off edges of that track.
--  The tone rarely sits on a bin centre, so the level is the strongest
--  of the nearest bin and its two neighbours. The threshold is the
--  midpoint of the track when the swing exceeds 6 dB (otherwise just
--  above the maximum, which reports the carrier as off).
package DSP.Carrier is
   Max_Edges : constant := 32;

   type Edge is record
      T0, T1 : Real := 0.0;
   end record;

   type Edge_List is array (1 .. Max_Edges) of Edge;

   function Bin (Carrier_Hz, Df : Real; Last_Bin : Natural) return Natural;

   function Level_DB (Mag : Real_Array; K : Natural) return Real;

   function Frame_Time
     (Frame : Natural; Hop, Rate, Window_N : Positive) return Real;
   --  Time at the centre of frame number Frame (0-based).

   procedure Detect
     (Level     : Real_Array;
      Hop       : Positive;
      Rate      : Positive;
      Window_N  : Positive;
      Threshold : out Real;
      Lo, Hi    : out Real;
      Edges     : out Edge_List;
      Count     : out Natural);
   --  Level is dBFS, one sample per STFT frame, Level'First = 0.
   --  An edge is a rising crossing followed by a falling crossing.
   --  A pulse still on at the last frame is closed at that frame's time.
end DSP.Carrier;
