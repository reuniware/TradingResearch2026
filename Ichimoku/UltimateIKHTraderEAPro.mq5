//+------------------------------------------------------------------+
//|                                    UltimateIKHTraderEAPro.mq5    |
//|                                    Version corrigée v3.2         |
//+------------------------------------------------------------------+
#property copyright "Ichimoku Opportunity Hunter v3.2"
#property version   "3.20"
#property description "EA qui capture TOUS les signaux Ichimoku identifiés comme rentables"
#property description "Scanne TOUS les symboles du Market Watch"

#include <Trade/Trade.mqh>

//--- Input parameters
input group "=== PARAMÈTRES ICHIMOKU ==="
input int      InpTenkan      = 9;           
input int      InpKijun       = 26;          
input int      InpSenkou      = 52;          

input group "=== STRATÉGIES ACTIVES ==="
input bool     InpStrategyKijunHigh = true;   
input bool     InpStrategyKijunRebound = true; 
input bool     InpStrategySSBHigh = true;     
input bool     InpStrategySSBRebound = false;  

input group "=== UNITÉS DE TEMPS SURVEILLÉES ==="
input bool     InpUseH1       = true;        
input bool     InpUseH4       = true;        
input bool     InpUseD1       = true;        
input bool     InpUseW1       = true;        
input bool     InpUseMN1      = true;        

input group "=== PARAMÈTRES DE PROXIMITÉ ==="
input double   InpProximityHigh = 0.05;      
input double   InpProximityRebound = 0.01;   

input group "=== GESTION DES RISQUES ==="
input double   InpLotSize     = 0.01;        
input double   InpRiskPercent = 2.0;         
input double   InpRiskReward  = 2.0;         
input int      InpMaxSpread   = 30;          
input int      InpSlippage    = 10;          
input int      InpMaxConcurrentTrades = 5;   

input group "=== GESTION DES POSITIONS ==="
input bool     InpUseTrailing = true;        
input int      InpTrailingStart = 20;        
input int      InpTrailingStep  = 10;        
input int      InpMagicNumber = 20260331;    

input group "=== PARAMÈTRES DE BACKTEST ==="
input bool     InpPrintSignals = true;       
input bool     InpPrintSummary = true;       

//--- Structures
struct TFData
{
   int handle;
   datetime lastBarTime;
   double kijun[2];
   double ssb[2];
   double tenkan[2];
};

struct SymbolData
{
   string symbol;
   bool enabled;
   TFData tf[5];        // 0:H1, 1:H4, 2:D1, 3:W1, 4:MN1
   int digits;
   double point;
};

struct Signal
{
   string symbol;
   int tfIndex;
   string tfName;
   double price;
   double kijun;
   double diffPercent;
   int direction;
   string strategy;
   int weight;
   datetime time;
};

