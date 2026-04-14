//+------------------------------------------------------------------+
//|                                         DeepSeek_ICT_Analyzer.mq5|
//|                                    Analyse ICT/SMC temps réel     |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "ICT/SMC Analyzer"
#property version   "1.10"
#property strict

// Paramètres d'entrée
input string   API_KEY = "";                    // Ta clé API DeepSeek (obligatoire)
input int      AnalysisIntervalMinutes = 5;    // Intervalle d'analyse (minutes)
input bool     SendOHLC = true;                // Envoyer les OHLC
input bool     GenerateAlerts = true;          // Générer des alertes
input bool     ShowOnChart = true;             // Afficher l'analyse sur le graphique

// Variables globales
datetime lastAnalysis = 0;
string lastResponse = "";
int      errorCount = 0;

//+------------------------------------------------------------------+
//| Initialisation                                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   if(StringLen(API_KEY) < 10)
   {
      Alert("ERREUR: Clé API DeepSeek invalide. Vérifie les paramètres.");
      return(INIT_FAILED);
   }
   
   Print("EA DeepSeek ICT Analyzer démarré (v1.10)");
   Print("Intervalle d'analyse: ", AnalysisIntervalMinutes, " minutes");
   Print("Clé API: ", StringSubstr(API_KEY, 0, 10), "...");
   
   // Analyse immédiate au démarrage
   PerformAnalysis();
   lastAnalysis = TimeCurrent();
   
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Deinitialisation                                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   Comment("");
   Print("EA arrêté. Raison: ", reason);
}

//+------------------------------------------------------------------+
//| Tick principal                                                   |
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
//| Effectue l'analyse via DeepSeek API                             |
//+------------------------------------------------------------------+
void PerformAnalysis()
{
   Print("=== Analyse DeepSeek à ", TimeToString(TimeCurrent()), " ===");
   
   string prompt = BuildPrompt();
   string response = CallDeepSeekAPI(prompt);
   
   if(response != "")
   {
      lastResponse = response;
      errorCount = 0;
      
      if(ShowOnChart)
         DisplayOnChart(response);
      
      if(GenerateAlerts)
         CheckForAlerts(response);
      
      Print("Analyse reçue avec succès");
   }
   else
   {
      errorCount++;
      Print("ERREUR: Pas de réponse de l'API DeepSeek (tentative ", errorCount, ")");
      
      if(ShowOnChart)
         Comment("Erreur API DeepSeek\nVérifie ta clé API et la connexion internet\nErreur: ", errorCount);
   }
}

//+------------------------------------------------------------------+
//| Construit le prompt pour DeepSeek                               |
//+------------------------------------------------------------------+
string BuildPrompt()
{
   string prompt = "";
   
   prompt += "Tu es un expert en trading ICT/SMC. Analyse le XAUUSD (or) en timeframe M5.\n";
   prompt += "\n";
   
   if(SendOHLC)
   {
      prompt += "DONNEES M5 (50 dernieres bougies):\n";
      prompt += GetOHLCData();
      prompt += "\n";
   }
   
   prompt += "DEMANDE D'ANALYSE:\n";
   prompt += "1. Identifie les FVG haussiers et baissiers\n";
   prompt += "2. Identifie les Order Blocks haussiers et baissiers\n";
   prompt += "3. Calcule les OTE (61.8%, 70.5%, 78.6%)\n";
   prompt += "4. Identifie les niveaux de liquidite (BSL/SSL)\n";
   prompt += "5. Donne le bias actuel\n";
   prompt += "6. Propose un setup de trade a haute probabilite si conditions reunies\n";
   prompt += "\n";
   
   prompt += "REPONDS UNIQUEMENT EN JSON VALIDE SANS TEXTE SUPPLEMENTAIRE:\n";
   prompt += "{\"bias\":\"haussier|baissier|neutre\",";
   prompt += "\"fvg_bullish\":[{\"low\":0,\"high\":0}],";
   prompt += "\"fvg_bearish\":[{\"low\":0,\"high\":0}],";
   prompt += "\"ob_bullish\":[{\"low\":0,\"high\":0}],";
   prompt += "\"ob_bearish\":[{\"low\":0,\"high\":0}],";
   prompt += "\"ote_bullish\":{\"l61\":0,\"l70\":0,\"l78\":0},";
   prompt += "\"ote_bearish\":{\"l61\":0,\"l70\":0,\"l78\":0},";
   prompt += "\"bsl\":0,\"ssl\":0,";
   prompt += "\"setup\":{\"type\":\"long|short|aucun\",\"entry\":0,\"sl\":0,\"tp1\":0,\"tp2\":0,\"probabilite\":\"haute|moyenne|faible\",\"raison\":\"\"},";
   prompt += "\"alert\":\"\"}";
   
   return prompt;
}

