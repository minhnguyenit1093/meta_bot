//+------------------------------------------------------------------+
//|                                                   TP_Support.mq5 |
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
input long PosTPInPip = 450;
input double ProtectThresholdInPip = 200;

//--- Global variables
long FirstPosTPInPip = PosTPInPip - 250;
double SymbolPoint = 0.01;
bool IsTouchTP = false;
double MovingTPThresholdInPrice = 0.5;
long PosTicket = 0;
double PosPrice = 0.0;
double TPInPrice = 0.0;
int Flag = 0;

int OnInit()
{
    Print("[EA] Start!!!");

    //double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    //trade.Sell(1, _Symbol, price, 0, 2000);

    //trade.BuyStop(0.7, price + 3, _Symbol, 0, 0);
    //trade.BuyStop(0.3, price + 4, _Symbol, 0, 0);

    return (INIT_SUCCEEDED);
}

void OnTick()
{
    for (int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket))
        {
            if (PositionGetDouble(POSITION_TP) > 0 && PositionGetDouble(POSITION_PROFIT) > 0)
            {
                ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                PosTicket = PositionGetInteger(POSITION_TICKET);
                PosPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double posVolume = PositionGetDouble(POSITION_VOLUME);

                if (type == POSITION_TYPE_BUY)
                {
                    // TP
                    if (TPInPrice == 0)
                    {
                        if (PositionsTotal() == 1)
                        {
                            TPInPrice = NormalizeDouble(PosPrice + FirstPosTPInPip * SymbolPoint, _Digits);
                        }
                        else if (PositionsTotal() > 1)
                        {
                            TPInPrice = NormalizeDouble(PosPrice + PosTPInPip * SymbolPoint, _Digits);
                        }
                    }
                    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                    if (currentPrice > TPInPrice)
                    {
                        IsTouchTP = true;
                        if (Flag == 0)
                        {
                            Print("[EA] Position ticket:", PosTicket, ", buy: ", posVolume, " lots touch TP:", TPInPrice);
                            Flag++;
                        }

                        if (currentPrice - TPInPrice > MovingTPThresholdInPrice)
                        {
                            TPInPrice = currentPrice - MovingTPThresholdInPrice;
                            Print("[EA] Position ticket:", PosTicket, ", buy: ", posVolume, " lots TPInPrice move to: ", TPInPrice);
                        }
                    }
                    if (IsTouchTP && currentPrice < TPInPrice - MovingTPThresholdInPrice)
                    {
                        if (PositionsTotal() == 1)
                        {
                            trade.PositionClose(PosTicket);
                            Print("[EA] Position ticket:", PosTicket, ", buy: ", posVolume, " lots TP at: ", currentPrice);
                        }
                        else if (PositionsTotal() > 1)
                        {
                            double TPUSD = PositionGetDouble(POSITION_PROFIT);
                            double PositionVolume = PositionGetDouble(POSITION_VOLUME);
                            trade.PositionClose(PosTicket);
                            Print("[EA] Position ticket:", PosTicket, ", buy: ", posVolume, " lots TP at: ", currentPrice, ", USD: ", TPUSD);

                            ulong trimPosTicket = 0;
                            double minPosPrice = 0.0;
                            for (int i = 0; i < PositionsTotal(); i++)
                            {
                                ulong ticket = PositionGetTicket(i);
                                if (PositionSelectByTicket(ticket))
                                {
                                    double posPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                                    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                                    if (posType == POSITION_TYPE_SELL)
                                    {
                                        if (trimPosTicket == 0 || posPrice < minPosPrice)
                                        {
                                            trimPosTicket = ticket;
                                            minPosPrice = posPrice;
                                        }
                                    }
                                }
                            }

                            if (PositionSelectByTicket(trimPosTicket))
                            {
                                double TotalLostUSD = -PositionGetDouble(POSITION_PROFIT);
                                double TrimPositionVolume = PositionGetDouble(POSITION_VOLUME);
                                double KeepUSD = PositionVolume * 100;
                                double ApplyUSD = TPUSD - KeepUSD;
                                double RemainLostUSD = TotalLostUSD - ApplyUSD;
                                if (RemainLostUSD > 0)
                                {
                                    double RemainVolume = NormalizeDouble((RemainLostUSD / TotalLostUSD * PositionVolume), 2);
                                    double CloseVolumn = TrimPositionVolume - RemainVolume;
                                    trade.PositionClosePartial(trimPosTicket, CloseVolumn);
                                    Print("[EA] Lost USD:", TotalLostUSD, ", Apply USD:", ApplyUSD, ", Remain USD:", RemainLostUSD);
                                    Print("[EA] Position ticket:", trimPosTicket, ", sell: ", TrimPositionVolume, " lots closed: ", CloseVolumn, " at price: ", currentPrice);
                                }
                                else
                                {
                                    trade.PositionClose(trimPosTicket);
                                    Print("[EA] Lost USD:", TotalLostUSD, ", Apply USD:", ApplyUSD, ", Remain USD:", RemainLostUSD);
                                    Print("[EA] Position ticket:", trimPosTicket, ", sell: ", TrimPositionVolume, " lots closed at price: ", currentPrice);

                                    ApplyUSD = ApplyUSD - TotalLostUSD;

                                    trimPosTicket = 0;
                                    minPosPrice = 0.0;
                                    for (int i = 0; i < PositionsTotal(); i++)
                                    {
                                        ulong ticket = PositionGetTicket(i);
                                        if (PositionSelectByTicket(ticket))
                                        {
                                            double posPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                                            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                                            if (posType == POSITION_TYPE_SELL)
                                            {
                                                if (trimPosTicket == 0 || posPrice < minPosPrice)
                                                {
                                                    trimPosTicket = ticket;
                                                    minPosPrice = posPrice;
                                                }
                                            }
                                        }
                                    }

                                    if (PositionSelectByTicket(trimPosTicket))
                                    {
                                        TrimPositionVolume = PositionGetDouble(POSITION_VOLUME);
                                        TotalLostUSD = -PositionGetDouble(POSITION_PROFIT);
                                        RemainLostUSD = TotalLostUSD - ApplyUSD;
                                        double RemainVolume = NormalizeDouble((RemainLostUSD / TotalLostUSD * TrimPositionVolume), 2);
                                        double CloseVolumn = TrimPositionVolume - RemainVolume;
                                        trade.PositionClosePartial(trimPosTicket, CloseVolumn);
                                        Print("[EA] Lost USD:", TotalLostUSD, ", Apply USD:", ApplyUSD, ", Remain USD:", RemainLostUSD);
                                        Print("[EA] Position ticket:", trimPosTicket, ", sell: ", TrimPositionVolume, " lots closed: ", CloseVolumn, " at price: ", currentPrice);
                                    }
                                }
                            }

                            // new order
                            // double sellOrderPrice = NormalizeDouble(currentPrice - ProtectThresholdInPip * SymbolPoint, _Digits);
                            // if (trade.SellStop(RemainVolume, buyOrderPrice, _Symbol, 0, 0))
                            // {
                            //     Print("[EA] Đặt lệnh SellStop tại ", buyOrderPrice);
                            // }
                        }
                    }
                }
                else if (type == POSITION_TYPE_SELL)
                {
                    // TP
                    if (TPInPrice == 0)
                    {
                        if (PositionsTotal() == 1)
                        {
                            TPInPrice = NormalizeDouble(PosPrice - FirstPosTPInPip * SymbolPoint, _Digits);
                        }
                        else if (PositionsTotal() > 1)
                        {
                            TPInPrice = NormalizeDouble(PosPrice - PosTPInPip * SymbolPoint, _Digits);
                        }
                    }
                    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                    if (currentPrice < TPInPrice)
                    {
                        IsTouchTP = true;
                        if (Flag == 0)
                        {
                            Print("[EA] Position ticket:", PosTicket, ", sell: ", posVolume, " lots touch TP:", TPInPrice);
                            Flag++;
                        }

                        if (TPInPrice - currentPrice > MovingTPThresholdInPrice)
                        {
                            TPInPrice = currentPrice + MovingTPThresholdInPrice;
                            Print("[EA] Position ticket:", PosTicket, ", sell: ", posVolume, " lots TPInPrice move to: ", TPInPrice);
                        }
                    }
                    if (IsTouchTP && currentPrice > TPInPrice + MovingTPThresholdInPrice)
                    {
                        if (PositionsTotal() == 1)
                        {
                            trade.PositionClose(PosTicket);
                            Print("[EA] Position ticket:", PosTicket, ", sell: ", posVolume, " lots TP at: ", currentPrice);
                        }
                        else if (PositionsTotal() > 1)
                        {
                            double TPUSD = PositionGetDouble(POSITION_PROFIT);
                            double PositionVolume = PositionGetDouble(POSITION_VOLUME);
                            trade.PositionClose(PosTicket);
                            Print("[EA] Position ticket:", PosTicket, ", sell: ", posVolume, " lots TP at: ", currentPrice, ", USD: ", TPUSD);

                            ulong trimPosTicket = 0;
                            double maxPosPrice = 0.0;
                            for (int i = 0; i < PositionsTotal(); i++)
                            {
                                ulong ticket = PositionGetTicket(i);
                                if (PositionSelectByTicket(ticket))
                                {
                                    double posPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                                    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                                    if (posType == POSITION_TYPE_BUY)
                                    {
                                        if (trimPosTicket == 0 || posPrice > maxPosPrice)
                                        {
                                            trimPosTicket = ticket;
                                            maxPosPrice = posPrice;
                                        }
                                    }
                                }
                            }

                            if (PositionSelectByTicket(trimPosTicket))
                            {
                                double TotalLostUSD = -PositionGetDouble(POSITION_PROFIT);
                                double TrimPositionVolume = PositionGetDouble(POSITION_VOLUME);
                                double KeepUSD = PositionVolume * 100;
                                double ApplyUSD = TPUSD - KeepUSD;
                                double RemainLostUSD = TotalLostUSD - ApplyUSD;
                                if (RemainLostUSD > 0)
                                {
                                    double RemainVolume = NormalizeDouble((RemainLostUSD / TotalLostUSD * PositionVolume), 2);
                                    double CloseVolumn = TrimPositionVolume - RemainVolume;
                                    trade.PositionClosePartial(trimPosTicket, CloseVolumn);
                                    Print("[EA] Lost USD:", TotalLostUSD, ", Apply USD:", ApplyUSD, ", Remain USD:", RemainLostUSD);
                                    Print("[EA] Position ticket:", trimPosTicket, ", buy: ", TrimPositionVolume, " lots closed: ", CloseVolumn, " at price: ", currentPrice);
                                }
                                else
                                {
                                    trade.PositionClose(trimPosTicket);
                                    Print("[EA] Lost USD:", TotalLostUSD, ", Apply USD:", ApplyUSD, ", Remain USD:", RemainLostUSD);
                                    Print("[EA] Position ticket:", trimPosTicket, ", buy: ", TrimPositionVolume, " lots closed at price: ", currentPrice);

                                    ApplyUSD = ApplyUSD - TotalLostUSD;

                                    trimPosTicket = 0;
                                    maxPosPrice = 0.0;
                                    for (int i = 0; i < PositionsTotal(); i++)
                                    {
                                        ulong ticket = PositionGetTicket(i);
                                        if (PositionSelectByTicket(ticket))
                                        {
                                            double posPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                                            ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
                                            if (posType == POSITION_TYPE_BUY)
                                            {
                                                if (trimPosTicket == 0 || posPrice > maxPosPrice)
                                                {
                                                    trimPosTicket = ticket;
                                                    maxPosPrice = posPrice;
                                                }
                                            }
                                        }
                                    }

                                    if (PositionSelectByTicket(trimPosTicket))
                                    {
                                        TrimPositionVolume = PositionGetDouble(POSITION_VOLUME);
                                        TotalLostUSD = -PositionGetDouble(POSITION_PROFIT);
                                        RemainLostUSD = TotalLostUSD - ApplyUSD;
                                        double RemainVolume = NormalizeDouble((RemainLostUSD / TotalLostUSD * TrimPositionVolume), 2);
                                        double CloseVolumn = TrimPositionVolume - RemainVolume;
                                        trade.PositionClosePartial(trimPosTicket, CloseVolumn);
                                        Print("[EA] Lost USD:", TotalLostUSD, ", Apply USD:", ApplyUSD, ", Remain USD:", RemainLostUSD);
                                        Print("[EA] Position ticket:", trimPosTicket, ", buy: ", TrimPositionVolume, " lots closed: ", CloseVolumn, " at price: ", currentPrice);
                                    }
                                }
                            }

                            // new order
                            // double buyOrderPrice = NormalizeDouble(currentPrice + ProtectThresholdInPip * SymbolPoint, _Digits);
                            // if (trade.BuyStop(RemainVolume, buyOrderPrice, _Symbol, 0, 0))
                            // {
                            //     Print("[EA] Đặt lệnh BuyStop tại ", buyOrderPrice);
                            // }
                        }
                    }
                }
                break;
            }
        }
    }
}
//+------------------------------------------------------------------+