//--- Global variables
CTrade         Trade;
SymbolData     symbols[];
int            totalSymbols;
string         tfNames[5] = {"H1", "H4", "D1", "W1", "MN1"};
ENUM_TIMEFRAMES tfValues[5] = {PERIOD_H1, PERIOD_H4, PERIOD_D1, PERIOD_W1, PERIOD_MN1};
int            tfWeights[5] = {1, 2, 3, 4, 5};
bool           tfEnabled[5];
datetime       lastSummaryTime;
int            totalTradesCount = 0;
datetime       lastDebugPrint = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   // Configurer les UT activées
   tfEnabled[0] = InpUseH1;
   tfEnabled[1] = InpUseH4;
   tfEnabled[2] = InpUseD1;
   tfEnabled[3] = InpUseW1;
   tfEnabled[4] = InpUseMN1;
   
   // Récupérer la liste des symboles
   if(!LoadSymbols())
   {
      Print("Erreur: Aucun symbole chargé");
      return(INIT_FAILED);
   }
   
   // Initialiser le trade
   Trade.SetExpertMagicNumber(InpMagicNumber);
   Trade.SetDeviationInPoints(InpSlippage);
   Trade.SetTypeFilling(ORDER_FILLING_FOK);
   
   lastSummaryTime = 0;
   
   Print("=== EA ICHIMOKU FULL OPPORTUNITY HUNTER INITIALISÉ ===");
   Print("Symboles surveillés: ", totalSymbols);
   Print("Stratégies actives:");
   if(InpStrategyKijunHigh) Print("  - Achat sur Kijun HAUT");
   if(InpStrategyKijunRebound) Print("  - Achat sur rebond Kijun");
   if(InpStrategySSBHigh) Print("  - Achat sur SSB HAUT");
   Print("Unités de temps: H1=", InpUseH1, " H4=", InpUseH4, " D1=", InpUseD1, " W1=", InpUseW1, " MN1=", InpUseMN1);
   Print("===========================================================");
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Charger TOUS les symboles du Market Watch                        |
//+------------------------------------------------------------------+
bool LoadSymbols()
{
   // Récupérer TOUS les symboles du Market Watch
   int total = SymbolsTotal(true);  // true = uniquement les symboles visibles dans Market Watch
   
   if(total == 0)
   {
      Print("ERREUR: Aucun symbole dans le Market Watch!");
      Print("Solution: Cliquez droit sur Market Watch (Ctrl+M) -> 'Afficher tout'");
      return false;
   }
   
   Print("Détection de ", total, " symboles dans le Market Watch");
   
   // Compter d'abord les symboles valides
   int validCount = 0;
   for(int i = 0; i < total; i++)
   {
      string sym = SymbolName(i, true);
      if(SymbolSelect(sym, true))
         validCount++;
   }
   
   if(validCount == 0)
   {
      Print("ERREUR: Aucun symbole valide trouvé");
      return false;
   }
   
   // Allouer le tableau
   ArrayResize(symbols, validCount);
   int idx = 0;
   
   for(int i = 0; i < total; i++)
   {
      string sym = SymbolName(i, true);
      
      if(!SymbolSelect(sym, true))
      {
         if(InpPrintSignals)
            Print("Symbole ignoré (non sélectionnable): ", sym);
         continue;
      }
      
      symbols[idx].symbol = sym;
      symbols[idx].digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
      symbols[idx].point = SymbolInfoDouble(sym, SYMBOL_POINT);
      symbols[idx].enabled = true;
      
      bool allOK = true;
      for(int t = 0; t < 5; t++)
      {
         if(!tfEnabled[t])
         {
            symbols[idx].tf[t].handle = INVALID_HANDLE;
            continue;
         }
         
         symbols[idx].tf[t].handle = iIchimoku(sym, tfValues[t], InpTenkan, InpKijun, InpSenkou);
         if(symbols[idx].tf[t].handle == INVALID_HANDLE)
         {
            if(InpPrintSignals)
               Print("Erreur Ichimoku sur ", sym, " ", tfNames[t]);
            allOK = false;
            break;
         }
         
         symbols[idx].tf[t].lastBarTime = 0;
         symbols[idx].tf[t].kijun[0] = 0;
         symbols[idx].tf[t].kijun[1] = 0;
         symbols[idx].tf[t].ssb[0] = 0;
         symbols[idx].tf[t].ssb[1] = 0;
         symbols[idx].tf[t].tenkan[0] = 0;
         symbols[idx].tf[t].tenkan[1] = 0;
      }
      
      if(allOK)
      {
         idx++;
      }
      else
      {
         // Libérer les handles en cas d'erreur
         for(int t = 0; t < 5; t++)
         {
            if(symbols[idx].tf[t].handle != INVALID_HANDLE)
               IndicatorRelease(symbols[idx].tf[t].handle);
         }
      }
   }
   
   totalSymbols = idx;
   
   Print("Symboles chargés avec succès: ", totalSymbols);
   
   // Afficher les 10 premiers symboles pour vérification
   if(InpPrintSignals && totalSymbols > 0)
   {
      Print("Exemples de symboles chargés:");
      for(int i = 0; i < MathMin(10, totalSymbols); i++)
         Print("  ", i+1, ". ", symbols[i].symbol);
      if(totalSymbols > 10)
         Print("  ... et ", totalSymbols - 10, " autres symboles");
   }
   
   return (totalSymbols > 0);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   for(int i = 0; i < totalSymbols; i++)
   {
      for(int t = 0; t < 5; t++)
      {
         if(symbols[i].tf[t].handle != INVALID_HANDLE)
            IndicatorRelease(symbols[i].tf[t].handle);
      }
   }
   
   Print("=== EA ICHIMOKU ARRÊTÉ ===");
   Print("Trades exécutés: ", totalTradesCount);
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   // Debug: Afficher un message toutes les minutes pour confirmer que l'EA tourne
   if(InpPrintSignals && TimeCurrent() - lastDebugPrint > 60)
   {
      lastDebugPrint = TimeCurrent();
      Print("EA actif - Scan de ", totalSymbols, " symboles... Positions ouvertes: ", CountOpenPositions());
   }
   
   if(CountOpenPositions() >= InpMaxConcurrentTrades)
      return;
   
   Signal signals[];
   ArrayResize(signals, totalSymbols * 5);
   int signalCount = 0;
   
   for(int i = 0; i < totalSymbols; i++)
   {
      if(!symbols[i].enabled)
         continue;
      
      for(int t = 0; t < 5; t++)
      {
         if(!tfEnabled[t])
            continue;
         if(symbols[i].tf[t].handle == INVALID_HANDLE)
            continue;
         
         datetime currentBarTime = GetBarTime(symbols[i].symbol, tfValues[t], 0);
         if(currentBarTime == symbols[i].tf[t].lastBarTime)
            continue;
         symbols[i].tf[t].lastBarTime = currentBarTime;
         
         if(!UpdateIchimokuValues(i, t))
            continue;
         
         Signal sig = AnalyzeSignal(i, t);
         if(sig.strategy != "")
         {
            signals[signalCount] = sig;
            signalCount++;
         }
      }
   }
   
   if(signalCount == 0)
      return;
   
   SortSignals(signals, signalCount);
   
   int executed = 0;
   for(int i = 0; i < signalCount && executed < InpMaxConcurrentTrades; i++)
   {
      if(ExecuteSignal(signals[i]))
         executed++;
   }
   
   if(InpUseTrailing)
      ManageAllTrailingStops();
}

