//+------------------------------------------------------------------+
//|                                          Detect_BSL_SSL_Cycle.mq5 |
//|                                    Détection cycle BSL → SSL → BSL|
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "ICT/SMC Cycle Detector"
#property version   "1.00"
#property indicator_chart_window
#property indicator_buffers 0
#property indicator_plots   0

// Paramètres d'entrée
input bool     ShowLines        = true;      // Afficher les niveaux sur le graphique
input int      LookbackBars     = 100;       // Nombre de bougies pour l'analyse
input double   MinSweepPercent  = 0.1;       // Sweep minimum en pourcentage (0.1% = ~4.8 points sur XAUUSD)
input bool     EnableAlerts     = true;      // Activer les alertes
input bool     EnablePush       = false;     // Activer les notifications push

// Variables globales
datetime lastAlertTime = 0;
double   currentBSL = 0;
double   currentSSL = 0;
double   sweepSSL_Level = 0;
datetime bslCreationTime = 0;
datetime sslCreationTime = 0;
datetime sslSweepTime = 0;
datetime pullbackConfirmTime = 0;
datetime bslSweepTime = 0;

enum ENUM_CYCLE_STATE
{
   STATE_IDLE,           // En attente
   STATE_BSL_CREATED,    // BSL créé
   STATE_SSL_SWEEP,      // SSL sweepé
   STATE_PULLBACK,       // Pullback confirmé
   STATE_CYCLE_COMPLETE  // Cycle complet (BSL sweepé)
};

ENUM_CYCLE_STATE cycleState = STATE_IDLE;

//+------------------------------------------------------------------+
//| Initialisation                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   Print("=== Cycle Detector BSL → SSL → BSL ===");
   Print("Analyse des ", LookbackBars, " dernières bougies M5");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Deinitialisation                                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   ObjectsDeleteAll(0, "CYCLE_");
   Comment("");
}

//+------------------------------------------------------------------+
//| Tick principal                                                   |
//+------------------------------------------------------------------+
void OnTick()
{
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, PERIOD_M5, 0);
   
   // Analyse à chaque nouvelle bougie M5
   if(currentBarTime != lastBarTime)
   {
      lastBarTime = currentBarTime;
      AnalyzeCycle();
   }
}

//+------------------------------------------------------------------+
//| Analyse le cycle BSL → SSL → BSL                                 |
//+------------------------------------------------------------------+
void AnalyzeCycle()
{
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_M5, 0, LookbackBars, rates);
   
   if(copied < 50) return;
   
   // Étape 1 : Identifier un BSL créé (EQH avec wick)
   int bslBar = FindBSLCreation(rates);
   
   if(bslBar >= 0)
   {
      currentBSL = rates[bslBar].high;
      bslCreationTime = rates[bslBar].time;
      
      if(cycleState < STATE_BSL_CREATED)
      {
         cycleState = STATE_BSL_CREATED;
         Print("🔵 BSL créé à ", currentBSL, " sur la bougie ", TimeToString(bslCreationTime));
         if(ShowLines) DrawHorizontalLine("BSL", currentBSL, clrBlue, "BSL");
         if(EnableAlerts) Alert("🔵 BSL créé à ", DoubleToString(currentBSL, 2));
      }
   }
   
   // Étape 2 : Après BSL créé, chercher un sweep d'un SSL préexistant
   if(cycleState >= STATE_BSL_CREATED && cycleState < STATE_SSL_SWEEP)
   {
      int sslSweepBar = FindSSLSweep(rates, bslBar);
      if(sslSweepBar >= 0)
      {
         sweepSSL_Level = rates[sslSweepBar].low;
         sslSweepTime = rates[sslSweepBar].time;
         cycleState = STATE_SSL_SWEEP;
         Print("🔴 SSL sweepé à ", sweepSSL_Level, " sur la bougie ", TimeToString(sslSweepTime));
         if(ShowLines) DrawHorizontalLine("SSL_SWEEP", sweepSSL_Level, clrRed, "SSL Sweep");
         if(EnableAlerts) Alert("🔴 SSL sweepé à ", DoubleToString(sweepSSL_Level, 2));
      }
   }
   
   // Étape 3 : Après SSL sweep, chercher un pullback réussi
   if(cycleState >= STATE_SSL_SWEEP && cycleState < STATE_PULLBACK)
   {
      int pullbackBar = FindSuccessfulPullback(rates, sslSweepTime, sweepSSL_Level);
      if(pullbackBar >= 0)
      {
         pullbackConfirmTime = rates[pullbackBar].time;
         cycleState = STATE_PULLBACK;
         Print("🟢 Pullback réussi à ", rates[pullbackBar].close, " sur la bougie ", TimeToString(pullbackConfirmTime));
         if(EnableAlerts) Alert("🟢 Pullback réussi - Entrée long envisageable");
      }
   }
   
   // Étape 4 : Après pullback, chercher le sweep du BSL
   if(cycleState >= STATE_PULLBACK && cycleState < STATE_CYCLE_COMPLETE)
   {
      int bslSweepBar = FindBSLSweep(rates, currentBSL, pullbackConfirmTime);
      if(bslSweepBar >= 0)
      {
         bslSweepTime = rates[bslSweepBar].time;
         cycleState = STATE_CYCLE_COMPLETE;
         Print("🟣 BSL sweepé à ", rates[bslSweepBar].high, " sur la bougie ", TimeToString(bslSweepTime));
         if(ShowLines) DrawHorizontalLine("BSL_SWEEP", rates[bslSweepBar].high, clrPurple, "BSL Sweep");
         
         string msg = "✅ CYCLE COMPLET : BSL créé à " + DoubleToString(currentBSL,2) + 
                      " | SSL sweep à " + DoubleToString(sweepSSL_Level,2) + 
                      " | BSL sweep à " + DoubleToString(rates[bslSweepBar].high,2);
         Print(msg);
         
         if(EnableAlerts) Alert(msg);
         if(EnablePush) SendNotification(msg);
         
         // Réinitialisation après un certain temps ou on laisse pour le prochain cycle
         ResetCycle();
      }
   }
}

