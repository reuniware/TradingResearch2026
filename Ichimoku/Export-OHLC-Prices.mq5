//+------------------------------------------------------------------+
//|                                     Export_OHLC_Complete_Ultime.mq5 |
//|            Export OHLC - Tous timeframes + historique extensible   |
//+------------------------------------------------------------------+
#property copyright "Configuration Ultime - Tous TFs"
#property version   "3.00"
#property script_show_inputs

//--- Inputs
input string          FileName             = "Market_Prices_OHLC_Complete.txt";
input bool            AppendTimestamp      = true;
input bool            ShowOnlyEnabled      = true;
input string          CustomSymbols        = "";

//--- Configuration de l'export
input int             InpBarsHistory       = 50;        // Nombre de bougies par timeframe (jusqu'à 500)
input bool            ExportAllTimeframes  = true;      // Exporter TOUS les timeframes

//--- Timeframes individuels (si ExportAllTimeframes = false)
input bool            Export_MN1           = true;
input bool            Export_W1            = true;
input bool            Export_D1            = true;
input bool            Export_H4            = true;
input bool            Export_H1            = true;
input bool            Export_M30           = true;
input bool            Export_M15           = true;
input bool            Export_M5            = true;
input bool            Export_M1            = true;

//+------------------------------------------------------------------+
//| Structure pour stocker les timeframes                            |
//+------------------------------------------------------------------+
struct TimeframeConfig
{
   ENUM_TIMEFRAMES tf;
   string          name;
   bool            exportIt;
};

TimeframeConfig Timeframes[];

//+------------------------------------------------------------------+
void OnInitConfig()
{
   int count = 0;
   
   if(ExportAllTimeframes || Export_MN1)
   {
      ArrayResize(Timeframes, count+1);
      Timeframes[count].tf = PERIOD_MN1;
      Timeframes[count].name = "MN1";
      Timeframes[count].exportIt = true;
      count++;
   }
   if(ExportAllTimeframes || Export_W1)
   {
      ArrayResize(Timeframes, count+1);
      Timeframes[count].tf = PERIOD_W1;
      Timeframes[count].name = "W1";
      Timeframes[count].exportIt = true;
      count++;
   }
   if(ExportAllTimeframes || Export_D1)
   {
      ArrayResize(Timeframes, count+1);
      Timeframes[count].tf = PERIOD_D1;
      Timeframes[count].name = "D1";
      Timeframes[count].exportIt = true;
      count++;
   }
   if(ExportAllTimeframes || Export_H4)
   {
      ArrayResize(Timeframes, count+1);
      Timeframes[count].tf = PERIOD_H4;
      Timeframes[count].name = "H4";
      Timeframes[count].exportIt = true;
      count++;
   }
   if(ExportAllTimeframes || Export_H1)
   {
      ArrayResize(Timeframes, count+1);
      Timeframes[count].tf = PERIOD_H1;
      Timeframes[count].name = "H1";
      Timeframes[count].exportIt = true;
      count++;
   }
   if(ExportAllTimeframes || Export_M30)
   {
      ArrayResize(Timeframes, count+1);
      Timeframes[count].tf = PERIOD_M30;
      Timeframes[count].name = "M30";
      Timeframes[count].exportIt = true;
      count++;
   }
   if(ExportAllTimeframes || Export_M15)
   {
      ArrayResize(Timeframes, count+1);
      Timeframes[count].tf = PERIOD_M15;
      Timeframes[count].name = "M15";
      Timeframes[count].exportIt = true;
      count++;
   }
   if(ExportAllTimeframes || Export_M5)
   {
      ArrayResize(Timeframes, count+1);
      Timeframes[count].tf = PERIOD_M5;
      Timeframes[count].name = "M5";
      Timeframes[count].exportIt = true;
      count++;
   }
   if(ExportAllTimeframes || Export_M1)
   {
      ArrayResize(Timeframes, count+1);
      Timeframes[count].tf = PERIOD_M1;
      Timeframes[count].name = "M1";
      Timeframes[count].exportIt = true;
      count++;
   }
}