//+------------------------------------------------------------------+
//| Mettre à jour les valeurs Ichimoku                               |
//+------------------------------------------------------------------+
bool UpdateIchimokuValues(int symIdx, int tfIdx)
{
   double tempBuffer[];
   ArraySetAsSeries(tempBuffer, true);
   
   // Kijun (buffer 1)
   if(CopyBuffer(symbols[symIdx].tf[tfIdx].handle, 1, 0, 2, tempBuffer) < 2)
      return false;
   symbols[symIdx].tf[tfIdx].kijun[0] = tempBuffer[0];
   symbols[symIdx].tf[tfIdx].kijun[1] = tempBuffer[1];
   
   // SSB (buffer 3)
   if(CopyBuffer(symbols[symIdx].tf[tfIdx].handle, 3, 0, 2, tempBuffer) < 2)
      return false;
   symbols[symIdx].tf[tfIdx].ssb[0] = tempBuffer[0];
   symbols[symIdx].tf[tfIdx].ssb[1] = tempBuffer[1];
   
   // Tenkan (buffer 0)
   if(CopyBuffer(symbols[symIdx].tf[tfIdx].handle, 0, 0, 2, tempBuffer) < 2)
      return false;
   symbols[symIdx].tf[tfIdx].tenkan[0] = tempBuffer[0];
   symbols[symIdx].tf[tfIdx].tenkan[1] = tempBuffer[1];
   
   return true;
}

