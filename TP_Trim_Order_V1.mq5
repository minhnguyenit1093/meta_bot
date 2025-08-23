//+------------------------------------------------------------------+
//|                                             TP_Trim_Order_V1.mq5 |
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
input long FirstPosTPIntervalInPip = 200;
input long ProtectThresholdInPip = 200;

//--- Global variables
long FirstPosTPInPip = PosTPInPip - FirstPosTPIntervalInPip;
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

    //double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    //trade.Buy(1, _Symbol, price, 0, price + 10);

    //trade.SellStop(1, price - 1.5, _Symbol, 0, 0);
    //double sellOrderPrice = price - ProtectThresholdInPip * SymbolPoint;
    //trade.SellStop(1, sellOrderPrice, _Symbol, 0, sellOrderPrice - 10);

    return (INIT_SUCCEEDED);
}

void OnTick()
{
    Squeeze();
    // Trim positions
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
                    if (TPInPrice < PosPrice)
                    {
                        TPInPrice = 0.0;
                        IsTouchTP = false;
                        Flag = 0;
                        Print("[EA] Target position changed to Buy: ", posVolume, " at price: ", NormalizeDouble(PosPrice, _Digits));
                    }
                    
                    datetime now = TimeCurrent(); 
                    MqlDateTime t;
                    TimeToStruct(now, t);
                    if(t.sec == 0)
                    {
                        Print("[EA] Target position ticket: ", PosTicket, ", buy: ", posVolume, " at price: ", NormalizeDouble(PosPrice, _Digits), " TPInPrice: ", TPInPrice, ", IsTouchTP: ", IsTouchTP, ", Flag: ", Flag);
                    }
                    
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
                        Print("[EA] Init TPInPrice: ", TPInPrice);
                    }
                    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
                    if (currentPrice > TPInPrice)
                    {
                        IsTouchTP = true;
                        if (Flag == 0)
                        {
                            Print("[EA] Position ticket: ", PosTicket, ", buy: ", posVolume, " lots touch TP: ", TPInPrice);
                            Flag++;
                        }

                        if (currentPrice > TPInPrice)
                        {
                            TPInPrice = currentPrice;
                            Print("[EA] Position ticket: ", PosTicket, ", buy: ", posVolume, " lots TPInPrice move to: ", TPInPrice);
                        }
                    }
                    if (IsTouchTP && currentPrice < TPInPrice - MovingTPThresholdInPrice)
                    {
                        if (PositionsTotal() == 1)
                        {
                            trade.PositionClose(PosTicket);
                            Print("[EA] Position ticket: ", PosTicket, ", buy: ", posVolume, " lots TP at: ", currentPrice);
                            TPInPrice = 0.0;
                            IsTouchTP = false;
                            Flag = 0;
                            CloseAllOrders();
                        }
                        else if (PositionsTotal() > 1)
                        {
                            double TPUSD = PositionGetDouble(POSITION_PROFIT);
                            double PositionVolume = PositionGetDouble(POSITION_VOLUME);
                            trade.PositionClose(PosTicket);
                            Print("[EA] Position ticket: ", PosTicket, ", buy: ", posVolume, " lots TP at: ", currentPrice, ", USD: ", TPUSD);
                            TPInPrice = 0.0;
                            IsTouchTP = false;
                            Flag = 0;
                            
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
                                    double RemainVolume = NormalizeDouble((RemainLostUSD / TotalLostUSD * TrimPositionVolume), 2);
                                    double CloseVolumn = TrimPositionVolume - RemainVolume;
                                    trade.PositionClosePartial(trimPosTicket, CloseVolumn);
                                    Print("[EA] Lost USD: ", TotalLostUSD, ", Apply USD: ", ApplyUSD, ", Remain USD: ", RemainLostUSD);
                                    Print("[EA] Position ticket: ", trimPosTicket, ", sell: ", TrimPositionVolume, " lots closed: ", CloseVolumn, " at price: ", currentPrice);
                                }
                                else
                                {
                                    trade.PositionClose(trimPosTicket);
                                    Print("[EA] Lost USD: ", TotalLostUSD, ", Apply USD: ", ApplyUSD, ", Remain USD: ", RemainLostUSD);
                                    Print("[EA] Position ticket: ", trimPosTicket, ", sell: ", TrimPositionVolume, " lots closed at price: ", currentPrice);

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
                                        Print("[EA] Lost USD: ", TotalLostUSD, ", Apply USD: ", ApplyUSD, ", Remain USD: ", RemainLostUSD);
                                        Print("[EA] Position ticket: ", trimPosTicket, ", sell: ", TrimPositionVolume, " lots closed: ", CloseVolumn, " at price: ", currentPrice);
                                    }
                                }

                                // new order
                                double diffVolume = GetDifferenceVolumeBuyAndSell();
                                if (diffVolume > 0)
                                {
                                    double buyOrderPrice = NormalizeDouble(currentPrice + ProtectThresholdInPip * SymbolPoint, _Digits);
                                    if (trade.BuyStop(diffVolume, buyOrderPrice, _Symbol, 0, 4000))
                                    {
                                        Print("[EA] Place Buy order ", diffVolume, " lot tại ", buyOrderPrice);
                                    }
                                }
                            }
                        }
                    }
                }
                else if (type == POSITION_TYPE_SELL)
                {
                    if (TPInPrice > PosPrice)
                    {
                        TPInPrice = 0.0;
                        IsTouchTP = false;
                        Flag = 0;
                        Print("[EA] Target position changed to Sell: ", posVolume, " at price: ", NormalizeDouble(PosPrice, _Digits));
                    }
                    
                    datetime now = TimeCurrent(); 
                    MqlDateTime t;
                    TimeToStruct(now, t);
                    if(t.sec == 0)
                    {
                        Print("[EA] Target position ticket: ", PosTicket, ", sell: ", posVolume, " at price: ", NormalizeDouble(PosPrice, _Digits), ", TPInPrice: ", TPInPrice, ", IsTouchTP: ", IsTouchTP, ", Flag: ", Flag);
                    }
                    
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
                        Print("[EA] Init TPInPrice: ", TPInPrice);
                    }
                    
                    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
                    if (currentPrice < TPInPrice)
                    {
                        IsTouchTP = true;
                        if (Flag == 0)
                        {
                            Print("[EA] Position ticket: ", PosTicket, ", sell: ", posVolume, " lots touch TP: ", TPInPrice);
                            Flag++;
                        }

                        if (currentPrice < TPInPrice)
                        {
                            TPInPrice = currentPrice;
                            Print("[EA] Position ticket: ", PosTicket, ", sell: ", posVolume, " lots TPInPrice move to: ", TPInPrice);
                        }
                    }
                    if (IsTouchTP && currentPrice > TPInPrice + MovingTPThresholdInPrice)
                    {
                        if (PositionsTotal() == 1)
                        {
                            trade.PositionClose(PosTicket);
                            Print("[EA] Position ticket: ", PosTicket, ", sell: ", posVolume, " lots TP at: ", currentPrice);
                            TPInPrice = 0.0;
                            IsTouchTP = false;
                            Flag = 0;
                            CloseAllOrders();
                        }
                        else if (PositionsTotal() > 1)
                        {
                            double TPUSD = PositionGetDouble(POSITION_PROFIT);
                            double PositionVolume = PositionGetDouble(POSITION_VOLUME);
                            trade.PositionClose(PosTicket);
                            Print("[EA] Position ticket: ", PosTicket, ", sell: ", posVolume, " lots TP at: ", currentPrice, ", USD: ", TPUSD);
                            TPInPrice = 0.0;
                            IsTouchTP = false;
                            Flag = 0;


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
                                    double RemainVolume = NormalizeDouble((RemainLostUSD / TotalLostUSD * TrimPositionVolume), 2);
                                    double CloseVolumn = TrimPositionVolume - RemainVolume;
                                    trade.PositionClosePartial(trimPosTicket, CloseVolumn);
                                    Print("[EA] Lost USD: ", TotalLostUSD, ", Apply USD: ", ApplyUSD, ", Remain USD: ", RemainLostUSD);
                                    Print("[EA] Position ticket: ", trimPosTicket, ", buy: ", TrimPositionVolume, " lots closed: ", CloseVolumn, " at price: ", currentPrice);
                                }
                                else
                                {
                                    trade.PositionClose(trimPosTicket);
                                    Print("[EA] Lost USD: ", TotalLostUSD, ", Apply USD: ", ApplyUSD, ", Remain USD: ", RemainLostUSD);
                                    Print("[EA] Position ticket: ", trimPosTicket, ", buy: ", TrimPositionVolume, " lots closed at price: ", currentPrice);

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
                                        Print("[EA] Lost USD: ", TotalLostUSD, ", Apply USD: ", ApplyUSD, ", Remain USD: ", RemainLostUSD);
                                        Print("[EA] Position ticket: ", trimPosTicket, ", buy: ", TrimPositionVolume, " lots closed: ", CloseVolumn, " at price: ", currentPrice);
                                    }
                                }
                                
                                // new order
                                double diffVolume = GetDifferenceVolumeBuyAndSell();
                                if (diffVolume > 0)
                                {
                                    double sellOrderPrice = NormalizeDouble(currentPrice - ProtectThresholdInPip * SymbolPoint, _Digits);
                                    if (trade.SellStop(diffVolume, sellOrderPrice, _Symbol, 0, 2000))
                                    {
                                        Print("[EA] Place Sell order ", diffVolume, " lot tại ", sellOrderPrice);
                                    }
                                }
                            }
                        }
                    }
                }
                break;
            }
        }
    }
}
//+------------------------------------------------------------------+
void CloseAllOrders()
{
    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong orderTicket = OrderGetTicket(i);
        if (OrderSelect(orderTicket))
        {
            trade.OrderDelete(orderTicket);
            Print("[EA] Đóng Order: ", orderTicket);
        }
    }
}