//+------------------------------------------------------------------+
void OnStart()
{
   OnInitConfig();
   
   if(ArraySize(Timeframes) == 0)
   {
      Print("Aucun timeframe sélectionné pour l'export !");
      return;
   }
   
   // Création du nom de fichier
   string file_name = FileName;
   if(AppendTimestamp)
   {
      string timestamp = TimeToString(TimeCurrent(), TIME_DATE|TIME_MINUTES|TIME_SECONDS);
      StringReplace(timestamp, ":", ".");
      StringReplace(timestamp, " ", "_");
      string base = FileName;
      int extPos = StringFind(FileName, ".txt");
      if(extPos > 0)
         base = StringSubstr(FileName, 0, extPos);
      file_name = base + "_" + timestamp + ".txt";
   }
   
   int handle = FileOpen(file_name, FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(handle == INVALID_HANDLE)
   {
      Print("Erreur ouverture fichier: ", GetLastError());
      return;
   }
   
   // En-tête
   FileWrite(handle, "=== EXPORT OHLC COMPLET MULTI-TIMEFRAME ===");
   FileWrite(handle, "Date/Heure export : " + TimeToString(TimeCurrent()));
   FileWrite(handle, "Nombre de bougies par TF : " + IntegerToString(InpBarsHistory));
   FileWrite(handle, "Timeframes exportes : " + GetTimeframesList());
   FileWrite(handle, "======================================================================");
   
   // Légende des colonnes
   string header = "Symbole | Spread | Bid | Ask";
   for(int t = 0; t < ArraySize(Timeframes); t++)
   {
      header += StringFormat(" | %s Close | %s High | %s Low | %s Open", 
                            Timeframes[t].name, Timeframes[t].name, 
                            Timeframes[t].name, Timeframes[t].name);
   }
   FileWrite(handle, header);
   FileWrite(handle, "======================================================================");
   
   // Récupération des symboles
   string symbols[];
   int totalSymbols = 0;
   
   if(CustomSymbols != "")
   {
      SplitString(CustomSymbols, ',', symbols);
      totalSymbols = ArraySize(symbols);
      for(int i = 0; i < totalSymbols; i++)
      {
         StringTrimLeft(symbols[i]);
         StringTrimRight(symbols[i]);
      }
   }
   else if(ShowOnlyEnabled)
   {
      totalSymbols = SymbolsTotal(true);
      ArrayResize(symbols, totalSymbols);
      for(int i = 0; i < totalSymbols; i++)
         symbols[i] = SymbolName(i, true);
   }
   
   int exported = 0;
   for(int i = 0; i < totalSymbols; i++)
   {
      if(ExportSymbolComplete(handle, symbols[i]))
         exported++;
   }
   
   FileWrite(handle, "======================================================================");
   FileWrite(handle, "Total symboles exportes : " + IntegerToString(exported));
   FileWrite(handle, "Fin de l'export");
   FileClose(handle);
   
   Print("=== EXPORT TERMINE ===");
   Print("Fichier : ", file_name);
   Print("Symboles : ", exported);
   Print("Timeframes : ", ArraySize(Timeframes));
   Print("Bougies par TF : ", InpBarsHistory);
   Print("Chemin : ", TerminalInfoString(TERMINAL_DATA_PATH), "\\MQL5\\Files\\", file_name);
}

//+------------------------------------------------------------------+
bool ExportSymbolComplete(int handle, string symbol)
{
   if(!SymbolSelect(symbol, true)) return false;
   
   // Prix actuels
   double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
   if(bid == 0 || ask == 0) return false;
   
   int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
   double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
   double spread = (point > 0) ? (ask - bid) / point : 0;
   
   string line = StringFormat("%-12s | Spread: %6.1f | Bid: %-12s | Ask: %-12s", 
                              symbol, spread, 
                              DoubleToString(bid, digits), 
                              DoubleToString(ask, digits));
   
   // Pour chaque timeframe, exporter la bougie actuelle
   for(int t = 0; t < ArraySize(Timeframes); t++)
   {
      MqlRates rates[];
      ArraySetAsSeries(rates, true);
      
      int copied = CopyRates(symbol, Timeframes[t].tf, 0, 1, rates);
      
      if(copied == 1)
      {
         line += StringFormat(" | %-12s | %-12s | %-12s | %-12s", 
                              DoubleToString(rates[0].close, digits),
                              DoubleToString(rates[0].high, digits),
                              DoubleToString(rates[0].low, digits),
                              DoubleToString(rates[0].open, digits));
      }
      else
      {
         line += " | N/A | N/A | N/A | N/A";
      }
   }
   
   FileWrite(handle, line);
   
   // --- EXPORT HISTORIQUE DÉTAILLÉ ---
   if(InpBarsHistory > 1)
   {
      FileWrite(handle, "  --- HISTORIQUE " + symbol + " ---");
      
      for(int t = 0; t < ArraySize(Timeframes); t++)
      {
         MqlRates rates[];
         ArraySetAsSeries(rates, true);
         
         int copied = CopyRates(symbol, Timeframes[t].tf, 0, InpBarsHistory, rates);
         
         if(copied == InpBarsHistory)
         {
            FileWrite(handle, "    [" + Timeframes[t].name + "] " + IntegerToString(copied) + " bougies :");
            
            for(int b = 0; b < copied; b++)
            {
               datetime barTime = rates[b].time;
               string timeStr = TimeToString(barTime, TIME_DATE|TIME_MINUTES);
               
               FileWrite(handle, StringFormat("      Bougie %2d (%s) : O=%-12s H=%-12s L=%-12s C=%-12s",
                                             b, timeStr,
                                             DoubleToString(rates[b].open, digits),
                                             DoubleToString(rates[b].high, digits),
                                             DoubleToString(rates[b].low, digits),
                                             DoubleToString(rates[b].close, digits)));
            }
         }
         else
         {
            FileWrite(handle, "    [" + Timeframes[t].name + "] ERREUR: seulement " + IntegerToString(copied) + " bougies sur " + IntegerToString(InpBarsHistory));
         }
      }
   }
   
   return true;
}

//+------------------------------------------------------------------+
string GetTimeframesList()
{
   string list = "";
   for(int t = 0; t < ArraySize(Timeframes); t++)
   {
      if(t > 0) list += ", ";
      list += Timeframes[t].name;
   }
   return list;
}

//+------------------------------------------------------------------+
void SplitString(string str, ushort separator, string &result[])
{
   int count = 0;
   int start = 0;
   int pos = 0;
   string sep_str = CharToString((uchar)separator);
   
   ArrayResize(result, 0);
   
   while((pos = StringFind(str, sep_str, start)) != -1)
   {
      ArrayResize(result, count + 1);
      result[count] = StringSubstr(str, start, pos - start);
      count++;
      start = pos + 1;
   }
   
   if(start < StringLen(str))
   {
      ArrayResize(result, count + 1);
      result[count] = StringSubstr(str, start);
      count++;
   }
}
//+------------------------------------------------------------------+
