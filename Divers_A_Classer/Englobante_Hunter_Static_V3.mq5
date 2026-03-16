//+------------------------------------------------------------------+
//|                                     Englobante_Hunter_Static_V3.mq5 |
//+------------------------------------------------------------------+
#property copyright "Price Mechanics - Didier Le HPI réunionnais"
#property indicator_chart_window
#property indicator_plots 0

enum ENUM_TYPE_ENG {
   Classique,   
   Optimisee    
};

input group "Paramètres de détection"
input ENUM_TYPE_ENG InpType       = Optimisee; 
input int           InpMaxBars    = 2000;      

input group "Visuel"
input color         InpBullColor  = clrLime;   
input color         InpBearColor  = clrRed;    
input int           InpOffset     = 1500;      // Augmente cette valeur si ça touche encore (ex: 2000 ou 3000)
input int           InpSize       = 3;         // Taille des flèches

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
   if(prev_calculated > 0) return(rates_total);

   ArraySetAsSeries(time, true);
   ArraySetAsSeries(open, true);
   ArraySetAsSeries(high, true);
   ArraySetAsSeries(low, true);
   ArraySetAsSeries(close, true);

   ObjectsDeleteAll(0, "EH_");

   int limit = MathMin(rates_total - 2, InpMaxBars);
   int countFound = 0;

   for(int i = 1; i < limit; i++) 
   {
      bool isBull = false;
      bool isBear = false;

      // Logique HugoFX Optimisée
      if(InpType == Optimisee)
      {
         if(close[i] > open[i] && low[i] < low[i+1] && close[i] > high[i+1])
            isBull = true;
         if(close[i] < open[i] && high[i] > high[i+1] && close[i] < low[i+1])
            isBear = true;
      }
      // Logique Classique
      else 
      {
         double p_max = MathMax(open[i+1], close[i+1]);
         double p_min = MathMin(open[i+1], close[i+1]);
         if(close[i] > open[i] && open[i] < p_min && close[i] > p_max)
            isBull = true;
         if(close[i] < open[i] && open[i] > p_max && close[i] < p_min)
            isBear = true;
      }

      if(isBull || isBear)
      {
         countFound++;
         string name = "EH_" + (string)i + "_" + TimeToString(time[i]);
         
         // Calcul du prix de la flèche avec décalage
         double anchor_price = isBull ? (low[i] - InpOffset * _Point) : (high[i] + InpOffset * _Point);

         ObjectCreate(0, name, OBJ_ARROW, 0, time[i], anchor_price);
         
         // Réglage du symbole (241 = flèche vers le haut, 242 = flèche vers le bas)
         ObjectSetInteger(0, name, OBJPROP_ARROWCODE, isBull ? 241 : 242);
         ObjectSetInteger(0, name, OBJPROP_COLOR, isBull ? InpBullColor : InpBearColor);
         ObjectSetInteger(0, name, OBJPROP_WIDTH, InpSize);
         
         // --- CORRECTION POSITIONNEMENT ---
         // Pour les flèches BULL (vertes) : on l'attache par le HAUT de l'icône
         // Pour les flèches BEAR (rouges) : on l'attache par le BAS de l'icône
         ObjectSetInteger(0, name, OBJPROP_ANCHOR, isBull ? ANCHOR_TOP : ANCHOR_BOTTOM);
      }
   }

   Print("Scan XAUUSD terminé. Patterns trouvés : ", countFound);
   return(rates_total);
}
