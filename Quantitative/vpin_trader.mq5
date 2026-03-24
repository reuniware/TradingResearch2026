//+------------------------------------------------------------------+
//|                                                     VPIN_EA.mq5 |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "VPIN Trading Bot - Version Active - By Didier Vx - Le HPI Réunionnais"
#property link      "https://www.mql5.com"
#property version   "9.00"
#property strict

#include <Trade\Trade.mqh>

//--- Paramètres VPIN
input double   InpBucketSize      = 500.0;    // Taille du bucket
input int      InpVpinWindow      = 20;       // Période VPIN (Réactivité)
input int      InpSigmaPeriod     = 100;      // Période volatilité
input double   InpTradeThreshold  = 0.7;      // Seuil VPIN Moyen
input double   InpInstantThreshold= 0.85;     // Seuil VPIN Instantané
input bool     InpEnableLogging   = true;     // Log CSV

//--- NOUVEAUX Paramètres de Trading
input group "Trading Settings"
input double   InpLotSize         = 0.1;      // Taille du lot
input int      InpStopLoss        = 500;      // Stop Loss en points (0 = aucun)
input int      InpTakeProfit      = 1000;     // Take Profit en points (0 = aucun)
input int      InpMagicNumber     = 123456;   // Magic Number
input bool     InpCloseOpposite   = true;     // Fermer la position opposée

//--- Globales
CTrade trade;

struct VpinBucket { double buyVolume; double sellVolume; };
VpinBucket g_buckets[]; 

double g_currentBuyVol   = 0.0;
double g_currentSellVol  = 0.0;
double g_currentTotalVol = 0.0;
double g_returns[]; 
int    g_retCount = 0; 

double g_lastVpin = 0.0;
string g_lastDirection = "En attente...";
double g_lastNetFlow = 0.0;
int    g_bucketCount = 0; 

double g_lastInstantImbalance = 0.0; 
string g_logFileName = "";

//+------------------------------------------------------------------+
//| Helpers Temps & Fichiers                                         |
//+------------------------------------------------------------------+
string GetPreciseTime()
{
   MqlTick tick;
   if(!SymbolInfoTick(_Symbol, tick)) return TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
   long ms = tick.time_msc % 1000;
   return TimeToString(tick.time, TIME_DATE|TIME_MINUTES|TIME_SECONDS) + "." + IntegerToString(ms, 3, '0');
}

void LogAlert(string type, double value, string direction, double netflow, double price)
{
   if(!InpEnableLogging) return;
   int fileHandle = FileOpen(g_logFileName, FILE_CSV|FILE_READ|FILE_WRITE|FILE_ANSI, ";");
   if(fileHandle != INVALID_HANDLE)
   {
      FileSeek(fileHandle, 0, SEEK_END);
      FileWrite(fileHandle, GetPreciseTime(), DoubleToString(price, _Digits), type, DoubleToString(value, 5), direction, DoubleToString(netflow, 2));
      FileClose(fileHandle);
   }
}

//+------------------------------------------------------------------+
//| Maths                                                            |
//+------------------------------------------------------------------+
double CalculateStdDev(double &array[], int count)
{
   if(count <= 1) return 0.0;
   double sum = 0.0; for(int i=0; i<count; i++) sum += array[i];
   double mean = sum / count;
   double sum_sq = 0.0; for(int i=0; i<count; i++) sum_sq += (array[i] - mean) * (array[i] - mean);
   return MathSqrt(sum_sq / (count - 1));
}
double NormCDF(double x)
{
   double a1 =  0.254829592; double a2 = -0.284496736; double a3 =  1.421413741;
   double a4 = -1.453152027; double a5 =  1.061405429; double p  =  0.3275911;
   int sign = 1; if(x < 0) sign = -1;
   x = MathAbs(x) / MathSqrt(2.0);
   double t = 1.0 / (1.0 + p*x);
   double y = 1.0 - (((((a5*t + a4)*t) + a3)*t + a2)*t + a1)*t * MathExp(-x*x);
   return 0.5 * (1.0 + sign * y);
}

//+------------------------------------------------------------------+
//| Gestion des Ordres (NOUVEAU)                                     |
//+------------------------------------------------------------------+
void ManagePosition(string direction)
{
   if(direction != "ACHAT (Hausse)" && direction != "VENTE (Baisse)") return;
   
   // Vérifier si on a déjà une position
   if(PositionSelect(_Symbol))
   {
      ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      
      // Si on est déjà dans la bonne direction, on ne fait rien
      if((type == POSITION_TYPE_BUY && direction == "ACHAT (Hausse)") ||
         (type == POSITION_TYPE_SELL && direction == "VENTE (Baisse)"))
      {
         return;
      }
      
      // Si on est en position inverse et qu'on doit fermer
      if(InpCloseOpposite)
      {
         trade.PositionClose(_Symbol);
      }
      else 
      {
         return; // On ne ferme pas l'opposé, donc on n'ouvre pas de nouvelle
      }
   }
   
   // Calcul SL / TP
   double sl = 0.0;
   double tp = 0.0;
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   
   if(direction == "ACHAT (Hausse)")
   {
      if(InpStopLoss > 0) sl = ask - InpStopLoss * point;
      if(InpTakeProfit > 0) tp = ask + InpTakeProfit * point;
      
      if(trade.Buy(InpLotSize, _Symbol, ask, sl, tp, "VPIN Buy Signal"))
      {
         Print("Ordre ACHAT exécuté. VPIN: ", DoubleToString(g_lastVpin, 4));
      }
   }
   else if(direction == "VENTE (Baisse)")
   {
      if(InpStopLoss > 0) sl = bid + InpStopLoss * point;
      if(InpTakeProfit > 0) tp = bid - InpTakeProfit * point;
      
      if(trade.Sell(InpLotSize, _Symbol, bid, sl, tp, "VPIN Sell Signal"))
      {
         Print("Ordre VENTE exécuté. VPIN: ", DoubleToString(g_lastVpin, 4));
      }
   }
}

