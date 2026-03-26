//+------------------------------------------------------------------+
//|                                            Ichimoku_Horizons.mq5 |
//|                                      Généré par Assistant IA     |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Assistant IA"
#property link      ""
#property version   "1.00"
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
//| Fonction pour récupérer les niveaux Ichimoku d'une période      |
//+------------------------------------------------------------------+
bool GetIchimokuLevels(ENUM_TIMEFRAMES timeframe, IchimokuLevels &levels)
  {
   // Initialisation
   levels.tenkan = 0;
   levels.kijun = 0;
   levels.senkouA = 0;
   levels.senkouB = 0;
   levels.time = 0;
   levels.tf = timeframe;
   
   // Handles pour les indicateurs
   int handle_tenkan = iCustom(NULL, timeframe, "Examples\\Ichimoku", InpTenkan, InpKijun, InpSenkouB);
   int handle_kijun = iCustom(NULL, timeframe, "Examples\\Ichimoku", InpTenkan, InpKijun, InpSenkouB);
   int handle_senkouA = iCustom(NULL, timeframe, "Examples\\Ichimoku", InpTenkan, InpKijun, InpSenkouB);
   int handle_senkouB = iCustom(NULL, timeframe, "Examples\\Ichimoku", InpTenkan, InpKijun, InpSenkouB);
   
   if(handle_tenkan == INVALID_HANDLE || handle_kijun == INVALID_HANDLE ||
      handle_senkouA == INVALID_HANDLE || handle_senkouB == INVALID_HANDLE)
     {
      Print("Erreur création handles pour ", EnumToString(timeframe));
      return false;
     }
   
   // Buffers pour chaque indicateur
   double tenkan_buff[], kijun_buff[], senkouA_buff[], senkouB_buff[];
   ArraySetAsSeries(tenkan_buff, true);
   ArraySetAsSeries(kijun_buff, true);
   ArraySetAsSeries(senkouA_buff, true);
   ArraySetAsSeries(senkouB_buff, true);
   
   // Récupération des valeurs
   if(CopyBuffer(handle_tenkan, 0, 0, 1, tenkan_buff) <= 0 ||
      CopyBuffer(handle_kijun, 1, 0, 1, kijun_buff) <= 0 ||
      CopyBuffer(handle_senkouA, 2, 0, 1, senkouA_buff) <= 0 ||
      CopyBuffer(handle_senkouB, 3, 0, 1, senkouB_buff) <= 0)
     {
      Print("Erreur copie buffers pour ", EnumToString(timeframe));
      IndicatorRelease(handle_tenkan);
      IndicatorRelease(handle_kijun);
      IndicatorRelease(handle_senkouA);
      IndicatorRelease(handle_senkouB);
      return false;
     }
   
   // Stockage des valeurs
   levels.tenkan = tenkan_buff[0];
   levels.kijun = kijun_buff[0];
   levels.senkouA = senkouA_buff[0];
   levels.senkouB = senkouB_buff[0];
   levels.time = TimeCurrent();
   
   // Libération des handles
   IndicatorRelease(handle_tenkan);
   IndicatorRelease(handle_kijun);
   IndicatorRelease(handle_senkouA);
   IndicatorRelease(handle_senkouB);
   
   return true;
  }

//+------------------------------------------------------------------+
//| Fonction pour tracer les lignes horizontales                     |
//+------------------------------------------------------------------+
void DrawHorizontalLine(string name, double price, color line_color, string prefix, string suffix)
  {
   if(price <= 0) return;
   
   string obj_name = prefix + "_" + name + "_" + suffix;
   
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
      
      // Ajouter une description
      string description = "";
      if(name == "Tenkan") description = "Tenkan-sen";
      else if(name == "Kijun") description = "Kijun-sen";
      else if(name == "SenkouA") description = "Senkou Span A";
      else if(name == "SenkouB") description = "Senkou Span B";
      
      ObjectSetString(0, obj_name, OBJPROP_TEXT, description);
     }
  }

//+------------------------------------------------------------------+
//| Fonction pour nettoyer les anciennes lignes                      |
//+------------------------------------------------------------------+
void CleanOldLines(string prefix)
  {
   for(int i = ObjectsTotal(0) - 1; i >= 0; i--)
     {
      string obj_name = ObjectName(0, i);
      if(StringFind(obj_name, prefix) == 0)
        {
         ObjectDelete(0, obj_name);
        }
     }
  }

//+------------------------------------------------------------------+
//| Script principal                                                 |
//+------------------------------------------------------------------+
void OnStart()
  {
   // Nettoyer les anciennes lignes
   CleanOldLines("ICHIMOKU_");
   
   IchimokuLevels levels;
   
   // Récupérer et tracer les niveaux Mensuels
   if(InpMonthly)
     {
      if(GetIchimokuLevels(PERIOD_MN1, levels))
        {
         DrawHorizontalLine("Tenkan", levels.tenkan, InpColorTenkan, "ICHIMOKU_MN", "Tenkan");
         DrawHorizontalLine("Kijun", levels.kijun, InpColorKijun, "ICHIMOKU_MN", "Kijun");
         DrawHorizontalLine("SenkouA", levels.senkouA, InpColorSenkouA, "ICHIMOKU_MN", "SenkouA");
         DrawHorizontalLine("SenkouB", levels.senkouB, InpColorSenkouB, "ICHIMOKU_MN", "SenkouB");
         Print("Niveaux Mensuels chargés: Tenkan=", levels.tenkan, " Kijun=", levels.kijun);
        }
      else
        {
         Print("Impossible de charger les niveaux Mensuels");
        }
     }
   
   // Récupérer et tracer les niveaux Hebdomadaires
   if(InpWeekly)
     {
      if(GetIchimokuLevels(PERIOD_W1, levels))
        {
         DrawHorizontalLine("Tenkan", levels.tenkan, InpColorTenkan, "ICHIMOKU_WK", "Tenkan");
         DrawHorizontalLine("Kijun", levels.kijun, InpColorKijun, "ICHIMOKU_WK", "Kijun");
         DrawHorizontalLine("SenkouA", levels.senkouA, InpColorSenkouA, "ICHIMOKU_WK", "SenkouA");
         DrawHorizontalLine("SenkouB", levels.senkouB, InpColorSenkouB, "ICHIMOKU_WK", "SenkouB");
         Print("Niveaux Hebdomadaires chargés: Tenkan=", levels.tenkan, " Kijun=", levels.kijun);
        }
      else
        {
         Print("Impossible de charger les niveaux Hebdomadaires");
        }
     }
   
   // Récupérer et tracer les niveaux Quotidiens
   if(InpDaily)
     {
      if(GetIchimokuLevels(PERIOD_D1, levels))
        {
         DrawHorizontalLine("Tenkan", levels.tenkan, InpColorTenkan, "ICHIMOKU_DL", "Tenkan");
         DrawHorizontalLine("Kijun", levels.kijun, InpColorKijun, "ICHIMOKU_DL", "Kijun");
         DrawHorizontalLine("SenkouA", levels.senkouA, InpColorSenkouA, "ICHIMOKU_DL", "SenkouA");
         DrawHorizontalLine("SenkouB", levels.senkouB, InpColorSenkouB, "ICHIMOKU_DL", "SenkouB");
         Print("Niveaux Quotidiens chargés: Tenkan=", levels.tenkan, " Kijun=", levels.kijun);
        }
      else
        {
         Print("Impossible de charger les niveaux Quotidiens");
        }
     }
   
   // Rafraîchir le graphique
   ChartRedraw(0);
   
   Print("Script terminé avec succès");
  }
//+------------------------------------------------------------------+
