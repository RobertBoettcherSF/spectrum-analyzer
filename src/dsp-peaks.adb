package body DSP.Peaks is
   type Raw is record
      F     : Real := 0.0;
      D     : Real := -999.0;
      Valid : Boolean := False;
   end record;

   procedure Find
     (Spectrum : Real_Array;
      Df       : Real;
      Floor_DB : Real;
      Peaks    : out Peak_List;
      Found    : out Natural)
   is
      P     : array (1 .. Max_Peaks) of Raw := (others => <>);
      Worst : Positive;
      Limit : constant Real := Floor_DB + 15.0;
   begin
      Peaks := (others => (0.0, -999.0));
      Found := 0;
      if Spectrum'Length < 5 then
         return;
      end if;

      for K in Spectrum'First + 2 .. Spectrum'Last - 2 loop
         if Spectrum (K) > Spectrum (K - 1)
           and then Spectrum (K) >= Spectrum (K + 1)
           and then Spectrum (K) > Spectrum (K - 2)
           and then Spectrum (K) >= Spectrum (K + 2)
           and then Spectrum (K) > Limit
         then
            declare
               A     : constant Real := Spectrum (K - 1);
               B     : constant Real := Spectrum (K);
               C     : constant Real := Spectrum (K + 1);
               Den   : constant Real := A - 2.0 * B + C;
               Shift : constant Real :=
                 (if Den /= 0.0 then 0.5 * (A - C) / Den else 0.0);
               Bin   : constant Natural := K - Spectrum'First;
               New_F : constant Real := (Real (Bin) + Shift) * Df;
               New_D : constant Real := B - 0.25 * (A - C) * Shift;
            begin
               Worst := 1;
               for J in P'Range loop
                  if P (J).D < P (Worst).D then
                     Worst := J;
                  end if;
               end loop;
               if not P (Worst).Valid or else New_D > P (Worst).D then
                  P (Worst) := (New_F, New_D, True);
               end if;
            end;
         end if;
      end loop;

      for I in P'Range loop
         for J in I + 1 .. P'Last loop
            if (P (J).Valid and then P (J).F < P (I).F)
              or else not P (I).Valid
            then
               declare
                  T : constant Raw := P (I);
               begin
                  P (I) := P (J);
                  P (J) := T;
               end;
            end if;
         end loop;
      end loop;

      for I in P'Range loop
         if P (I).Valid then
            Found := Found + 1;
            Peaks (Found) := (P (I).F, P (I).D);
         end if;
      end loop;
   end Find;
end DSP.Peaks;