//+------------------------------------------------------------------+
//| Initialisation                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Configuration du trade
   trade.SetExpertMagicNumber(InpMagicNumber);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_IOC); // Ajuster selon votre broker si nécessaire

   ArrayResize(g_buckets, InpVpinWindow);
   ArrayResize(g_returns, InpSigmaPeriod);
   g_retCount = 0;
   g_lastVpin = 0;
   
   g_logFileName = "VPIN_History_" + _Symbol + ".csv";
   
   if(!FileIsExist(g_logFileName))
   {
      int fileHandle = FileOpen(g_logFileName, FILE_CSV|FILE_WRITE|FILE_ANSI, ";");
      if(fileHandle != INVALID_HANDLE)
      {
         FileWrite(fileHandle, "Time_Precise", "Price", "Alert_Type", "Value", "Direction", "NetFlow");
         FileClose(fileHandle);
      }
   }
   
   // Init historique (inchangée pour la logique de calcul)
   MqlRates rates[];
   int total_bars = CopyRates(_Symbol, PERIOD_M1, 0, 200, rates);
   if(total_bars > 0)
   {
      for(int i = total_bars - 2; i >= 0; i--)
      {
         if(i == 0) continue;
         double priceReturn = rates[i].close - rates[i+1].close;
         if(g_retCount < InpSigmaPeriod) { g_returns[g_retCount] = priceReturn; g_retCount++; }
         else { for(int k=0; k<InpSigmaPeriod-1; k++) g_returns[k] = g_returns[k+1]; g_returns[InpSigmaPeriod-1] = priceReturn; }
         
         double volumeTick = (double)rates[i].tick_volume;
         if(g_retCount >= 10)
         {
             double sigma = CalculateStdDev(g_returns, g_retCount); if(sigma==0) sigma=0.000001;
             double sum=0; for(int s=0; s<g_retCount; s++) sum+=g_returns[s];
             double mean = sum / g_retCount;
             double z_score = (priceReturn - mean) / sigma;
             double prob_buy = NormCDF(z_score);
             
             g_currentTotalVol += volumeTick;
             g_currentBuyVol += volumeTick * prob_buy;
             g_currentSellVol += volumeTick * (1.0 - prob_buy);
             
             if(g_currentTotalVol >= InpBucketSize)
             {
                 static int bucketIdx = 0;
                 g_buckets[bucketIdx].buyVolume = g_currentBuyVol;
                 g_buckets[bucketIdx].sellVolume = g_currentSellVol;
                 bucketIdx++; if(bucketIdx >= InpVpinWindow) bucketIdx = 0;
                 g_bucketCount++;
                 
                 double surplus = g_currentTotalVol - InpBucketSize;
                 double ratioKeep = (surplus > 0 && g_currentTotalVol > 0) ? surplus / g_currentTotalVol : 0;
                 
                 g_currentBuyVol = g_currentBuyVol * ratioKeep;
                 g_currentSellVol = g_currentSellVol * ratioKeep;
                 g_currentTotalVol = surplus;
             }
         }
      }
      if(g_bucketCount >= InpVpinWindow) CalculateVpin();
   }
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| OnTick                                                           |
//+------------------------------------------------------------------+
void OnTick()
{
   MqlRates rates[];
   if(CopyRates(_Symbol, PERIOD_M1, 1, 1, rates) < 1) return;
   
   static datetime lastBarTime = 0;
   if(rates[0].time == lastBarTime) return;
   lastBarTime = rates[0].time;
   
   MqlRates prevRates[];
   if(CopyRates(_Symbol, PERIOD_M1, 2, 1, prevRates) < 1) return;
   
   double lastClose = rates[0].close;
   double prevClose = prevRates[0].close;
   double volumeTick = (double)rates[0].tick_volume; 
   double priceReturn = lastClose - prevClose;
   
   if(g_retCount < InpSigmaPeriod) { g_returns[g_retCount] = priceReturn; g_retCount++; }
   else { for(int i=0; i<InpSigmaPeriod-1; i++) g_returns[i] = g_returns[i+1]; g_returns[InpSigmaPeriod-1] = priceReturn; }
   
   if(g_retCount < 10) { Comment("VPIN: Init... ", g_retCount, "/10"); return; }

   double sigma = CalculateStdDev(g_returns, g_retCount);
   if(sigma == 0.0) sigma = 0.000001;
   double sum=0; for(int i=0; i<g_retCount; i++) sum+=g_returns[i];
   double mean = sum / g_retCount;
   
   double z_score = (priceReturn - mean) / sigma;
   double prob_buy = NormCDF(z_score);
   
   double buyVolEstimate  = volumeTick * prob_buy;
   double sellVolEstimate = volumeTick * (1.0 - prob_buy);
   
   double remainingVol = volumeTick;
   
   while(remainingVol > 0)
   {
      double spaceLeft = InpBucketSize - g_currentTotalVol;
      
      if(remainingVol >= spaceLeft)
      {
         double ratio = spaceLeft / volumeTick; 
         g_currentBuyVol  += buyVolEstimate * ratio;
         g_currentSellVol += sellVolEstimate * ratio;
         
         // Calcul flux instantané
         double instantImbalance = MathAbs(g_currentBuyVol - g_currentSellVol) / InpBucketSize;
         g_lastInstantImbalance = instantImbalance;
         
         // Sauvegarde bucket
         static int nextBucketIndex = 0;
         g_buckets[nextBucketIndex].buyVolume = g_currentBuyVol;
         g_buckets[nextBucketIndex].sellVolume = g_currentSellVol;
         
         nextBucketIndex++;
         if(nextBucketIndex >= InpVpinWindow) nextBucketIndex = 0;
         g_bucketCount++;
         
         CalculateVpin(); // <-- C'est ici que le trade est décidé
         
         remainingVol -= spaceLeft;
         g_currentBuyVol = 0;
         g_currentSellVol = 0;
         g_currentTotalVol = 0;
      }
      else
      {
         g_currentBuyVol  += buyVolEstimate;
         g_currentSellVol += sellVolEstimate;
         g_currentTotalVol += remainingVol;
         remainingVol = 0; 
      }
   }
   
   // Affichage
   string progress = "N/A";
   if(g_currentTotalVol > 0) progress = DoubleToString((g_currentTotalVol/InpBucketSize)*100, 1) + "%";
   
   // Vérifier l'état de la position pour l'affichage
   string posState = "Aucune position";
   if(PositionSelect(_Symbol)) {
      posState = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? "Position: ACHAT" : "Position: VENTE";
   }

   Comment("=== VPIN TRADING BOT (v9) ===", 
           "\nVPIN Moyen: ", DoubleToString(g_lastVpin, 4), 
           "\nFLUX INSTANT: ", DoubleToString(g_lastInstantImbalance, 4), 
           "\nDirection: ", g_lastDirection,
           "\n-------------------",
           "\nBucket Progress: ", progress,
           "\n", posState);
}

