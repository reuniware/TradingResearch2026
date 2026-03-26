//+------------------------------------------------------------------+
//|                                            Ichimoku_Horizons.mq5 |
//|                                      Version avec historique     |
//+------------------------------------------------------------------+
#property copyright "Didier Le HPI Réunionnais né le 11/12/1975 à Nogent Sur Marne"
#property link      ""
#property version   "2.00"
#property script_show_inputs

//+------------------------------------------------------------------+
//| Paramètres d'entrée                                             |
//+------------------------------------------------------------------+
input group "Paramètres Ichimoku"
input int      InpTenkan = 9;                // Période Tenkan-sen
input int      InpKijun  = 26;               // Période Kijun-sen
input int      InpSenkouB = 52;              // Période Senkou Span B

input group "Sélection des unités de temps"
input bool     InpMonthly = true;            // Afficher niveaux Mensuels
input bool     InpWeekly  = true;            // Afficher niveaux Hebdomadaires
input bool     InpDaily   = true;            // Afficher niveaux Quotidiens

input group "Nombre de niveaux à tracer"
input int      InpHistoryBars = 10;          // Nombre de périodes historiques (1-50)
input bool     InpDrawOnlyLast = false;      // Tracer uniquement la dernière valeur ?

input group "Style des lignes"
input color    InpColorTenkan = clrDodgerBlue;  // Couleur Tenkan
input color    InpColorKijun  = clrOrangeRed;   // Couleur Kijun
input color    InpColorSenkouA = clrGreen;      // Couleur Senkou A
input color    InpColorSenkouB = clrRed;        // Couleur Senkou B
input ENUM_LINE_STYLE InpStyle = STYLE_DASH;    // Style de ligne
input int      InpWidth = 1;                    // Épaisseur ligne

//+------------------------------------------------------------------+
//| Structure pour stocker les niveaux                              |
//+------------------------------------------------------------------+
struct IchimokuLevels
  {
   double tenkan;
   double kijun;
   double senkouA;
   double senkouB;
   datetime time;
   ENUM_TIMEFRAMES tf;
  };

//+------------------------------------------------------------------+
//| Fonction pour récupérer les niveaux Ichimoku historiques        |
//+------------------------------------------------------------------+
int GetHistoricalIchimokuLevels(ENUM_TIMEFRAMES timeframe, IchimokuLevels &levels[], int max_bars)
  {
   // Handles pour l'indicateur Ichimoku
   int handle = iCustom(NULL, timeframe, "Examples\\Ichimoku", InpTenkan, InpKijun, InpSenkouB);
   if(handle == INVALID_HANDLE)
     {
      Print("Erreur création handle pour ", EnumToString(timeframe));
      return 0;
     }
   
   // Buffers
   double tenkan_buff[], kijun_buff[], senkouA_buff[], senkouB_buff[];
   ArraySetAsSeries(tenkan_buff, true);
   ArraySetAsSeries(kijun_buff, true);
   ArraySetAsSeries(senkouA_buff, true);
   ArraySetAsSeries(senkouB_buff, true);
   
   // Récupération des valeurs
   int bars_copied = CopyBuffer(handle, 0, 0, max_bars, tenkan_buff);
   if(bars_copied <= 0) 
     {
      IndicatorRelease(handle);
      return 0;
     }
   
   CopyBuffer(handle, 1, 0, max_bars, kijun_buff);
   CopyBuffer(handle, 2, 0, max_bars, senkouA_buff);
   CopyBuffer(handle, 3, 0, max_bars, senkouB_buff);
   
   // Redimensionner le tableau
   ArrayResize(levels, bars_copied);
   
   // Remplir la structure
   for(int i = 0; i < bars_copied; i++)
     {
      levels[i].tenkan = tenkan_buff[i];
      levels[i].kijun = kijun_buff[i];
      levels[i].senkouA = senkouA_buff[i];
      levels[i].senkouB = senkouB_buff[i];
      levels[i].time = iTime(NULL, timeframe, i);
      levels[i].tf = timeframe;
     }
   
   IndicatorRelease(handle);
   return bars_copied;
  }

//+------------------------------------------------------------------+
//| Fonction pour tracer les lignes horizontales                     |
//+------------------------------------------------------------------+
void DrawHorizontalLine(string name, double price, color line_color, 
                        string prefix, string suffix, datetime time = 0)
  {
   if(price <= 0 || price == EMPTY_VALUE) return;
   
   string obj_name;
   if(time > 0)
     {
      // Pour les lignes historiques, on inclut la date dans le nom
      obj_name = prefix + "_" + name + "_" + suffix + "_" + IntegerToString(time);
     }
   else
     {
      obj_name = prefix + "_" + name + "_" + suffix;
     }
   
   // Supprimer l'objet s'il existe déjà
   ObjectDelete(0, obj_name);
   
   // Créer la ligne horizontale
   if(ObjectCreate(0, obj_name, OBJ_HLINE, 0, 0, price))
     {
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, line_color);
      ObjectSetInteger(0, obj_name, OBJPROP_STYLE, InpStyle);
      ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, InpWidth);
      ObjectSetInteger(0, obj_name, OBJPROP_BACK, false);
      ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, obj_name, OBJPROP_HIDDEN, false);
     }
  }

