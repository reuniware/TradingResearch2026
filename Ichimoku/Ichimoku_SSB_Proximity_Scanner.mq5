//+------------------------------------------------------------------+
//|                               ScannerSSB_Kijun_Proximity_Fix.mq5 |
//|           Scanner Proximité SSB & Kijun Actuelles (Temps Réel)   |
//|                                                      MetaTrader 5|
//+------------------------------------------------------------------+
#property copyright "Corrigé et Adapté - Version avec Kijun"
#property link      ""
#property version   "1.04"

//--- Inputs
input int             InpTenkan       = 9;         // Tenkan-sen
input int             InpKijun        = 26;        // Kijun-sen
input int             InpSenkouB      = 52;        // Senkou Span B
input double          InpProximity    = 0.05;      // Tolérance d'approche (en % du prix, ex: 0.05)
input bool            InpPopup        = true;      // Activer les alertes Popup
input bool            InpPush         = false;     // Activer les notifications Push (Mobile)

// Structure pour mémoriser l'état des alertes par symbole (Séparation SSB et Kijun)
struct SymbolState {
   string   name;
   ENUM_TIMEFRAMES last_tf;
   datetime last_ssb_alert_time;
   datetime last_kijun_alert_time;
};

SymbolState symbols_state[];

int OnInit()
{
   EventSetTimer(10); 
   Print("Scanner d'approche SSB & Kijun démarré. Timer: 10s. Tolérance: ", InpProximity, "%");
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
}

void OnTimer()
{
   ENUM_TIMEFRAMES currentTF = Period();
   int total = SymbolsTotal(true); 
   
   for(int i = 0; i < total; i++)
   {
      string symbol = SymbolName(i, true);
      ScanSymbol(symbol, currentTF);
   }
}

void ScanSymbol(string symbol, ENUM_TIMEFRAMES tf)
{
   int handle = iIchimoku(symbol, tf, InpTenkan, InpKijun, InpSenkouB);
   if(handle == INVALID_HANDLE) return;
 
   double ssb_buffer[];   
   double kijun_buffer[]; // Nouveau buffer pour la Kijun
   double close_price[];  
   datetime time_buffer[];
   
   ArraySetAsSeries(ssb_buffer, true);
   ArraySetAsSeries(kijun_buffer, true);
   ArraySetAsSeries(close_price, true);
   ArraySetAsSeries(time_buffer, true);

   // Lecture des prix (0 = actuel, 1 = précédent)
   if(CopyClose(symbol, tf, 0, 2, close_price) < 2 || CopyTime(symbol, tf, 0, 1, time_buffer) < 1) 
   { 
      IndicatorRelease(handle); 
      return; 
   }

   // Lecture de la SSB (Buffer 3) et de la Kijun (Buffer 1) sur la bougie actuelle (Index 0)
   if(CopyBuffer(handle, 3, 0, 2, ssb_buffer) < 2 || CopyBuffer(handle, 1, 0, 2, kijun_buffer) < 2) 
   { 
      IndicatorRelease(handle); 
      return; 
   }

   // Variables pour plus de clarté
   double close_0 = close_price[0]; 
   double close_1 = close_price[1]; 
   
   double ssb_0 = ssb_buffer[0];    
   double ssb_1 = ssb_buffer[1];    
   
   double kijun_0 = kijun_buffer[0];    
   double kijun_1 = kijun_buffer[1];

   // --- CALCULS DES DISTANCES (en % du prix) ---
   double dist_ssb_actuelle    = (MathAbs(close_0 - ssb_0) / close_0) * 100.0;
   double dist_ssb_precedente  = (MathAbs(close_1 - ssb_1) / close_1) * 100.0;
   
   double dist_kijun_actuelle   = (MathAbs(close_0 - kijun_0) / close_0) * 100.0;
   double dist_kijun_precedente = (MathAbs(close_1 - kijun_1) / close_1) * 100.0;

   // --- LOGIQUE D'ALERTE SSB ---
   bool is_approaching_ssb = (dist_ssb_precedente > InpProximity) && (dist_ssb_actuelle <= InpProximity);
   if(is_approaching_ssb)
   {
      if(!AlreadyAlerted(symbol, time_buffer[0], tf, "SSB")) 
      {
         string direction = (close_1 > ssb_1) ? "par le HAUT" : "par le BAS";
         string msg = StringFormat("APPROCHE SSB | %s | %s | Prix: %.5f | SSB: %.5f | %s", 
                                    symbol, EnumToString(tf), close_0, ssb_0, direction);
         
         Print(msg);
         if(InpPopup) Alert(msg);
         if(InpPush)  SendNotification(msg);
         
         UpdateAlertState(symbol, time_buffer[0], tf, "SSB");
      }
   }

   // --- LOGIQUE D'ALERTE KIJUN ---
   bool is_approaching_kijun = (dist_kijun_precedente > InpProximity) && (dist_kijun_actuelle <= InpProximity);
   if(is_approaching_kijun)
   {
      if(!AlreadyAlerted(symbol, time_buffer[0], tf, "KIJUN")) 
      {
         string direction = (close_1 > kijun_1) ? "par le HAUT" : "par le BAS";
         string msg = StringFormat("APPROCHE KIJUN | %s | %s | Prix: %.5f | Kijun: %.5f | %s", 
                                    symbol, EnumToString(tf), close_0, kijun_0, direction);
         
         Print(msg);
         if(InpPopup) Alert(msg);
         if(InpPush)  SendNotification(msg);
         
         UpdateAlertState(symbol, time_buffer[0], tf, "KIJUN");
      }
   }
   
   // Libération de la mémoire
   IndicatorRelease(handle);
}

// --- Fonctions de gestion d'état ---
// Le paramètre alert_type ("SSB" ou "KIJUN") permet de ne pas bloquer les alertes indépendantes
bool AlreadyAlerted(string symbol, datetime bar_time, ENUM_TIMEFRAMES tf, string alert_type)
{
   int size = ArraySize(symbols_state);
   for(int i=0; i<size; i++)
   {
      if(symbols_state[i].name == symbol && symbols_state[i].last_tf == tf)
      {
         if(alert_type == "SSB" && symbols_state[i].last_ssb_alert_time == bar_time) return true;
         if(alert_type == "KIJUN" && symbols_state[i].last_kijun_alert_time == bar_time) return true;
         return false; // Symbole trouvé mais pas encore d'alerte pour ce TYPE sur cette bougie
      }
   }
   return false;
}

void UpdateAlertState(string symbol, datetime bar_time, ENUM_TIMEFRAMES tf, string alert_type)
{
   int size = ArraySize(symbols_state);
   for(int i=0; i<size; i++)
   {
      if(symbols_state[i].name == symbol && symbols_state[i].last_tf == tf)
      {
         if(alert_type == "SSB") symbols_state[i].last_ssb_alert_time = bar_time;
         if(alert_type == "KIJUN") symbols_state[i].last_kijun_alert_time = bar_time;
         return;
      }
   }
   
   // Ajout d'un nouveau symbole
   ArrayResize(symbols_state, size + 1);
   symbols_state[size].name = symbol;
   symbols_state[size].last_tf = tf;
   
   if(alert_type == "SSB") {
      symbols_state[size].last_ssb_alert_time = bar_time;
      symbols_state[size].last_kijun_alert_time = 0;
   } else {
      symbols_state[size].last_ssb_alert_time = 0;
      symbols_state[size].last_kijun_alert_time = bar_time;
   }
}
//+------------------------------------------------------------------+