//+------------------------------------------------------------------+
//| Analyser les signaux                                             |
//+------------------------------------------------------------------+
Signal AnalyzeSignal(int symIdx, int tfIdx)
{
   Signal sig;
   sig.symbol = symbols[symIdx].symbol;
   sig.tfIndex = tfIdx;
   sig.tfName = tfNames[tfIdx];
   sig.strategy = "";
   sig.weight = tfWeights[tfIdx];
   sig.time = TimeCurrent();
   
   double bid = SymbolInfoDouble(sig.symbol, SYMBOL_BID);
   if(bid == 0)
      return sig;
      
   sig.price = bid;
   
   double kijun = symbols[symIdx].tf[tfIdx].kijun[1];
   if(kijun == 0)
      return sig;
      
   double diff = MathAbs(bid - kijun);
   double diffPercent = (diff / kijun) * 100.0;
   int direction = (bid > kijun) ? 1 : -1;
   
   sig.kijun = kijun;
   sig.diffPercent = diffPercent;
   sig.direction = direction;
   
   // Stratégie 1: Kijun HAUT
   if(InpStrategyKijunHigh && direction > 0 && diffPercent <= InpProximityHigh)
   {
      sig.strategy = "Kijun HAUT";
      return sig;
   }
   
   // Stratégie 2: Kijun REBOND
   if(InpStrategyKijunRebound && diffPercent <= InpProximityRebound)
   {
      sig.strategy = "Kijun REBOND";
      return sig;
   }
   
   // SSB
   double ssb = symbols[symIdx].tf[tfIdx].ssb[1];
   if(ssb == 0)
      return sig;
      
   double ssbDiff = MathAbs(bid - ssb);
   double ssbDiffPercent = (ssbDiff / ssb) * 100.0;
   int ssbDirection = (bid > ssb) ? 1 : -1;
   
   // Stratégie 3: SSB HAUT
   if(InpStrategySSBHigh && ssbDirection > 0 && ssbDiffPercent <= InpProximityHigh)
   {
      sig.strategy = "SSB HAUT";
      return sig;
   }
   
   // Stratégie 4: SSB REBOND
   if(InpStrategySSBRebound && ssbDiffPercent <= InpProximityRebound)
   {
      sig.strategy = "SSB REBOND";
      return sig;
   }
   
   return sig;
}

