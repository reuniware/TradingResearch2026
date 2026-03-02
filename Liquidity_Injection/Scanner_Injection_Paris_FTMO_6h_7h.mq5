//+------------------------------------------------------------------+
//|                                Scanner_Injection_Paris_FTMO.mq5 |
//|                                  Copyright 2026, Price Mechanics |
//+------------------------------------------------------------------+
#property copyright "Price Mechanics"
#property link      "https://pricemechanics.blogspot.com"
#property version   "1.10"
#property indicator_chart_window

// --- PARAMÈTRES POUR FTMO (GMT+2) ---
input int      InpParisStart = 6;      // Heure cible Paris (Début)
input int      InpParisEnd   = 7;      // Heure cible Paris (Fin)
input int      InpOffsetFTMO = 1;      // Décalage : FTMO est à +1h de Paris
input double   InpThreshold  = 1.5;    // Sensibilité (1.5 = 50% plus fort que la moyenne)
input int      InpLookback   = 30;     // Nombre de jours à scanner
input color    InpColor      = clrLimeGreen; // Couleur de la zone

//+------------------------------------------------------------------+
//| Initialisation                                                   |
//+------------------------------------------------------------------+
int OnInit() {
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Calcul principal                                                 |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   if(rates_total < 200) return(0);

   // Déterminer où commencer le scan
   int limit = rates_total - prev_calculated;
   int bars_in_day = 1440 / (int)(PeriodSeconds()/60);
   int total_lookback = InpLookback * bars_in_day;
   int start_idx = (prev_calculated == 0) ? (rates_total - total_lookback) : (rates_total - limit);
   if(start_idx < 100) start_idx = 100;

   for(int i = start_idx; i < rates_total - 1; i++)
   {
      MqlDateTime dt;
      TimeToStruct(time[i], dt);
      
      // LOGIQUE : Si Chart=07h et Offset=1 -> Paris=06h
      int current_paris_hour = dt.hour - InpOffsetFTMO;

      // Détection de la bougie de 06:00 Paris (07:00 FTMO)
      if(current_paris_hour == InpParisStart && dt.min == 0)
      {
         int start_box = i;
         int end_box = i;
         double max_h = high[i];
         double min_l = low[i];

         // Parcourir jusqu'à 07:00 Paris (08:00 FTMO)
         for(int j = i; j < rates_total; j++)
         {
            MqlDateTime dt_j;
            TimeToStruct(time[j], dt_j);
            if((dt_j.hour - InpOffsetFTMO) >= InpParisEnd) break;
            
            if(high[j] > max_h) max_h = high[j];
            if(low[j] < min_l) min_l = low[j];
            end_box = j;
         }

         // Calcul de la moyenne des 5 heures précédentes pour comparaison
         double avg_volatility = 0;
         int bars_to_avg = 300 / (int)(PeriodSeconds()/60); // 5 heures
         int count = 0;
         for(int k = start_box - 1; k > start_box - bars_to_avg && k > 0; k--) {
            avg_volatility += (high[k] - low[k]);
            count++;
         }

         if(count > 0) {
            avg_volatility /= count;
            double current_range = max_h - min_l;

            // Si mouvement > moyenne * seuil -> INJECTION
            if(current_range > (avg_volatility * InpThreshold)) {
               string name = "Liq_" + TimeToString(time[start_box]);
               ObjectDelete(0, name);
               ObjectCreate(0, name, OBJ_RECTANGLE, 0, time[start_box], max_h, time[end_box], min_l);
               ObjectSetInteger(0, name, OBJPROP_COLOR, InpColor);
               ObjectSetInteger(0, name, OBJPROP_FILL, true);
               ObjectSetInteger(0, name, OBJPROP_BACK, true);
               
               string txt = "Txt_" + name;
               ObjectDelete(0, txt);
               ObjectCreate(0, txt, OBJ_TEXT, 0, time[start_box], max_h + (200 * _Point));
               ObjectSetString(0, txt, OBJPROP_TEXT, "INJECTION PARIS 6H");
               ObjectSetInteger(0, txt, OBJPROP_COLOR, clrWhite);
               ObjectSetInteger(0, txt, OBJPROP_FONTSIZE, 8);
            }
         }
         i = end_box; // Sauter à la fin de la fenêtre
      }
   }
   return(rates_total);
}