//+------------------------------------------------------------------+
//| Fonction pour tracer tous les niveaux d'une période             |
//+------------------------------------------------------------------+
void DrawAllLevelsForTF(ENUM_TIMEFRAMES tf, string tf_prefix, int max_bars)
  {
   // Variables locales pour éviter de modifier les constantes
   int bars_to_load = max_bars;
   
   // Limiter le nombre de barres
   if(bars_to_load < 1) bars_to_load = 1;
   if(bars_to_load > 50) bars_to_load = 50;
   
   IchimokuLevels levels[];
   int bars = GetHistoricalIchimokuLevels(tf, levels, bars_to_load);
   
   if(bars <= 0)
     {
      Print("Aucune donnée pour ", EnumToString(tf));
      return;
     }
   
   Print("Tracé de ", bars, " niveaux pour ", EnumToString(tf));
   
   // Déterminer combien de niveaux tracer
   int start_idx = 0;
   int end_idx = bars;
   
   if(InpDrawOnlyLast)
     {
      start_idx = bars - 1;
      end_idx = bars;
     }
   
   for(int i = start_idx; i < end_idx; i++)
     {
      // Vérifier si les valeurs sont valides
      if(levels[i].tenkan > 0 && levels[i].tenkan != EMPTY_VALUE)
         DrawHorizontalLine("Tenkan", levels[i].tenkan, InpColorTenkan, 
                           tf_prefix, "Tenkan", levels[i].time);
      
      if(levels[i].kijun > 0 && levels[i].kijun != EMPTY_VALUE)
         DrawHorizontalLine("Kijun", levels[i].kijun, InpColorKijun, 
                           tf_prefix, "Kijun", levels[i].time);
      
      if(levels[i].senkouA > 0 && levels[i].senkouA != EMPTY_VALUE)
         DrawHorizontalLine("SenkouA", levels[i].senkouA, InpColorSenkouA, 
                           tf_prefix, "SenkouA", levels[i].time);
      
      if(levels[i].senkouB > 0 && levels[i].senkouB != EMPTY_VALUE)
         DrawHorizontalLine("SenkouB", levels[i].senkouB, InpColorSenkouB, 
                           tf_prefix, "SenkouB", levels[i].time);
     }
  }

//+------------------------------------------------------------------+
//| Fonction pour nettoyer les anciennes lignes                      |
//+------------------------------------------------------------------+
void CleanOldLines()
  {
   int deleted = 0;
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
     {
      string obj_name = ObjectName(0, i);
      if(StringFind(obj_name, "ICHIMOKU_") == 0)
        {
         ObjectDelete(0, obj_name);
         deleted++;
        }
     }
   if(deleted > 0) Print("Nettoyage de ", deleted, " anciennes lignes");
  }

//+------------------------------------------------------------------+
//| Script principal                                                 |
//+------------------------------------------------------------------+
void OnStart()
  {
   // Variables locales pour stocker les valeurs des inputs
   int history_bars = InpHistoryBars;
   bool draw_only_last = InpDrawOnlyLast;
   bool monthly = InpMonthly;
   bool weekly = InpWeekly;
   bool daily = InpDaily;
   
   // Valider les paramètres
   if(history_bars < 1) history_bars = 1;
   if(history_bars > 50) history_bars = 50;
   
   // Nettoyer les anciennes lignes
   CleanOldLines();
   
   // Tracer les niveaux pour chaque période
   if(monthly)
     {
      Print("Traitement des niveaux Mensuels...");
      DrawAllLevelsForTF(PERIOD_MN1, "ICHIMOKU_MN", history_bars);
     }
   
   if(weekly)
     {
      Print("Traitement des niveaux Hebdomadaires...");
      DrawAllLevelsForTF(PERIOD_W1, "ICHIMOKU_WK", history_bars);
     }
   
   if(daily)
     {
      Print("Traitement des niveaux Quotidiens...");
      DrawAllLevelsForTF(PERIOD_D1, "ICHIMOKU_DL", history_bars);
     }
   
   // Rafraîchir le graphique
   ChartRedraw(0);
   
   Print("Script terminé avec succès");
  }
//+------------------------------------------------------------------+
