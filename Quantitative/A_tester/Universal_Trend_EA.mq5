//+------------------------------------------------------------------+
//|                                              Universal_Trend_EA.mq5 |
//|                                      Généré par l'IA pour MT5       |
//+------------------------------------------------------------------+
#property copyright "Créé pour MT5"
#property link      ""
#property version   "1.00"

#include <Trade\Trade.mqh>

//--- Paramètres de l'utilisateur
input double   InpRiskPercent       = 1.0;      // Risque par trade (% du Capital)
input double   InpRiskRewardRatio   = 2.0;      // Ratio Risque/Récompense (ex: 2.0 = TP 2x plus grand que SL)
input int      InpFastEMA           = 10;       // Période EMA Rapide
input int      InpSlowEMA           = 50;       // Période EMA Lente
input int      InpATRPeriod         = 14;       // Période ATR (pour la volatilité)
input double   InpATRMultiplierSL   = 1.5;      // Multiplicateur ATR pour le Stop Loss
input ulong    InpMagicNumber       = 123456;   // Nombre Magique (Identifiant de l'EA)

//--- Variables globales
CTrade         trade;
int            handle_ema_fast;
int            handle_ema_slow;
int            handle_atr;
datetime       last_bar_time;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   // Initialisation de la classe de trading
   trade.SetExpertMagicNumber(InpMagicNumber);
   
   // Initialisation des indicateurs
   handle_ema_fast = iMA(_Symbol, _Period, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   handle_ema_slow = iMA(_Symbol, _Period, InpSlowEMA, 0, MODE_EMA, PRICE_CLOSE);
   handle_atr      = iATR(_Symbol, _Period, InpATRPeriod);
   
   if(handle_ema_fast == INVALID_HANDLE || handle_ema_slow == INVALID_HANDLE || handle_atr == INVALID_HANDLE)
     {
      Print("Erreur lors du chargement des indicateurs !");
      return(INIT_FAILED);
     }
     
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   IndicatorRelease(handle_ema_fast);
   IndicatorRelease(handle_ema_slow);
   IndicatorRelease(handle_atr);
  }

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // 1. S'assurer qu'on exécute le code uniquement à la clôture d'une bougie
   datetime current_bar_time = iTime(_Symbol, _Period, 0);
   if(current_bar_time == last_bar_time) return;
   
   // 2. Vérifier si un trade est déjà ouvert par cet EA sur cet actif
   if(CountOpenPositions() > 0) return; // Un seul trade à la fois pour maîtriser le risque
   
   // 3. Récupération des données des indicateurs
   double ema_fast[], ema_slow[], atr[];
   ArraySetAsSeries(ema_fast, true);
   ArraySetAsSeries(ema_slow, true);
   ArraySetAsSeries(atr, true);
   
   if(CopyBuffer(handle_ema_fast, 0, 1, 2, ema_fast) <= 0) return;
   if(CopyBuffer(handle_ema_slow, 0, 1, 2, ema_slow) <= 0) return;
   if(CopyBuffer(handle_atr, 0, 1, 1, atr) <= 0) return;

   // 4. Conditions de Trading (Croisement des EMA)
   bool buy_condition = (ema_fast[1] > ema_slow[1] && ema_fast[0] <= ema_slow[0]);  // Croisement Haussier
   bool sell_condition = (ema_fast[1] < ema_slow[1] && ema_fast[0] >= ema_slow[0]); // Croisement Baissier

   // 5. Calcul des distances de sécurité basées sur l'ATR
   double atr_value = atr[0];
   double sl_distance_price = atr_value * InpATRMultiplierSL;
   
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // 6. Exécution des ordres
   if(buy_condition)
     {
      double sl = ask - sl_distance_price;
      double tp = ask + (sl_distance_price * InpRiskRewardRatio);
      double lot_size = CalculateLotSize(sl_distance_price);
      
      if(lot_size > 0)
        {
         trade.Buy(lot_size, _Symbol, ask, sl, tp, "EA Trend Buy");
         last_bar_time = current_bar_time; // Enregistrer la bougie
        }
     }
   else if(sell_condition)
     {
      double sl = bid + sl_distance_price;
      double tp = bid - (sl_distance_price * InpRiskRewardRatio);
      double lot_size = CalculateLotSize(sl_distance_price);
      
      if(lot_size > 0)
        {
         trade.Sell(lot_size, _Symbol, bid, sl, tp, "EA Trend Sell");
         last_bar_time = current_bar_time; // Enregistrer la bougie
        }
     }
  }

//+------------------------------------------------------------------+
//| Calcule la taille de lot optimale selon le risque en %           |
//+------------------------------------------------------------------+
double CalculateLotSize(double sl_distance_price)
  {
   double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double risk_amount = account_balance * (InpRiskPercent / 100.0);
   
   double tick_size = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   if(tick_size <= 0 || tick_value <= 0 || sl_distance_price <= 0) return 0.0;
   
   // Calcul de la valeur financière d'un mouvement de la taille du Stop Loss pour 1 lot
   double points_at_risk = sl_distance_price / tick_size;
   double money_risk_per_lot = points_at_risk * tick_value;
   
   if(money_risk_per_lot <= 0) return 0.0;
   
   // Calcul final des lots
   double lot_size = risk_amount / money_risk_per_lot;
   
   // Normalisation des lots selon les limites du courtier
   double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   lot_size = MathRound(lot_size / step_lot) * step_lot;
   
   if(lot_size < min_lot) lot_size = min_lot;
   if(lot_size > max_lot) lot_size = max_lot;
   
   return lot_size;
  }

//+------------------------------------------------------------------+
//| Compte le nombre de positions ouvertes par l'EA sur ce symbole   |
//+------------------------------------------------------------------+
int CountOpenPositions()
  {
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && 
         PositionGetInteger(POSITION_MAGIC) == InpMagicNumber)
        {
         count++;
        }
     }
   return count;
  }
//+------------------------------------------------------------------+