//+------------------------------------------------------------------+
//| Exécuter un signal                                               |
//+------------------------------------------------------------------+
bool ExecuteSignal(Signal &sig)
{
   if(PositionSelect(sig.symbol))
   {
      ulong posMagic = PositionGetInteger(POSITION_MAGIC);
      if(posMagic == InpMagicNumber)
         return false;
   }
   
   double ask = SymbolInfoDouble(sig.symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(sig.symbol, SYMBOL_BID);
   int symIdx = FindSymbolIndex(sig.symbol);
   if(symIdx < 0) return false;
   
   double spread = (ask - bid) / symbols[symIdx].point;
   if(spread > InpMaxSpread)
   {
      if(InpPrintSignals)
         Print("Spread trop élevé sur ", sig.symbol, ": ", spread, " > ", InpMaxSpread);
      return false;
   }
   
   double lot = CalculateLotSize(sig);
   if(lot <= 0) return false;
   
   double sl = sig.kijun - (sig.kijun * 0.002);
   if(sig.direction < 0)
      sl = MathMin(sig.price - (sig.price * 0.002), sig.kijun - (sig.kijun * 0.001));
   
   double risk = (sig.price - sl) * lot;
   double tp = sig.price + (risk / lot) * InpRiskReward;
   
   int digits = symbols[symIdx].digits;
   sl = NormalizeDouble(sl, digits);
   tp = NormalizeDouble(tp, digits);
   
   if(!CheckStopLevels(sig.symbol, sl, tp))
   {
      if(InpPrintSignals)
         Print("Stop levels invalides sur ", sig.symbol);
      return false;
   }
   
   if(InpPrintSignals)
   {
      Print("========================================");
      Print("🔥 SIGNAL: ", sig.symbol, " | ", sig.tfName, " | ", sig.strategy);
      Print("Prix: ", DoubleToString(sig.price, digits), " | Kijun: ", DoubleToString(sig.kijun, digits));
      Print("Écart: ", DoubleToString(sig.diffPercent, 4), "% | Lot: ", lot);
      Print("========================================");
   }
   
   string comment = StringFormat("Ichimoku %s %s", sig.tfName, sig.strategy);
   
   if(Trade.Buy(lot, sig.symbol, 0, sl, tp, comment))
   {
      totalTradesCount++;
      Print("✅ ORDRE EXÉCUTÉ sur ", sig.symbol, " - Ticket: ", Trade.ResultDeal());
      return true;
   }
   else
   {
      Print("❌ ERREUR ORDRE sur ", sig.symbol, ": ", Trade.ResultRetcodeDescription());
      return false;
   }
}

//+------------------------------------------------------------------+
//| Calculer la taille du lot                                        |
//+------------------------------------------------------------------+
double CalculateLotSize(Signal &sig)
{
   if(InpLotSize > 0)
      return InpLotSize;
   
   double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = accountBalance * (InpRiskPercent / 100.0);
   
   double slDistance = MathAbs(sig.price - sig.kijun);
   if(slDistance == 0)
      return 0.01;
   
   int symIdx = FindSymbolIndex(sig.symbol);
   if(symIdx < 0) return 0.01;
   
   double point = symbols[symIdx].point;
   double tickValue = SymbolInfoDouble(sig.symbol, SYMBOL_TRADE_TICK_VALUE);
   double slPoints = slDistance / point;
   double riskPerLot = slPoints * tickValue;
   
   if(riskPerLot <= 0) return 0.01;
   
   double lot = riskAmount / riskPerLot;
   lot = NormalizeDouble(lot, 2);
   
   double minLot = SymbolInfoDouble(sig.symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(sig.symbol, SYMBOL_VOLUME_MAX);
   
   if(lot < minLot) lot = minLot;
   if(lot > maxLot) lot = maxLot;
   
   return lot;
}

//+------------------------------------------------------------------+
//| Trier les signaux                                                |
//+------------------------------------------------------------------+
void SortSignals(Signal &arr[], int count)
{
   for(int i = 0; i < count - 1; i++)
   {
      for(int j = i + 1; j < count; j++)
      {
         if(arr[j].weight > arr[i].weight)
         {
            Signal temp = arr[i];
            arr[i] = arr[j];
            arr[j] = temp;
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Compter les positions ouvertes                                   |
//+------------------------------------------------------------------+
int CountOpenPositions()
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
            count++;
      }
   }
   return count;
}

//+------------------------------------------------------------------+
//| Trouver l'index d'un symbole                                     |
//+------------------------------------------------------------------+
int FindSymbolIndex(string symbol)
{
   for(int i = 0; i < totalSymbols; i++)
   {
      if(symbols[i].symbol == symbol)
         return i;
   }
   return -1;
}

//+------------------------------------------------------------------+
//| Vérifier les stops                                               |
//+------------------------------------------------------------------+
bool CheckStopLevels(string symbol, double sl, double tp)
{
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double stopLevel = SymbolInfoInteger(symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   
   if(bid - sl < stopLevel)
      return false;
   if(tp - bid < stopLevel && tp > bid)
      return false;
   
   return true;
}

//+------------------------------------------------------------------+
//| Gérer le trailing stop                                           |
//+------------------------------------------------------------------+
void ManageAllTrailingStops()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByTicket(PositionGetTicket(i)))
      {
         if(PositionGetInteger(POSITION_MAGIC) != InpMagicNumber)
            continue;
         
         string symbol = PositionGetString(POSITION_SYMBOL);
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double sl = PositionGetDouble(POSITION_SL);
         double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
         double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
         
         double profitPoints = (bid - openPrice) / point;
         double trailStart = InpTrailingStart * point;
         double trailStep = InpTrailingStep * point;
         
         if(profitPoints >= trailStart)
         {
            double newSL = bid - trailStep;
            if(newSL > sl)
            {
               Trade.PositionModify(symbol, newSL, PositionGetDouble(POSITION_TP));
               if(InpPrintSignals)
                  Print("Trailing stop mis à jour sur ", symbol, " - Nouveau SL: ", newSL);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Obtenir l'heure de la barre                                      |
//+------------------------------------------------------------------+
datetime GetBarTime(string symbol, ENUM_TIMEFRAMES tf, int shift)
{
   datetime timeArray[];
   ArraySetAsSeries(timeArray, true);
   if(CopyTime(symbol, tf, shift, 1, timeArray) > 0)
      return timeArray[0];
   return 0;
}
