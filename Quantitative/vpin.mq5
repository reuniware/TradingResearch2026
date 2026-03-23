//+------------------------------------------------------------------+
//|                                                     VPIN_EA.mq5 |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "VPIN Millionaire Trading Bot by Didier Le HPI Réunionnais"
#property link      "https://www.mql5.com"
#property version   "6.00"
#property strict

#include <Trade\Trade.mqh>

//--- Paramètres
input double   InpBucketSize   = 500.0;    // Taille du bucket (Ajustez selon l'actif)
input int      InpVpinWindow   = 50;       // Fenêtre de lissage
input int      InpSigmaPeriod  = 100;      // Période volatilité
input double   InpTradeThreshold= 0.7;     // Seuil d'alerte

//--- Globales
CTrade trade;

struct VpinBucket { double buyVolume; double sellVolume; };
VpinBucket g_buckets[]; 

double g_currentBuyVol   = 0.0;
double g_currentSellVol  = 0.0;
double g_currentTotalVol = 0.0;
double g_returns[]; 
int    g_retCount = 0; 

// Variable pour mémoriser le dernier VPIN calculé
double g_lastVpin = 0.0;
string g_lastDirection = "En attente...";
double g_lastNetFlow = 0.0;
int    g_bucketCount = 0; // Combien de buckets ont été remplis

//+------------------------------------------------------------------+
//| Fonctions Mathématiques (StdDev & CDF)                           |
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
//| Initialisation                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   ArrayResize(g_buckets, InpVpinWindow);
   ArrayResize(g_returns, InpSigmaPeriod);
   g_retCount = 0;
   g_lastVpin = 0;
   
   // Chargement historique rapide
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
             
             // Logique Bucket simplifiée pour init
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
      // Calcul initial
      if(g_bucketCount >= InpVpinWindow) CalculateVpin();
   }
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
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
   
   // Mise à jour affichage même si on attend des données
   if(g_retCount < 10)
   {
      Comment("VPIN: Initialisation... ", g_retCount, "/10 min");
      return;
   }

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
         
         static int nextBucketIndex = 0;
         g_buckets[nextBucketIndex].buyVolume = g_currentBuyVol;
         g_buckets[nextBucketIndex].sellVolume = g_currentSellVol;
         
         nextBucketIndex++;
         if(nextBucketIndex >= InpVpinWindow) nextBucketIndex = 0;
         
         g_bucketCount++;
         
         // CALCUL ET MEMORISATION DU VPIN
         CalculateVpin(); 
         
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
   
   // AFFICHAGE FINAL PERMANENT
   // On affiche le dernier VPIN calculé + la progression du bucket actuel
   string progress = "N/A";
   if(g_currentTotalVol > 0) progress = DoubleToString((g_currentTotalVol/InpBucketSize)*100, 1) + "%";
   
   Comment("=== VPIN INDICATOR ===", 
           "\nValeur: ", DoubleToString(g_lastVpin, 4), 
           "\nDirection: ", g_lastDirection,
           "\nNet Flow: ", DoubleToString(g_lastNetFlow, 0),
           "\n-------------------",
           "\nBucket Progress: ", progress,
           "\nBuckets remplis: ", g_bucketCount);
}

//+------------------------------------------------------------------+
//| Calcul VPIN (Met à jour les variables globales d'affichage)      |
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
   
   // Mémorisation pour l'affichage permanent
   g_lastVpin = vpin;
   g_lastNetFlow = sumNetFlow;
   
   if(sumNetFlow > 0) g_lastDirection = "ACHAT (Hausse)";
   else if(sumNetFlow < 0) g_lastDirection = "VENTE (Baisse)";
   else g_lastDirection = "NEUTRE";
   
   // Alerte
   if(vpin > InpTradeThreshold)
   {
      Print("ALERTE VPIN! Valeur: ", DoubleToString(vpin, 4), " Direction: ", g_lastDirection);
   }
}
