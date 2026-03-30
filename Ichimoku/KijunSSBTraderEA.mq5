//+------------------------------------------------------------------+
//|                                  Ichimoku_Multi_Rejection_EA.mq5 |
//|                          Copyright 2026, T0W3RBU5T3R.            |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, T0W3RBU5T3R."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>
#include <Trade\SymbolInfo.mqh>

// --- INPUTS
input double   InpRiskPercent  = 1.0;     // Risque par trade (% de la balance)
input int      InpKijunPeriod  = 26;      // Période Kijun-sen
input int      InpSSBPeriod    = 52;      // Période SSB
input int      InpTimerSeconds = 10;      // Fréquence du scan (secondes)
input int      InpMagicNumber  = 123456;  // Magic Number
input int      InpStopOffset   = 10;      // Marge d'erreur SL (en Points)

// --- VARIABLES GLOBALES
struct SymbolData {
   string name;
   int    handle;
};

SymbolData m_symbols[];
int        m_total_symbols = 0;
CTrade     m_trade;

//+------------------------------------------------------------------+
int OnInit() {
   m_trade.SetExpertMagicNumber(InpMagicNumber);
   
   if(!InitializeHandles()) return(INIT_FAILED);
   
   EventSetTimer(InpTimerSeconds);
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   EventKillTimer();
   for(int i=0; i<m_total_symbols; i++) {
      if(m_symbols[i].handle != INVALID_HANDLE)
         IndicatorRelease(m_symbols[i].handle);
   }
}

void OnTimer() {
   ScanAndTrade();
}

//+------------------------------------------------------------------+
//| FONCTION PRINCIPALE DE SCAN ET TRADING                           |
//+------------------------------------------------------------------+
void ScanAndTrade() {
   MqlRates rates[];
   double kj_buf[], ssb_buf[];
   ArraySetAsSeries(rates, true);
   ArraySetAsSeries(kj_buf, true);
   ArraySetAsSeries(ssb_buf, true);

   for(int i=0; i<m_total_symbols; i++) {
      string sname = m_symbols[i].name;

      // 1. Vérifier si on a déjà une position sur ce symbole
      if(PositionSelect(sname)) continue;

      // 2. Récupérer les données (bougie fermée index 1)
      if(CopyRates(sname, PERIOD_CURRENT, 0, 2, rates) < 2) continue;
      if(CopyBuffer(m_symbols[i].handle, 1, 0, 2, kj_buf) < 2) continue; // Kijun
      if(CopyBuffer(m_symbols[i].handle, 3, 0, 2, ssb_buf) < 2) continue; // SSB

      double priceClose = rates[1].close;
      double priceHigh  = rates[1].high;
      double priceLow   = rates[1].low;
      double kjVal      = kj_buf[1];
      double ssbVal     = ssb_buf[1];

      // --- LOGIQUE DE SIGNAL ---
      bool buySignal = false;
      bool sellSignal = false;
      double targetLine = 0;

      // Test Kijun
      if(priceLow <= kjVal && priceClose > kjVal) { buySignal = true; targetLine = kjVal; }
      else if(priceHigh >= kjVal && priceClose < kjVal) { sellSignal = true; targetLine = kjVal; }
      
      // Test SSB (prioritaire si Kijun n'a pas déclenché)
      if(!buySignal && !sellSignal) {
         if(priceLow <= ssbVal && priceClose > ssbVal) { buySignal = true; targetLine = ssbVal; }
         else if(priceHigh >= ssbVal && priceClose < ssbVal) { sellSignal = true; targetLine = ssbVal; }
      }

      // 3. Exécution
      if(buySignal) ExecuteTrade(sname, ORDER_TYPE_BUY, targetLine);
      if(sellSignal) ExecuteTrade(sname, ORDER_TYPE_SELL, targetLine);
   }
}

//+------------------------------------------------------------------+
//| EXÉCUTION AVEC CALCUL DE LOTS AUTOMATIQUE                       |
//+------------------------------------------------------------------+
void ExecuteTrade(string sname, ENUM_ORDER_TYPE type, double lineVal) {
   CSymbolInfo sym;
   sym.Name(sname);
   sym.RefreshRates();
   
   double entry = (type == ORDER_TYPE_BUY) ? sym.Ask() : sym.Bid();
   double point = sym.Point();
   
   // Calcul du Stop Loss
   double sl = (type == ORDER_TYPE_BUY) ? (lineVal - (InpStopOffset * point)) : (lineVal + (InpStopOffset * point));
   
   // Sécurité : Vérifier que le SL est cohérent
   double slDist = MathAbs(entry - sl);
   if(slDist <= 0) return;

   // Calcul du Take Profit (Ratio 1:2)
   double tp = (type == ORDER_TYPE_BUY) ? (entry + (slDist * 2)) : (entry - (slDist * 2));

   // CALCUL DES LOTS BASÉ SUR LE RISQUE
   double lot = CalculateLots(sname, slDist);
   if(lot <= 0) return;

   // Envoi de l'ordre
   m_trade.Buy(lot, sname, entry, sl, tp, "Rejection Trade");
   if(m_trade.ResultRetcode() == TRADE_RETCODE_DONE) {
      Print("Trade ouvert sur ", sname, " Lots: ", lot);
   } else if(type == ORDER_TYPE_SELL) {
      m_trade.Sell(lot, sname, entry, sl, tp, "Rejection Trade");
   }
}

//+------------------------------------------------------------------+
//| CALCUL DU VOLUME (LOTS)                                          |
//+------------------------------------------------------------------+
double CalculateLots(string sname, double slDistancePrice) {
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (InpRiskPercent / 100.0);
   double tickValue = SymbolInfoDouble(sname, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(sname, SYMBOL_TRADE_TICK_SIZE);
   double lotStep = SymbolInfoDouble(sname, SYMBOL_VOLUME_STEP);
   
   if(tickValue <= 0 || tickSize <= 0) return 0;

   // Formule : Risque / (Distance SL en points * Valeur du point)
   double points = slDistancePrice / tickSize;
   double lot = riskAmount / (points * tickValue);
   
   // Ajustement aux limites du courtier
   double minLot = SymbolInfoDouble(sname, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(sname, SYMBOL_VOLUME_MAX);
   
   lot = MathFloor(lot / lotStep) * lotStep;
   
   if(lot < minLot) lot = 0; // Risque trop petit pour le capital
   if(lot > maxLot) lot = maxLot;
   
   return lot;
}

//+------------------------------------------------------------------+
//| INITIALISATION DES HANDLES                                       |
//+------------------------------------------------------------------+
bool InitializeHandles() {
   int total = SymbolsTotal(true);
   m_total_symbols = 0;
   ArrayResize(m_symbols, total);

   for(int i=0; i<total; i++) {
      string sname = SymbolName(i, true);
      SymbolSelect(sname, true);
      int h = iIchimoku(sname, PERIOD_CURRENT, 9, InpKijunPeriod, InpSSBPeriod);
      if(h != INVALID_HANDLE) {
         m_symbols[m_total_symbols].name = sname;
         m_symbols[m_total_symbols].handle = h;
         m_total_symbols++;
      }
   }
   ArrayResize(m_symbols, m_total_symbols);
   Print("EA Initialisé sur ", m_total_symbols, " symboles.");
   return (m_total_symbols > 0);
}

void OnTick() {}