//+------------------------------------------------------------------+
void Squeeze()
{
    if (OrdersTotal() == 1)
    {
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        ulong orderTicket = OrderGetTicket(0);
        if (OrderSelect(orderTicket))
        {
            double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
            if (MathAbs(currentPrice - orderPrice) > ProtectThresholdInPip * SymbolPoint)
            {
                ENUM_ORDER_TYPE orderType = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
                if (orderType == ORDER_TYPE_BUY_STOP)
                {
                    double maxSellPositionPrice = GetMinMaxPositionPriceByType(POSITION_TYPE_SELL);
                    double newOrderPrice = NormalizeDouble(currentPrice + ProtectThresholdInPip * SymbolPoint, _Digits);
                    if (newOrderPrice >= maxSellPositionPrice + ProtectThresholdInPip * SymbolPoint)
                    {
                        trade.OrderModify(orderTicket, newOrderPrice, 0, newOrderPrice + 10, ORDER_TIME_GTC, 0);
                        Print("[EA] Modify buy order from: ", orderPrice, " to: ", newOrderPrice);
                    }
                }
                else if (orderType == ORDER_TYPE_SELL_STOP)
                {
                    double minBuyPositionPrice = GetMinMaxPositionPriceByType(POSITION_TYPE_BUY);
                    double newOrderPrice = NormalizeDouble(currentPrice - ProtectThresholdInPip * SymbolPoint, _Digits);
                    if (newOrderPrice <= minBuyPositionPrice - ProtectThresholdInPip * SymbolPoint)
                    {
                        trade.OrderModify(orderTicket, newOrderPrice, 0, newOrderPrice - 10, ORDER_TIME_GTC, 0);
                        Print("[EA] Modify sell order from: ", orderPrice, " to: ", newOrderPrice);
                    }
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
double GetMinMaxPositionPriceByType(ENUM_POSITION_TYPE type)
{
    double price = 0.0;
    for (int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket))
        {
            if (type == POSITION_TYPE_BUY)
            {
                if (price == 0.0 || PositionGetDouble(POSITION_PRICE_OPEN) < price)
                {
                    price = PositionGetDouble(POSITION_PRICE_OPEN);
                }
            }
            else if (type == POSITION_TYPE_SELL)
            {
                if (price == 0.0 || PositionGetDouble(POSITION_PRICE_OPEN) > price)
                {
                    price = PositionGetDouble(POSITION_PRICE_OPEN);
                }
            }
        }
    }
    return price;
}

//+------------------------------------------------------------------+
double GetDifferenceVolumeBuyAndSell()
{
    double buyVolume = 0.0;
    double sellVolume = 0.0;

    for (int i = 0; i < PositionsTotal(); i++)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket))
        {
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double volume = PositionGetDouble(POSITION_VOLUME);

            if (type == POSITION_TYPE_BUY)
            {
                buyVolume += volume;
            }
            else if (type == POSITION_TYPE_SELL)
            {
                sellVolume += volume;
            }
        }
    }

    return MathAbs(buyVolume - sellVolume);
}

//+------------------------------------------------------------------+
void PlaceNewOrder(ENUM_ORDER_TYPE orderType, double volume, double price, string symbol)
{
    if (orderType == ORDER_TYPE_BUY_STOP)
    {
        if (trade.BuyStop(volume, price, symbol, 0, 4000))
        {
            Print("[EA] Buy stop order placed: ", volume, " lots at price: ", price);
        }
    }
    else if (orderType == ORDER_TYPE_SELL_STOP)
    {
        if (trade.SellStop(volume, price, symbol, 0, 2000))
        {
            Print("[EA] Sell stop order placed: ", volume, " lots at price: ", price);
        }
    }
    
}