//+------------------------------------------------------------------+
//| Récupère les données OHLC M5 (format CSV simple)                |
//+------------------------------------------------------------------+
string GetOHLCData()
{
   string data = "";
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   
   int copied = CopyRates(_Symbol, PERIOD_M5, 0, 50, rates);
   
   if(copied > 0)
   {
      for(int i = 0; i < copied && i < 30; i++) // Limite à 30 bougies pour éviter trop de données
      {
         data += StringFormat("%s O:%.2f H:%.2f L:%.2f C:%.2f\n",
            TimeToString(rates[i].time, TIME_MINUTES),
            rates[i].open,
            rates[i].high,
            rates[i].low,
            rates[i].close);
      }
   }
   else
   {
      data = "Impossible de recuperer les donnees";
   }
   
   return data;
}

//+------------------------------------------------------------------+
//| Appelle l'API DeepSeek avec JSON propre                         |
//+------------------------------------------------------------------+
string CallDeepSeekAPI(string prompt)
{
   string url = "https://api.deepseek.com/v1/chat/completions";
   
   // Construction manuelle du JSON (plus fiable)
   string json = "{";
   json += "\"model\": \"deepseek-chat\",";
   json += "\"messages\": [";
   
   // System message
   json += "{";
   json += "\"role\": \"system\",";
   json += "\"content\": \"You are an ICT/SMC trading expert. Respond ONLY with valid JSON.\"";
   json += "},";
   
   // User message
   json += "{";
   json += "\"role\": \"user\",";
   json += "\"content\": \"" + EscapeJSONForAPI(prompt) + "\"";
   json += "}";
   
   json += "],";
   json += "\"temperature\": 0.3,";
   json += "\"max_tokens\": 1500,";
   json += "\"stream\": false";
   json += "}";
   
   // Debug
   Print("JSON length: ", StringLen(json));
   
   // Préparation de la requête
   char postData[];
   int dataSize = StringToCharArray(json, postData, 0, StringLen(json));
   
   string headers = "Content-Type: application/json\r\n";
   headers += "Authorization: Bearer " + API_KEY + "\r\n";
   
   char result[];
   string responseHeaders;
   
   int timeout = 45000; // 45 secondes
   
   // Réinitialiser l'erreur
   ResetLastError();
   
   int res = WebRequest("POST", url, headers, timeout, postData, result, responseHeaders);
   
   Print("WebRequest result: ", res, " (200 = OK)");
   
   if(res == 200)
   {
      string response = CharArrayToString(result);
      return ExtractContentFromResponse(response);
   }
   else
   {
      Print("LastError: ", GetLastError());
      Print("Response headers: ", responseHeaders);
      if(ArraySize(result) > 0)
      {
         string errorBody = CharArrayToString(result);
         Print("Error body: ", errorBody);
      }
      return "";
   }
}

//+------------------------------------------------------------------+
//| Échappe les caractères pour l'API                               |
//+------------------------------------------------------------------+
string EscapeJSONForAPI(string text)
{
   string result = "";
   for(int i = 0; i < StringLen(text); i++)
   {
      ushort ch = StringGetCharacter(text, i);
      
      if(ch == '"')
         result += "\\\"";
      else if(ch == '\\')
         result += "\\\\";
      else if(ch == '\n')
         result += "\\n";
      else if(ch == '\r')
         result += "\\r";
      else if(ch == '\t')
         result += "\\t";
      else if(ch < 32)
         continue; // Ignorer autres caractères de contrôle
      else
         result += ShortToString(ch);
   }
   return result;
}