//+------------------------------------------------------------------+
//| Calcul VPIN & Trading Logic                                      |
//+------------------------------------------------------------------+
void CalculateVpin()
{
   double sumImbalance = 0.0;
   double sumNetFlow = 0.0;
   
   for(int i=0; i<InpVpinWindow; i++)
   {
      sumImbalance += MathAbs(g_buckets[i].buyVolume - g_buckets[i].sellVolume);
      sumNetFlow += (g_buckets[i].buyVolume - g_buckets[i].sellVolume);
   }
   
   double vpin = (sumImbalance / (double)InpVpinWindow) / InpBucketSize;
   
   g_lastVpin = vpin;
   g_lastNetFlow = sumNetFlow;
   
   if(sumNetFlow > 0) g_lastDirection = "ACHAT (Hausse)";
   else if(sumNetFlow < 0) g_lastDirection = "VENTE (Baisse)";
   else g_lastDirection = "NEUTRE";
   
   // --- LOGIQUE DE TRADING ---
   
   // 1. Alerte VPIN Moyen
   if(vpin > InpTradeThreshold)
   {
      MqlTick tick; SymbolInfoTick(_Symbol, tick);
      Print("SIGNAL VPIN MOYEN! Val: ", DoubleToString(vpin, 4), " Dir: ", g_lastDirection);
      LogAlert("VPIN_AVG", vpin, g_lastDirection, sumNetFlow, tick.bid);
      
      // Déclenchement Trade
      ManagePosition(g_lastDirection);
   }
   
   // 2. Alerte VPIN Instantané (Prioritaire car plus réactif)
   if(g_lastInstantImbalance > InpInstantThreshold)
   {
      MqlTick tick; SymbolInfoTick(_Symbol, tick);
      Print("SIGNAL VPIN INSTANTANE! Val: ", DoubleToString(g_lastInstantImbalance, 4), " Dir: ", g_lastDirection);
      LogAlert("VPIN_INSTANT", g_lastInstantImbalance, g_lastDirection, sumNetFlow, tick.bid);
      
      // Déclenchement Trade
      ManagePosition(g_lastDirection);
   }
}