//+------------------------------------------------------------------+
//| Trouve la création d'un BSL (EQH avec wick)                      |
//+------------------------------------------------------------------+
int FindBSLCreation(MqlRates &rates[])
{
   for(int i = 10; i < 50; i++)  // Évite les bougies trop récentes
   {
      // Vérifie si c'est un plus haut des 10 bougies précédentes
      bool isHigh = true;
      for(int j = 1; j <= 10; j++)
      {
         if(i+j >= ArraySize(rates)) break;
         if(rates[i].high <= rates[i+j].high)
         {
            isHigh = false;
            break;
         }
      }
      
      if(isHigh)
      {
         // Vérifie qu'il y a un wick (haut > clôture)
         double wick = rates[i].high - MathMax(rates[i].open, rates[i].close);
         double range = rates[i].high - rates[i].low;
         
         if(range > 0 && wick / range > 0.2)  // Wick > 20% de la bougie
         {
            // Vérifie que les bougies suivantes n'ont pas clôturé au-dessus
            bool noCloseAbove = true;
            for(int k = 1; k <= 5; k++)
            {
               if(i+k >= ArraySize(rates)) break;
               if(rates[i+k].close > rates[i].high)
               {
                  noCloseAbove = false;
                  break;
               }
            }
            
            if(noCloseAbove)
               return i;
         }
      }
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Trouve un sweep SSL (cassure sous un bas préexistant)           |
//+------------------------------------------------------------------+
int FindSSLSweep(MqlRates &rates[], int bslBar)
{
   // Cherche un bas significatif avant le BSL
   double prevLow = FindPreviousLow(rates, bslBar);
   if(prevLow <= 0) return -1;
   
   // Vérifie les bougies après le BSL
   for(int i = bslBar - 1; i >= 0 && i > bslBar - 30; i--)
   {
      if(rates[i].low < prevLow - prevLow * MinSweepPercent / 100)
      {
         // Vérifie que c'est bien un sweep (wick sous le niveau)
         if(rates[i].low < prevLow && rates[i].close > prevLow)
            return i;
      }
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Trouve un plus bas préexistant                                   |
//+------------------------------------------------------------------+
double FindPreviousLow(MqlRates &rates[], int startIndex)
{
   double lowest = DBL_MAX;
   for(int i = startIndex + 10; i < ArraySize(rates) && i < startIndex + 50; i++)
   {
      if(rates[i].low < lowest)
         lowest = rates[i].low;
   }
   return (lowest != DBL_MAX) ? lowest : 0;
}

//+------------------------------------------------------------------+
//| Vérifie un pullback réussi (clôture au-dessus de l'ancien support)|
//+------------------------------------------------------------------+
int FindSuccessfulPullback(MqlRates &rates[], datetime sweepTime, double sweepLevel)
{
   int startIndex = 0;
   for(int i = 0; i < ArraySize(rates); i++)
   {
      if(rates[i].time == sweepTime)
      {
         startIndex = i - 1;
         break;
      }
   }
   if(startIndex < 0) startIndex = 0;
   
   for(int i = startIndex; i >= 0 && i > startIndex - 20; i--)
   {
      // Pullback réussi si clôture > sweepLevel
      if(rates[i].close > sweepLevel)
      {
         // Vérifie que le prix est resté au-dessus pendant au moins 2 bougies
         if(i-1 >= 0 && rates[i-1].close > sweepLevel)
            return i;
      }
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Trouve le sweep du BSL                                           |
//+------------------------------------------------------------------+
int FindBSLSweep(MqlRates &rates[], double bslLevel, datetime pullbackTime)
{
   int startIndex = 0;
   for(int i = 0; i < ArraySize(rates); i++)
   {
      if(rates[i].time == pullbackTime)
      {
         startIndex = i - 1;
         break;
      }
   }
   if(startIndex < 0) startIndex = 0;
   
   for(int i = startIndex; i >= 0 && i > startIndex - 30; i--)
   {
      if(rates[i].high > bslLevel)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Affiche une ligne horizontale                                    |
//+------------------------------------------------------------------+
void DrawHorizontalLine(string name, double price, color clr, string label)
{
   string objName = "CYCLE_" + name;
   if(ObjectFind(0, objName) < 0)
   {
      ObjectCreate(0, objName, OBJ_HLINE, 0, 0, price);
      ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, objName, OBJPROP_WIDTH, 1);
      ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
      
      string textName = objName + "_TXT";
      ObjectCreate(0, textName, OBJ_TEXT, 0, TimeCurrent(), price);
      ObjectSetString(0, textName, OBJPROP_TEXT, label + " " + DoubleToString(price, 2));
      ObjectSetInteger(0, textName, OBJPROP_COLOR, clr);
      ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 9);
   }
}

//+------------------------------------------------------------------+
//| Réinitialise le cycle après un certain temps                     |
//+------------------------------------------------------------------+
void ResetCycle()
{
   // On réinitialise après 30 minutes pour éviter les doublons
   static datetime lastReset = 0;
   if(TimeCurrent() - lastReset > 1800)
   {
      cycleState = STATE_IDLE;
      lastReset = TimeCurrent();
      Print("Cycle réinitialisé");
   }
}

//+------------------------------------------------------------------+