//+------------------------------------------------------------------+
//| Extrait le contenu de la réponse JSON                           |
//+------------------------------------------------------------------+
string ExtractContentFromResponse(string response)
{
   // Recherche du champ "content"
   int searchPos = 0;
   string searchStr = "\"content\":";
   
   int pos = StringFind(response, searchStr, searchPos);
   if(pos < 0)
   {
      Print("Champ 'content' non trouvé");
      return response;
   }
   
   pos += StringLen(searchStr);
   
   // Sauter les espaces
   while(pos < StringLen(response) && StringGetCharacter(response, pos) == ' ')
      pos++;
   
   // Vérifier si le contenu commence par un guillemet
   if(StringGetCharacter(response, pos) != '"')
   {
      Print("Format de contenu inattendu");
      return response;
   }
   
   pos++;
   
   // Extraire jusqu'au guillemet fermant
   int end = pos;
   while(end < StringLen(response))
   {
      ushort ch = StringGetCharacter(response, end);
      if(ch == '"')
      {
         // Vérifier si ce n'est pas un guillemet échappé
         if(end > 0 && StringGetCharacter(response, end-1) != '\\')
            break;
      }
      end++;
   }
   
   if(end <= pos)
      return response;
   
   string content = StringSubstr(response, pos, end - pos);
   
   // Déséchapper les caractères
   content = StringReplace(content, "\\\"", "\"");
   content = StringReplace(content, "\\n", "\n");
   content = StringReplace(content, "\\r", "\r");
   content = StringReplace(content, "\\t", "\t");
   content = StringReplace(content, "\\\\", "\\");
   
   return content;
}

//+------------------------------------------------------------------+
//| Affiche l'analyse sur le graphique                              |
//+------------------------------------------------------------------+
void DisplayOnChart(string analysis)
{
   string display = "";
   display += "========== DEEPSEEK ICT/SMC ==========\n";
   display += "Heure: " + TimeToString(TimeCurrent()) + "\n";
   display += "=====================================\n\n";
   
   if(StringLen(analysis) > 800)
      display += StringSubstr(analysis, 0, 800) + "...\n";
   else
      display += analysis + "\n";
   
   display += "\n=====================================\n";
   display += "Prochaine analyse dans " + string(AnalysisIntervalMinutes) + " min";
   
   Comment(display);
}

//+------------------------------------------------------------------+
//| Vérifie et génère des alertes                                   |
//+------------------------------------------------------------------+
void CheckForAlerts(string analysis)
{
   // Recherche de setup LONG haute probabilité
   if(StringFind(analysis, "\"type\":\"long\"") >= 0 && 
      StringFind(analysis, "\"probabilite\":\"haute\"") >= 0)
   {
      Alert("🔔 DEEPSEEK: Setup LONG a haute probabilite detecte!");
      PlaySound("alert.wav");
   }
   
   // Recherche de setup SHORT haute probabilité
   if(StringFind(analysis, "\"type\":\"short\"") >= 0 && 
      StringFind(analysis, "\"probabilite\":\"haute\"") >= 0)
   {
      Alert("🔔 DEEPSEEK: Setup SHORT a haute probabilite detecte!");
      PlaySound("alert.wav");
   }
   
   // Recherche d'alerte personnalisée
   int start = StringFind(analysis, "\"alert\":\"");
   if(start >= 0)
   {
      start += 9;
      int end = start;
      while(end < StringLen(analysis))
      {
         ushort ch = StringGetCharacter(analysis, end);
         if(ch == '"')
         {
            if(end > 0 && StringGetCharacter(analysis, end-1) != '\\')
               break;
         }
         end++;
      }
      
      if(end > start)
      {
         string alertMsg = StringSubstr(analysis, start, end - start);
         if(StringLen(alertMsg) > 0)
         {
            Alert("🔔 DEEPSEEK: ", alertMsg);
            PlaySound("alert.wav");
         }
      }
   }
}

//+------------------------------------------------------------------+
