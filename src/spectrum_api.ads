--  What the browser calls. Every value is an integer so the WebAssembly
--  ABI stays the same shape as murmuration-spark (C convention, i32).
--
--  Scaling:
--    *_uhz    frequency or bandwidth in microhertz (Hz * 1e6)
--    *_us     time in microseconds
--    *_db10   level in tenths of a dB (-59 means -5.9 dBFS)
--    *_ppm    linear magnitude * 1e6 (1000000 means 1.0)
--
--  Indexes: markers and edges are 1-based. Spectrum bins, waterfall
--  cells and timeline frames are 0-based. Call sa_analyze or
--  sa_analyze_pcm first.
--
--  PCM: the page writes little-endian int16 mono samples at sa_pcm_ptr
--  (sa_pcm_cap of them at most) and calls sa_analyze_pcm. Stereo is mixed
--  to mono before that write. sa_analyze_pcm returns 0, or
--  1 rate / 2 too short / 3 too long / 4 carrier.
package Spectrum_API is
   PCM_OK          : constant := 0;
   PCM_Bad_Rate    : constant := 1;
   PCM_Too_Short   : constant := 2;
   PCM_Too_Long    : constant := 3;
   PCM_Bad_Carrier : constant := 4;

   procedure Analyze
     with Export, Convention => C, External_Name => "sa_analyze";

   function Analyze_PCM (Rate, Count, Carrier_UHz : Integer) return Integer
     with Export, Convention => C, External_Name => "sa_analyze_pcm";

   function Set_Carrier (Carrier_UHz : Integer) return Integer
     with Export, Convention => C, External_Name => "sa_set_carrier";
   --  Same codes as Analyze_PCM for the carrier: 0, or 4 when the
   --  frequency is not inside the current plot and below Nyquist.
   --  Recomputes the on/off timeline already in hand. Peaks and the
   --  waterfall stay. The next live play of the demo keeps the lock.

   function PCM_Cap return Integer
     with Export, Convention => C, External_Name => "sa_pcm_cap";
   function PCM_Min return Integer
     with Export, Convention => C, External_Name => "sa_pcm_min";
   function PCM_Min_Rate return Integer
     with Export, Convention => C, External_Name => "sa_pcm_min_rate";
   function PCM_Max_Rate return Integer
     with Export, Convention => C, External_Name => "sa_pcm_max_rate";
   function PCM_FMax_UHz return Integer
     with Export, Convention => C, External_Name => "sa_pcm_fmax_uhz";
   function PCM_Ptr return Integer
     with Export, Convention => C, External_Name => "sa_pcm_ptr";

   procedure Store (Index : Integer; Value : Integer);
   --  One int16 sample, for the native smoke test. The page writes the
   --  buffer at PCM_Ptr instead.

   function Ready return Integer
     with Export, Convention => C, External_Name => "sa_ready";
   function Tone_OK return Integer
     with Export, Convention => C, External_Name => "sa_tone_ok";
   function Tone_Peak_PPM return Integer
     with Export, Convention => C, External_Name => "sa_tone_peak_ppm";
   function Tone_Side_PPM return Integer
     with Export, Convention => C, External_Name => "sa_tone_side_ppm";
   function Tone_Far_PPM return Integer
     with Export, Convention => C, External_Name => "sa_tone_far_ppm";

   function Rate return Integer
     with Export, Convention => C, External_Name => "sa_rate";
   function Fft_N return Integer
     with Export, Convention => C, External_Name => "sa_fft_n";
   function Stft_N return Integer
     with Export, Convention => C, External_Name => "sa_stft_n";
   function Hop return Integer
     with Export, Convention => C, External_Name => "sa_hop";
   function Avg_Count return Integer
     with Export, Convention => C, External_Name => "sa_avg_count";
   function Spec_Bins return Integer
     with Export, Convention => C, External_Name => "sa_spec_bins";
   function Df_UHz return Integer
     with Export, Convention => C, External_Name => "sa_df_uhz";
   function Sdf_UHz return Integer
     with Export, Convention => C, External_Name => "sa_sdf_uhz";
   function Fmax_UHz return Integer
     with Export, Convention => C, External_Name => "sa_fmax_uhz";
   function Carrier_UHz return Integer
     with Export, Convention => C, External_Name => "sa_carrier_uhz";
   function Carrier_Bin return Integer
     with Export, Convention => C, External_Name => "sa_carrier_bin";
   function Duration_US return Integer
     with Export, Convention => C, External_Name => "sa_duration_us";
   function Floor_DB10 return Integer
     with Export, Convention => C, External_Name => "sa_floor_db10";
   function Thr_DB10 return Integer
     with Export, Convention => C, External_Name => "sa_thr_db10";
   function Lo_DB10 return Integer
     with Export, Convention => C, External_Name => "sa_lo_db10";
   function Hi_DB10 return Integer
     with Export, Convention => C, External_Name => "sa_hi_db10";
   function Rbw_UHz return Integer
     with Export, Convention => C, External_Name => "sa_rbw_uhz";

   function Spec_DB10 (K : Integer) return Integer
     with Export, Convention => C, External_Name => "sa_spec_db10";
   function Markers return Integer
     with Export, Convention => C, External_Name => "sa_markers";
   function Marker_UHz (I : Integer) return Integer
     with Export, Convention => C, External_Name => "sa_marker_uhz";
   function Marker_DB10 (I : Integer) return Integer
     with Export, Convention => C, External_Name => "sa_marker_db10";
   function Marker_Carrier (I : Integer) return Integer
     with Export, Convention => C, External_Name => "sa_marker_carrier";

   function Wf_Rows return Integer
     with Export, Convention => C, External_Name => "sa_wf_rows";
   function Wf_Cols return Integer
     with Export, Convention => C, External_Name => "sa_wf_cols";
   function Wf (Row, Col : Integer) return Integer
     with Export, Convention => C, External_Name => "sa_wf";

   function Tl_Count return Integer
     with Export, Convention => C, External_Name => "sa_tl_count";
   function Tl_US (I : Integer) return Integer
     with Export, Convention => C, External_Name => "sa_tl_us";
   function Tl_DB10 (I : Integer) return Integer
     with Export, Convention => C, External_Name => "sa_tl_db10";
   function Tl_On (I : Integer) return Integer
     with Export, Convention => C, External_Name => "sa_tl_on";

   function Edges return Integer
     with Export, Convention => C, External_Name => "sa_edges";
   function Edge_On_US (I : Integer) return Integer
     with Export, Convention => C, External_Name => "sa_edge_on_us";
   function Edge_Off_US (I : Integer) return Integer
     with Export, Convention => C, External_Name => "sa_edge_off_us";

   function Source_Len return Integer
     with Export, Convention => C, External_Name => "sa_source_len";
   function Source_Char (I : Integer) return Integer
     with Export, Convention => C, External_Name => "sa_source_char";

   --  Live play of the built-in demo. sa_analyze remains the one-shot
   --  full-file path (markers, averaged spectrum, the whole waterfall).
   --  After sa_live_begin, each sa_live_step fills the same getters the
   --  page already uses: spectrum, waterfall, timeline and edges, one
   --  hop at a time. The spectrum during a take is that hop's STFT.
   function Live_Begin return Integer
     with Export, Convention => C, External_Name => "sa_live_begin";
   function Live_Step return Integer
     with Export, Convention => C, External_Name => "sa_live_step";
   function Live_Index return Integer
     with Export, Convention => C, External_Name => "sa_live_index";
   function Live_Total return Integer
     with Export, Convention => C, External_Name => "sa_live_total";
end Spectrum_API;
