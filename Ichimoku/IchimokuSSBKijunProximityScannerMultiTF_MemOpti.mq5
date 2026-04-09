//+------------------------------------------------------------------+
//|        IchimokuSSBKijunProximityScannerMultiTF_MemOpti.mq5       |
//|           Scanner Proximité SSB & Kijun - Multi Timeframes       |
//|                                                     MetaTrader 5 |
//+------------------------------------------------------------------+
#property copyright "Corrigé et Adapté - Multi Timeframes"
#property link      "https://ntic974.blogspot.com"
#property version   "1.06"

//--- Inputs
input int             InpTenkan       = 9;         // Tenkan-sen
input int             InpKijun        = 26;        // Kijun-sen
input int             InpSenkouB      = 52;        // Senkou Span B
input double          InpProximity    = 0.05;      // Tolérance d'approche (en % du prix, ex: 0.05)
input bool            InpPopup        = true;      // Activer les alertes Popup
input bool            InpPush         = false;     // Activer les notifications Push (Mobile)

// Liste des timeframes à scanner
ENUM_TIMEFRAMES TimeframesToScan[] = {
   PERIOD_M15,   // 15 minutes
   PERIOD_M30,   // 30 minutes
   PERIOD_H1,    // 1 heure
   PERIOD_H4,    // 4 heures
   PERIOD_D1,    // 1 jour
   PERIOD_W1,    // 1 semaine
   PERIOD_MN1    // 1 mois
};

// Structure pour mémoriser l'état des alertes par symbole ET par timeframe
struct SymbolState {
   string   name;
   ENUM_TIMEFRAMES tf;
   datetime last_ssb_alert_time;
   datetime last_kijun_alert_time;
};

SymbolState symbols_state[];

// Tampons réutilisables pour éviter les allocations répétées
double ssb_buffer[];   
double kijun_buffer[];
double close_price[];  
datetime time_buffer[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   EventSetTimer(10);
   
   // Pré-allocation des tampons avec une taille raisonnable
   ArrayResize(ssb_buffer, 2);
   ArrayResize(kijun_buffer, 2);
   ArrayResize(close_price, 2);
   ArrayResize(time_buffer, 1);
   
   ArraySetAsSeries(ssb_buffer, true);
   ArraySetAsSeries(kijun_buffer, true);
   ArraySetAsSeries(close_price, true);
   ArraySetAsSeries(time_buffer, true);
   
   Print("Scanner d'approche SSB & Kijun MULTI-TIMEFRAMES démarré. Timer: 10s. Tolérance: ", InpProximity, "%");
   Print("Timeframes scannés: M15, M30, H1, H4, D1, W1, MN1");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   EventKillTimer();
   
   // Libération des tampons
   ArrayFree(ssb_buffer);
   ArrayFree(kijun_buffer);
   ArrayFree(close_price);
   ArrayFree(time_buffer);
   ArrayFree(symbols_state);
}

//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   int total = SymbolsTotal(true); 
   
   // Boucle sur tous les symboles du Market Watch
   for(int i = 0; i < total; i++)
   {
      string symbol = SymbolName(i, true);
      
      // Pour chaque symbole, scanner TOUS les timeframes définis
      for(int t = 0; t < ArraySize(TimeframesToScan); t++)
      {
         ENUM_TIMEFRAMES currentTF = TimeframesToScan[t];
         ScanSymbol(symbol, currentTF);
      }
   }
}

