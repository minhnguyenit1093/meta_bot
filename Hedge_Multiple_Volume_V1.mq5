//+------------------------------------------------------------------+
//|                                     Hedge_Multiple_Volume_V1.mq5 |
//|                                                           minhnd |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "minhnd"
#property link "https://www.mql5.com"
#property version "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>
CTrade trade;

//--- Inputs
input int Type = 0;
input long TPInPip = 200;
input long HedgeInPip = 100;

//--- Global variables
double SymbolPoint = 0.01;
double BuyPrice = 0.0;
double SellPrice = 0.0;
double TPBuyPrice = 0.0;
double TPSellPrice = 0.0;
double Volume = 0.0;
double TrimVolume = 0.45;
bool Pause = false;
double InitialVolume = 0.01;
double MaxVolume = 1.28;
int MaxPositions = 8;
double FullPosProtectPrice = 0.0;
bool IsTouchFullPosProtect = false;
double FullPosProtectThreshold = 0.2;

int OnInit()
{
    Print("***[EA]*** Start!!!");
    return (INIT_SUCCEEDED);
}

void OnTick()
{
    if (PositionsTotal() == 0 && OrdersTotal() == 0)
    {
        IsTouchFullPosProtect = false;
        if (IsTimeToCheck() && IsM5VolumePass(2000)) {
            Print("***[EA]*** New Cycle ---------------------------------------------------");
            Init();
        }
    }

    if (PositionsTotal() > 0 && OrdersTotal() == 0 && Volume < MaxVolume)
    {
        Volume = Volume * 2;
        if (Type == 0)
        {
            if (PositionsTotal() % 2 == 0)
            {
                trade.BuyStop(Volume, BuyPrice, _Symbol, TPSellPrice, TPBuyPrice);
                Print("***[EA]*** Place BUY Order, volume: ", Volume);
            }
            else
            {
                trade.SellStop(Volume, SellPrice, _Symbol, TPBuyPrice, TPSellPrice);
                Print("***[EA]*** Place SELL Order, volume: ", Volume);
            }
        }
        else if (Type == 1)
        {
            if (PositionsTotal() % 2 == 0)
            {
                trade.SellStop(Volume, SellPrice, _Symbol, TPBuyPrice, TPSellPrice);
                Print("***[EA]*** Place SELL Order, volume: ", Volume);
            }
            else
            {
                trade.BuyStop(Volume, BuyPrice, _Symbol, TPSellPrice, TPBuyPrice);
                Print("***[EA]*** Place BUY Order, volume: ", Volume);
            }
        }
        return;
    }
    
    if (IsTakeProfit())
    {
        int buyCount = CountPositionByType(POSITION_TYPE_BUY);
        int sellCount = CountPositionByType(POSITION_TYPE_SELL);
        if ((buyCount > 0 && sellCount == 0) || (sellCount > 0 && buyCount == 0) || (buyCount == 0 && sellCount == 0 && OrdersTotal() > 0))
        {
            CloseAllPositions();
            CloseAllOrders();
            Print("***[EA]*** TP !!!");
            return;
        }
    }

    if (Volume == MaxVolume)
    {
        if (GetTotalProfit() <= -120)
        {
            CloseAllPositions();
            CloseAllOrders();
            Print("***[EA]*** Loss = 120$, SL !!!");
            return;
        }
    }
}

void Init()
{
    Volume = InitialVolume;
    if (Type == 0)
    {
        BuyPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        SellPrice = NormalizeDouble(BuyPrice - HedgeInPip * SymbolPoint, _Digits);
        TPBuyPrice = NormalizeDouble(BuyPrice + TPInPip * SymbolPoint, _Digits);
        TPSellPrice = NormalizeDouble(SellPrice - TPInPip * SymbolPoint, _Digits);
        trade.Buy(Volume, _Symbol, BuyPrice, TPSellPrice, TPBuyPrice);
        Print("***[EA]*** Place BUY Position, volume: ", Volume);
        FullPosProtectPrice = SellPrice;
    }
    else if (Type == 1)
    {
        SellPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        BuyPrice = NormalizeDouble(SellPrice + HedgeInPip * SymbolPoint, _Digits);
        TPBuyPrice = NormalizeDouble(BuyPrice + TPInPip * SymbolPoint, _Digits);
        TPSellPrice = NormalizeDouble(SellPrice - TPInPip * SymbolPoint, _Digits);
        trade.Sell(Volume, _Symbol, SellPrice, TPBuyPrice, TPSellPrice);
        Print("***[EA]*** Place SELL Position, volume: ", Volume);
        FullPosProtectPrice = BuyPrice;
    }
}

