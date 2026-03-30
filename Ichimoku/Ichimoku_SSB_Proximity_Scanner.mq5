//+------------------------------------------------------------------+
//|                                         Ichimoku_SSB_Bounce.mq5|
//|                          Copyright 2026, T0W3RBU5T3R. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, T0W3RBU5T3R."
#property link      "https://www.mql5.com"
#property version   "1.05"

#include <Trade\Trade.mqh>

// On garde les variables globales du code original
MqlRates mql_rates[];
double ssb_buffer[];           // Senkou Span B
double tenkan_sen_buffer[];    // Non utilisé ici mais gardé pour la structure
double kijun_sen_buffer[];     // Non utilisé ici mais gardé pour la structure
double senkou_span_a_buffer[];
double chikou_span_buffer[];

int OnInit()
  {
   // Initialisation des séries comme dans l'original
   ArraySetAsSeries(mql_rates, true);
   ArraySetAsSeries(ssb_buffer, true);
   ArraySetAsSeries(tenkan_sen_buffer, true);
   ArraySetAsSeries(kijun_sen_buffer, true);
   ArraySetAsSeries(senkou_span_a_buffer, true);
   ArraySetAsSeries(chikou_span_buffer, true);

   printf("--- DÉBUT DU SCANNER SENKOU SPAN B BOUNCE ---");

   bool onlySymbolsInMarketwatch = true;
   int stotal = SymbolsTotal(onlySymbolsInMarketwatch);

   for(int sindex = 0; sindex < stotal; sindex++)
     {
      string sname = SymbolName(sindex, onlySymbolsInMarketwatch);
      CheckSSBPullback(sname);
     }

   printf("--- FIN DU SCANNER ---");
   return(INIT_SUCCEEDED);
  }

void OnTick() {}

void CheckSSBPullback(string sname)
  {
   // On récupère les 2 dernières bougies (courante et précédente)
   if(CopyRates(sname, PERIOD_CURRENT, 0, 2, mql_rates) <= 0) return;

   int tenkan_sen = 9;
   int kijun_sen = 26;
   int senkou_span_b = 52;

   int handle = iIchimoku(sname, PERIOD_CURRENT, tenkan_sen, kijun_sen, senkou_span_b);
   
   if(handle != INVALID_HANDLE)
     {
      // Récupération de la Senkou Span B (on a besoin des 2 dernières valeurs)
      // CORRECTION : Utiliser SENKOUSPANB_LINE au lieu de SENKOUSHAN_B_LINE
      if(CopyBuffer(handle, SENKOUSPANB_LINE, 0, 2, ssb_buffer) > 1)
        {
         double currentLow = mql_rates[0].low;
         double currentHigh = mql_rates[0].high;
         double currentClose = mql_rates[0].close;
         double currentOpen = mql_rates[0].open;
         double ssbCurrent = ssb_buffer[0];
         
         // --- DÉTECTION : ARRIVÉE SUR LA SSB PAR LE BAS ---
         // Le prix vient du dessous (bougie précédente sous SSB)
         // ET la bougie actuelle touche ou traverse la SSB
         bool previousBelowSSB = (mql_rates[1].high < ssb_buffer[1]);
         bool touchingFromBelow = (currentLow <= ssbCurrent && currentHigh >= ssbCurrent) ||
                                  (currentHigh >= ssbCurrent && currentLow < ssbCurrent);
         
         if(previousBelowSSB && touchingFromBelow && currentLow <= ssbCurrent)
           {
            printf(sname + " : [BAS → SSB] La bougie en cours arrive sur la Senkou Span B par le bas (Low: " + 
                   DoubleToString(currentLow, _Digits) + ", SSB: " + 
                   DoubleToString(ssbCurrent, _Digits) + ")");
           }
         
         // --- DÉTECTION : ARRIVÉE SUR LA SSB PAR LE HAUT ---
         // Le prix vient du dessus (bougie précédente au-dessus SSB)
         // ET la bougie actuelle touche ou traverse la SSB
         bool previousAboveSSB = (mql_rates[1].low > ssb_buffer[1]);
         bool touchingFromAbove = (currentLow <= ssbCurrent && currentHigh >= ssbCurrent) ||
                                  (currentLow <= ssbCurrent && currentHigh > ssbCurrent);
         
         if(previousAboveSSB && touchingFromAbove && currentHigh >= ssbCurrent)
           {
            printf(sname + " : [HAUT → SSB] La bougie en cours arrive sur la Senkou Span B par le haut (High: " + 
                   DoubleToString(currentHigh, _Digits) + ", SSB: " + 
                   DoubleToString(ssbCurrent, _Digits) + ")");
           }
        }
      
      // Nettoyage des buffers pour ce symbole
      IndicatorRelease(handle); 
     }
  }