//+------------------------------------------------------------------+
//| Scan un symbole sur un timeframe spécifique                      |
//+------------------------------------------------------------------+
void ScanSymbol(string symbol, ENUM_TIMEFRAMES tf)
{
   // Vérifier que le timeframe est disponible pour ce symbole
   if(!IsTimeframeAvailable(symbol, tf)) return;
   
   int handle = iIchimoku(symbol, tf, InpTenkan, InpKijun, InpSenkouB);
   if(handle == INVALID_HANDLE) return;

   // Réutilisation des tampons au lieu de recréer à chaque appel
   // Lecture des prix
   if(CopyClose(symbol, tf, 0, 2, close_price) < 2 || 
      CopyTime(symbol, tf, 0, 1, time_buffer) < 1) 
   { 
      IndicatorRelease(handle); 
      return; 
   }

   // Lecture de la SSB (Buffer 3) et de la Kijun (Buffer 1)
   if(CopyBuffer(handle, 3, 0, 2, ssb_buffer) < 2 || 
      CopyBuffer(handle, 1, 0, 2, kijun_buffer) < 2) 
   { 
      IndicatorRelease(handle); 
      return; 
   }

   // Vérifier que les valeurs sont valides (non nulles)
   if(close_price[0] <= 0 || ssb_buffer[0] <= 0 || kijun_buffer[0] <= 0) 
   {
      IndicatorRelease(handle);
      return;
   }

   // --- CALCULS DES DISTANCES (en % du prix) ---
   double dist_ssb_actuelle    = (MathAbs(close_price[0] - ssb_buffer[0]) / close_price[0]) * 100.0;
   double dist_ssb_precedente  = (MathAbs(close_price[1] - ssb_buffer[1]) / close_price[1]) * 100.0;
   
   double dist_kijun_actuelle   = (MathAbs(close_price[0] - kijun_buffer[0]) / close_price[0]) * 100.0;
   double dist_kijun_precedente = (MathAbs(close_price[1] - kijun_buffer[1]) / close_price[1]) * 100.0;

   // --- LOGIQUE D'ALERTE SSB ---
   if((dist_ssb_precedente > InpProximity) && (dist_ssb_actuelle <= InpProximity))
   {
      if(!AlreadyAlerted(symbol, time_buffer[0], tf, "SSB")) 
      {
         string direction = (close_price[1] > ssb_buffer[1]) ? "par le HAUT" : "par le BAS";
         string msg = StringFormat("APPROCHE SSB | %s | %s | Prix: %.5f | SSB: %.5f | %s | Distance: %.3f%%", 
                                    symbol, TimeframeToString(tf), close_price[0], ssb_buffer[0], 
                                    direction, dist_ssb_actuelle);
         
         Print(msg);
         if(InpPopup) Alert(msg);
         if(InpPush)  SendNotification(msg);
         
         UpdateAlertState(symbol, time_buffer[0], tf, "SSB");
      }
   }

   // --- LOGIQUE D'ALERTE KIJUN ---
   if((dist_kijun_precedente > InpProximity) && (dist_kijun_actuelle <= InpProximity))
   {
      if(!AlreadyAlerted(symbol, time_buffer[0], tf, "KIJUN")) 
      {
         string direction = (close_price[1] > kijun_buffer[1]) ? "par le HAUT" : "par le BAS";
         string msg = StringFormat("APPROCHE KIJUN | %s | %s | Prix: %.5f | Kijun: %.5f | %s | Distance: %.3f%%", 
                                    symbol, TimeframeToString(tf), close_price[0], kijun_buffer[0], 
                                    direction, dist_kijun_actuelle);
         
         Print(msg);
         if(InpPopup) Alert(msg);
         if(InpPush)  SendNotification(msg);
         
         UpdateAlertState(symbol, time_buffer[0], tf, "KIJUN");
      }
   }
   
   IndicatorRelease(handle);
}

//+------------------------------------------------------------------+
//| Vérifie si un timeframe est disponible pour le symbole          |
//+------------------------------------------------------------------+
bool IsTimeframeAvailable(string symbol, ENUM_TIMEFRAMES tf)
{
   // Réutilisation d'un tableau statique pour minimiser les allocations
   static MqlRates rates[];
   return(CopyRates(symbol, tf, 0, 1, rates) > 0);
}

//+------------------------------------------------------------------+
//| Convertit un ENUM_TIMEFRAMES en string lisible                  |
//+------------------------------------------------------------------+
string TimeframeToString(ENUM_TIMEFRAMES tf)
{
   switch(tf)
   {
      case PERIOD_M15: return "M15";
      case PERIOD_M30: return "M30";
      case PERIOD_H1:  return "H1";
      case PERIOD_H4:  return "H4";
      case PERIOD_D1:  return "D1";
      case PERIOD_W1:  return "W1";
      case PERIOD_MN1: return "MN1";
      default: return EnumToString(tf);
   }
}

//+------------------------------------------------------------------+
//| Vérifie si une alerte a déjà été envoyée                        |
//+------------------------------------------------------------------+
bool AlreadyAlerted(string symbol, datetime bar_time, ENUM_TIMEFRAMES tf, string alert_type)
{
   int size = ArraySize(symbols_state);
   for(int i = 0; i < size; i++)
   {
      if(symbols_state[i].name == symbol && symbols_state[i].tf == tf)
      {
         if(alert_type == "SSB") 
            return (symbols_state[i].last_ssb_alert_time == bar_time);
         if(alert_type == "KIJUN") 
            return (symbols_state[i].last_kijun_alert_time == bar_time);
         return false;
      }
   }
   return false;
}

//+------------------------------------------------------------------+
//| Met à jour l'état des alertes                                   |
//+------------------------------------------------------------------+
void UpdateAlertState(string symbol, datetime bar_time, ENUM_TIMEFRAMES tf, string alert_type)
{
   int size = ArraySize(symbols_state);
   for(int i = 0; i < size; i++)
   {
      if(symbols_state[i].name == symbol && symbols_state[i].tf == tf)
      {
         if(alert_type == "SSB") 
            symbols_state[i].last_ssb_alert_time = bar_time;
         if(alert_type == "KIJUN") 
            symbols_state[i].last_kijun_alert_time = bar_time;
         return;
      }
   }
   
   // Ajout d'une nouvelle combinaison avec redimensionnement optimisé
   int new_size = size + 1;
   ArrayResize(symbols_state, new_size);
   symbols_state[size].name = symbol;
   symbols_state[size].tf = tf;
   
   if(alert_type == "SSB") {
      symbols_state[size].last_ssb_alert_time = bar_time;
      symbols_state[size].last_kijun_alert_time = 0;
   } else {
      symbols_state[size].last_ssb_alert_time = 0;
      symbols_state[size].last_kijun_alert_time = bar_time;
   }
}
//+------------------------------------------------------------------+
