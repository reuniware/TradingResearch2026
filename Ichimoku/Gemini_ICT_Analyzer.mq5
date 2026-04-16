//+------------------------------------------------------------------+
//| GEMINI SIMPLE STABLE                                             |
//+------------------------------------------------------------------+
#property strict
#property version "4.00"

input string API_KEY = "";
input int IntervalMin = 5;

datetime last = 0;

//+------------------------------------------------------------------+
int OnInit()
{
   Print("EA GEMINI SIMPLE START");
   CallGemini();
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
void OnTick()
{
   if(TimeCurrent() - last >= IntervalMin * 60)
   {
      CallGemini();
      last = TimeCurrent();
   }
}

//+------------------------------------------------------------------+
string GetData()
{
   MqlRates r[];
   ArraySetAsSeries(r, true);
   CopyRates(_Symbol, PERIOD_M5, 0, 10, r);

   string s = "";

   for(int i=0;i<10;i++)
      s += DoubleToString(r[i].close, 2) + ",";

   return s;
}

//+------------------------------------------------------------------+
void CallGemini()
{
   string url =
   "https://generativelanguage.googleapis.com/v1/models/gemini-2.5-flash:generateContent?key="
   + API_KEY;

   string prompt =
   "Analyse XAUUSD closes: " + GetData() +
   ". Return only: bullish or bearish";

   string json =
   "{\"contents\":[{\"parts\":[{\"text\":\"" + Clean(prompt) + "\"}]}]}";

   char data[];
   char result[];
   string headers = "Content-Type: application/json\r\n";

   StringToCharArray(json, data, 0, WHOLE_ARRAY, CP_UTF8);

   ResetLastError();

   int res = WebRequest(
      "POST",
      url,
      headers,
      10000,
      data,
      result,
      headers
   );

   if(res == -1)
   {
      Print("WebRequest error: ", GetLastError());
      return;
   }

   string out = CharArrayToString(result, 0, -1, CP_UTF8);

   Print("GEMINI => ", out);
}

//+------------------------------------------------------------------+
string Clean(string s)
{
   StringReplace(s, "\"", "");
   StringReplace(s, "\n", " ");
   StringReplace(s, "\r", " ");
   return s;
}
