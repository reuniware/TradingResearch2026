//+------------------------------------------------------------------+
//|                                         Gemini_ICT_Analyzer.mq5  |
//|                           Analyse ICT/SMC temps réel (Gemini)    |
//+------------------------------------------------------------------+
#property copyright "ICT/SMC Analyzer"
#property version   "2.00"
#property strict

// Paramètres d'entrée
input string   API_KEY = "";                  
input int      AnalysisIntervalMinutes = 5;
input bool     SendOHLC = true;
input bool     GenerateAlerts = true;
input bool     ShowOnChart = true;

// Variables globales
datetime lastAnalysis = 0;
string lastResponse = "";
int      errorCount = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   if(StringLen(API_KEY) < 10)
   {
      Alert("ERREUR: Clé API Gemini invalide.");
      return(INIT_FAILED);
   }
   
   Print("EA Gemini ICT Analyzer démarré (v2.00)");
   
   PerformAnalysis();
   lastAnalysis = TimeCurrent();
   
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
}
//+------------------------------------------------------------------+
void OnTick()
{
   if(TimeCurrent() - lastAnalysis >= AnalysisIntervalMinutes * 60)
   {
      PerformAnalysis();
      lastAnalysis = TimeCurrent();
   }
}
//+------------------------------------------------------------------+
void PerformAnalysis()
{
   string prompt = BuildPrompt();
   string response = CallGeminiAPI(prompt);
   
   if(response != "")
   {
      lastResponse = response;
      errorCount = 0;
      
      if(ShowOnChart)
         DisplayOnChart(response);
      
      if(GenerateAlerts)
         CheckForAlerts(response);
   }
   else
   {
      errorCount++;
      Comment("Erreur API Gemini: ", errorCount);
   }
}
//+------------------------------------------------------------------+
string BuildPrompt()
{
   string prompt = "";
   
   prompt += "Tu es un expert ICT/SMC.\n";
   
   if(SendOHLC)
   {
      prompt += "DONNEES:\n";
      prompt += GetOHLCData();
   }
   
   prompt += "REPONDS UNIQUEMENT EN JSON STRICT:\n";
   prompt += "{\"bias\":\"haussier|baissier|neutre\",";
   prompt += "\"setup\":{\"type\":\"long|short|aucun\",\"entry\":0,\"sl\":0,\"tp\":0}}";
   
   return prompt;
}
//+------------------------------------------------------------------+
string GetOHLCData()
{
   string data = "";
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   int copied = CopyRates(_Symbol, PERIOD_M5, 0, 30, rates);
   
   for(int i = 0; i < copied; i++)
   {
      data += StringFormat("O:%.2f H:%.2f L:%.2f C:%.2f\n",
         rates[i].open,
         rates[i].high,
         rates[i].low,
         rates[i].close);
   }
   
   return data;
}
//+------------------------------------------------------------------+
string CallGeminiAPI(string prompt)
{
   string url = "https://generativelanguage.googleapis.com/v1/models/gemini-pro:generateContent?key=" + API_KEY;

   string json = "{";
   json += "\"contents\": [{\"parts\": [{\"text\": \"" + EscapeJSON(prompt) + "\"}]}]";
   json += "}";

   char post[];
   StringToCharArray(json, post);

   string headers = "Content-Type: application/json\r\n";

   char result[];
   string result_headers;

   int res = WebRequest("POST", url, headers, 45000, post, result, result_headers);

   if(res == 200)
   {
      string response = CharArrayToString(result);
      return ExtractGemini(response);
   }

   Print("Erreur HTTP: ", res);
   return "";
}
//+------------------------------------------------------------------+
string ExtractGemini(string response)
{
   int pos = StringFind(response, "\"text\":");
   if(pos < 0) return "";

   pos += 7;

   while(StringGetCharacter(response, pos) != '"') pos++;
   pos++;

   int end = pos;

   while(end < StringLen(response))
   {
      if(StringGetCharacter(response, end) == '"' &&
         StringGetCharacter(response, end-1) != '\\')
         break;
      end++;
   }

   string content = StringSubstr(response, pos, end-pos);

   content = StringReplace(content, "\\\"", "\"");
   content = StringReplace(content, "\\n", "\n");

   return content;
}
//+------------------------------------------------------------------+
string EscapeJSON(string text)
{
   string result = text;
   result = StringReplace(result, "\\", "\\\\");
   result = StringReplace(result, "\"", "\\\"");
   result = StringReplace(result, "\n", "\\n");
   return result;
}
//+------------------------------------------------------------------+
void DisplayOnChart(string analysis)
{
   Comment("GEMINI ICT\n\n", analysis);
}
//+------------------------------------------------------------------+
void CheckForAlerts(string analysis)
{
   if(StringFind(analysis, "long") >= 0)
      Alert("LONG détecté");

   if(StringFind(analysis, "short") >= 0)
      Alert("SHORT détecté");
}
//+------------------------------------------------------------------+
