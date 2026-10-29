--  Short-time Fourier transform used by the waterfall and the carrier track.
--  Each hop is one call to DSP.Magnitude. Waterfall cells are quantised
--  to 0 .. 99 over the dBFS range -120 .. 0, which is what the page paints.
--  The carrier column is not quantised: it stays in dBFS for the edge detector.
package DSP.STFT is
   --  2048 hops cover the longest accepted PCM buffer (524288 samples,
   --  1024-point window, hop 256 is 2045 frames). The demo uses 309.
   Max_Rows : constant := 2_048;
   Max_Cols : constant := 513;

   type Image is array (0 .. Max_Rows - 1, 0 .. Max_Cols - 1) of Integer;
   subtype Level_List is Real_Array (0 .. Max_Rows - 1);

   function Quantize (A : Real) return Integer;
   --  Waterfall cell, 0 .. 99, for a linear magnitude over -120 .. 0 dBFS.

   function Count_Frames
     (Length : Natural; Window, Hop : Positive) return Natural;
   --  Hops Build will take, capped at Max_Rows. A take shorter than
   --  Window is still one frame.

   procedure Measure_Frame
     (S           : Real_Array;
      Start       : Natural;
      Win         : Real_Array;
      Rate        : Positive;
      F_Max       : Real;
      Carrier_Hz  : Real;
      Mag         : out Real_Array;
      Cols        : out Natural;
      Df          : out Real;
      Carrier_Bin : out Natural;
      Level       : out Real);
   --  One windowed hop. Mag'Length must be at least Win'Length / 2 + 1
   --  and Mag'First is the DC bin. Cols counts bins from 0 through F_Max.
   --  Level is the carrier in dBFS (nearest bin and its two neighbours).
   --  Win'Length must be a power of two, at most 1024; otherwise Cols is
   --  0 and Level is -200.

   procedure Build
     (S           : Real_Array;
      Win         : Real_Array;
      Hop         : Positive;
      Rate        : Positive;
      F_Max       : Real;
      Carrier_Hz  : Real;
      WF          : out Image;
      Rows        : out Natural;
      Cols        : out Natural;
      Level       : out Level_List;
      Frames      : out Natural;
      Df          : out Real;
      Carrier_Bin : out Natural);
   --  Win'Length must be a power of two, at most 1024.
   --  Frames is every hop, capped at Max_Rows. Waterfall rows are a
   --  stride of those frames, about 400 lines. Level (0 .. Frames-1)
   --  is the carrier track at every hop.
end DSP.STFT;
