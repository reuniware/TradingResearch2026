//+------------------------------------------------------------------+
//|                                         Ichimoku_Kijun_Bounce.mq5|
//|                          Copyright 2026, T0W3RBU5T3R. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, T0W3RBU5T3R."
#property link      "https://www.mql5.com"
#property version   "1.04"

#include <Trade\Trade.mqh>

// On garde les variables globales du code original
MqlRates mql_rates[];
double kijun_sen_buffer[];
double tenkan_sen_buffer[]; // Non utilisé ici mais gardé pour la structure
double senkou_span_a_buffer[];
double senkou_span_b_buffer[];
double chikou_span_buffer[];

int OnInit()
  {
   // Initialisation des séries comme dans l'original
   ArraySetAsSeries(mql_rates, true);
   ArraySetAsSeries(kijun_sen_buffer, true);
   ArraySetAsSeries(tenkan_sen_buffer, true);
   ArraySetAsSeries(senkou_span_a_buffer, true);
   ArraySetAsSeries(senkou_span_b_buffer, true);
   ArraySetAsSeries(chikou_span_buffer, true);

   printf("--- DÉBUT DU SCANNER KIJUN BOUNCE ---");

   bool onlySymbolsInMarketwatch = true;
   int stotal = SymbolsTotal(onlySymbolsInMarketwatch);

   for(int sindex = 0; sindex < stotal; sindex++)
     {
      string sname = SymbolName(sindex, onlySymbolsInMarketwatch);
      CheckKijunPullback(sname);
     }

   printf("--- FIN DU SCANNER ---");
   return(INIT_SUCCEEDED);
  }

void OnTick() {}

void CheckKijunPullback(string sname)
  {
   // On récupère les 2 dernières bougies (courante et précédente)
   if(CopyRates(sname, PERIOD_CURRENT, 0, 2, mql_rates) <= 0) return;

   int tenkan_sen = 9;
   int kijun_sen = 26;
   int senkou_span_b = 52;

   int handle = iIchimoku(sname, PERIOD_CURRENT, tenkan_sen, kijun_sen, senkou_span_b);
   
   if(handle != INVALID_HANDLE)
     {
      // Récupération de la Kijun-Sen (2 valeurs)
      if(CopyBuffer(handle, KIJUNSEN_LINE, 0, 2, kijun_sen_buffer) > 1)
        {
         double currentLow = mql_rates[0].low;
         double currentHigh = mql_rates[0].high;
         double currentClose = mql_rates[0].close;
         double currentOpen = mql_rates[0].open;
         double kijunCurrent = kijun_sen_buffer[0];
         
         // Calcul de la position de la bougie par rapport à la Kijun
         bool isBelowKijun = currentHigh < kijunCurrent;      // Bougie entièrement sous Kijun
         bool isAboveKijun = currentLow > kijunCurrent;       // Bougie entièrement au-dessus Kijun
         bool isCrossing = (currentLow <= kijunCurrent && currentHigh >= kijunCurrent); // Bougie traverse Kijun
         
         // --- DÉTECTION : ARRIVÉE SUR LA KIJUN PAR LE BAS ---
         // Le prix vient du dessous (bougie précédente sous Kijun ou en train de monter)
         // ET la bougie actuelle touche ou traverse la Kijun
         bool previousBelowKijun = (mql_rates[1].high < kijun_sen_buffer[1]);
         bool touchingFromBelow = (currentLow <= kijunCurrent && currentHigh >= kijunCurrent) ||
                                  (currentHigh >= kijunCurrent && currentLow < kijunCurrent);
         
         if(previousBelowKijun && touchingFromBelow && currentLow <= kijunCurrent)
           {
            printf(sname + " : [BAS → KIJUN] La bougie en cours arrive sur la Kijun par le bas (Low: " + 
                   DoubleToString(currentLow, _Digits) + ", Kijun: " + 
                   DoubleToString(kijunCurrent, _Digits) + ")");
           }
         
         // --- DÉTECTION : ARRIVÉE SUR LA KIJUN PAR LE HAUT ---
         // Le prix vient du dessus (bougie précédente au-dessus Kijun ou en train de descendre)
         // ET la bougie actuelle touche ou traverse la Kijun
         bool previousAboveKijun = (mql_rates[1].low > kijun_sen_buffer[1]);
         bool touchingFromAbove = (currentLow <= kijunCurrent && currentHigh >= kijunCurrent) ||
                                  (currentLow <= kijunCurrent && currentHigh > kijunCurrent);
         
         if(previousAboveKijun && touchingFromAbove && currentHigh >= kijunCurrent)
           {
            printf(sname + " : [HAUT → KIJUN] La bougie en cours arrive sur la Kijun par le haut (High: " + 
                   DoubleToString(currentHigh, _Digits) + ", Kijun: " + 
                   DoubleToString(kijunCurrent, _Digits) + ")");
           }
        }
      
      // Nettoyage des buffers pour ce symbole
      IndicatorRelease(handle); 
     }
  }