bool IsTakeProfit()
{
    double currentBidPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double currentAskPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    if (currentAskPrice > TPBuyPrice || currentBidPrice < TPSellPrice)
        return true;
    return false;
}

int CountPositionByType(ENUM_POSITION_TYPE type)   
{
    int count = 0;
    for (int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket))
        {
            if (PositionGetInteger(POSITION_TYPE) == type)
            {
                count++;
            }
        }
    }
    return count;
}

void CloseAllOrders()
{
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong orderTicket = OrderGetTicket(i);
        if (OrderSelect(orderTicket))
        {
            trade.OrderDelete(orderTicket);
            Print("***[EA]*** Đóng Order: ", orderTicket);
        }
    }
}

void CloseAllPositions()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket))
        {
            trade.PositionClose(ticket);
            Print("***[EA]*** Đóng Position: ", ticket);
        }
    }
}

double GetMaxVolumePosition()
{
    double maxVolume = 0.0;
    for (int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket))
        {
            double volume = PositionGetDouble(POSITION_VOLUME);
            if (volume > maxVolume)
            {
                maxVolume = volume;
            }
        }
    }
    return maxVolume;
}

bool CheckStartHedge()
{
    bool isHedge = true;
    for (int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket))
        {
            double posVolume = PositionGetDouble(POSITION_VOLUME);
            double intervalVolume = MaxVolume - TrimVolume;
            if (NormalizeDouble(posVolume, 2) != NormalizeDouble(intervalVolume, 2))
            {
                isHedge = false;
                break;
            }
        }
    }
    return isHedge;
}

double GetTotalProfit()
{
    double totalProfit = 0.0;
    for (int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket))
        {
            if (PositionGetString(POSITION_SYMBOL) == _Symbol)
             {
                double profit = PositionGetDouble(POSITION_PROFIT);
                totalProfit += profit;
             }
        }
    }
    return totalProfit;
}

bool IsCurrentM5CandleInRange()
{
    return true;
   //datetime candleTime = iTime(_Symbol, PERIOD_M5, 0);
   //MqlDateTime tm;
   //TimeToStruct(candleTime, tm); 
   //int hour = tm.hour; 

   //if((hour >= 7 && hour < 9) || (hour >= 14 && hour < 16) || (hour >= 19 && hour < 21))
      //return true;
   //return false;
}

long GetM5Volume(int shift=0)
{
   return iVolume(_Symbol, PERIOD_M5, shift);
}

bool IsTimeToCheck()
{
   datetime now = TimeCurrent();
   MqlDateTime tm;
   TimeToStruct(now, tm);                      
   int hour = tm.hour;   
   int min = tm.min;  
   int sec = tm.sec;                     

   if((min % 5 == 0 || min % 6 == 0 || min % 7 == 0) && sec < 30)
      return true;
   return false;
}

bool IsM5VolumePass(long volumne)
{
    long previousM5Volume = GetM5Volume(1);
    if (previousM5Volume > volumne)
    {
       datetime candleTime = iTime(_Symbol, PERIOD_M5, 0); 
       MqlDateTime tm;
       TimeToStruct(candleTime, tm);                       
       int hour = tm.hour;   
       int min = tm.min;     
       Print("Time: ", hour, ":", min - 5, ". Volume: ", previousM5Volume);
       return true;
    }
    return false;
}
