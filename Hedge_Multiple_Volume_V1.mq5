//+------------------------------------------------------------------+
//|                                        Hedge_Multiple_Volume.mq5 |
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
input double InitialVolume = 0.01;
input double MaxVolume = 1.28;
input int MaxSL = 120;
input double SymbolPoint = 0.01;
input double SpreadInPip = 20;
input long CandleVolume = 2000;

input bool CheckTime = true;
input bool CheckVolume = true;

//--- Global variables
double BuyPrice = 0.0;
double SellPrice = 0.0;
double TPBuyPrice = 0.0;
double TPSellPrice = 0.0;
double VolumeArray[] = { InitialVolume, 2*InitialVolume, 4*InitialVolume, 8*InitialVolume, 16*InitialVolume, 32*InitialVolume, 64*InitialVolume, 128*InitialVolume };
bool PrintMaxVol = true;


int OnInit()
{
    Print("***[EA]*** Start!!!");
    return (INIT_SUCCEEDED);
}

void OnTick()
{
    if (PositionsTotal() == 0 && OrdersTotal() == 0)
    {
        if (CheckCondition()) {
            Print("***[EA]*** New Cycle ---------------------------------------------------");
            Init();
        }
    }

    if (PositionsTotal() > 0 && OrdersTotal() == 0 && GetMaxVolumePosition() < MaxVolume)
    {
        double volume = VolumeArray[PositionsTotal()];
        if (Type == 0)
        {
            if (PositionsTotal() % 2 == 0)
            {
                trade.BuyStop(volume, BuyPrice, _Symbol, TPSellPrice, TPBuyPrice);
                Print("***[EA]*** Place BUY Order, volume: ", volume);
            }
            else
            {
                trade.SellStop(volume, SellPrice, _Symbol, TPBuyPrice, TPSellPrice);
                Print("***[EA]*** Place SELL Order, volume: ", volume);
            }
        }
        else if (Type == 1)
        {
            if (PositionsTotal() % 2 == 0)
            {
                trade.SellStop(volume, SellPrice, _Symbol, TPBuyPrice, TPSellPrice);
                Print("***[EA]*** Place SELL Order, volume: ", volume);
            }
            else
            {
                trade.BuyStop(volume, BuyPrice, _Symbol, TPSellPrice, TPBuyPrice);
                Print("***[EA]*** Place BUY Order, volume: ", volume);
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

    if (GetMaxVolumePosition() == MaxVolume)
    {
        if (PrintMaxVol)
        {
            Print("***[EA]*** Position Max volume!!!");
            PrintMaxVol = false;
        }
        if (GetTotalProfit() <= -MaxSL)
        {
            CloseAllPositions();
            CloseAllOrders();
            Print("***[EA]*** SL, Loss 120$ !!!");
            return;
        }
    }
}

void Init()
{
    PrintMaxVol = true;
    if (Type == 0)
    {
        BuyPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        SellPrice = NormalizeDouble(BuyPrice - HedgeInPip * SymbolPoint, _Digits);
        TPBuyPrice = NormalizeDouble(BuyPrice + (TPInPip + SpreadInPip) * SymbolPoint, _Digits);
        TPSellPrice = NormalizeDouble(SellPrice - TPInPip * SymbolPoint, _Digits);
        trade.Buy(InitialVolume, _Symbol, BuyPrice, TPSellPrice, TPBuyPrice);
        Print("***[EA]*** Place BUY Position, volume: ", InitialVolume);
    }
    else if (Type == 1)
    {
        SellPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        BuyPrice = NormalizeDouble(SellPrice + HedgeInPip * SymbolPoint, _Digits);
        TPBuyPrice = NormalizeDouble(BuyPrice + (TPInPip + SpreadInPip) * SymbolPoint, _Digits);
        TPSellPrice = NormalizeDouble(SellPrice - TPInPip * SymbolPoint, _Digits);
        trade.Sell(InitialVolume, _Symbol, SellPrice, TPBuyPrice, TPSellPrice);
        Print("***[EA]*** Place SELL Position, volume: ", InitialVolume);
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

long GetM5Volume(int shift=0)
{
   return iVolume(_Symbol, PERIOD_M5, shift);
}

bool CheckCondition()
{
    bool passTimeCheck = true;
    bool passVolumnCheck = true;
    
    if (IsM5VolumeOver(CandleVolume))
        return true;
    
    //if (CheckTime)
    //{
        //passTimeCheck = IsM5InFirst3Minutes();
    //}

    if (CheckVolume)
    {
        passVolumnCheck = CheckVolumeFunc(CandleVolume);
    }

    return (passTimeCheck && passVolumnCheck);
}

bool CheckTimeFunc()
{
   datetime now = TimeCurrent();
   MqlDateTime tm;
   TimeToStruct(now, tm);                      
   int hour = tm.hour;   
   int min = tm.min;  
   int sec = tm.sec;                     
   
   if(hour == 22)
      return false;
      
   return true;
}

bool CheckVolumeFunc(long volumne)
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

bool IsM5VolumeOver(long volThres)
{
   long vol = iVolume(NULL, PERIOD_M5, 0);
          
   if (vol > volThres)
      return true;
   return false;
}

bool IsM5InFirst3Minutes()
{
   datetime open_time = iTime(_Symbol, PERIOD_M5, 0); 
   int passed = (int)(TimeCurrent() - open_time);

   if(0 * 60 < passed && passed < 3 * 60)
      return true;
   return false;
}
