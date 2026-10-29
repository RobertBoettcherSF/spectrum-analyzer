--  Short-time Fourier transform used by the waterfall and the carrier track.
--  Each hop is one call to DSP.Magnitude. Waterfall cells are quantised
--  to 0 .. 99 over the dBFS range -120 .. 0, which is what the page paints.
--  The carrier column is not quantised: it stays in dBFS for the edge detector.
package DSP.STFT is
   Max_Rows : constant := 512;
   Max_Cols : constant := 513;

   type Image is array (0 .. Max_Rows - 1, 0 .. Max_Cols - 1) of Integer;
   subtype Level_List is Real_Array (0 .. Max_Rows - 1);

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
   --  Rows is the number of waterfall lines actually stored (at most ~400;
   --  frames are strided when there are more). Frames is every hop, and
   --  Level (0 .. Frames-1) is the carrier track at that hop.
end DSP.STFT;
