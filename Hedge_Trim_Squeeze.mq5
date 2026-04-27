//+------------------------------------------------------------------+
//|                                                         Test.mq5 |
//|                                  Copyright 2026, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, MetaQuotes Ltd."
#property link "https://www.mql5.com"
#property version "1.00"
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#property strict
#include <Trade/Trade.mqh>
#include <Arrays/ArrayObj.mqh>
CTrade trade;

//input int delayInit = 1;
input int initPosType = 0;
input double initPosVolume = 1.0;
input long Threshold_Pip = 300;
input long HedgeTP_Pip = 500;
input double SymbolPoint = 0.01;
input int VolDigits = 2;

double g_startEquity = 0;
bool g_startEquityReady = false;
bool g_initDone = false;

double NormalizeVolume(double volume)
{
    double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    double minV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double maxV = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

    if (step <= 0)
        return volume;

    volume = MathFloor(volume / step) * step;

    if (maxV > 0 && volume > maxV)
        volume = maxV;

    if (volume < minV)
        return 0;

    return NormalizeDouble(volume, VolDigits);
}

int OnInit()
{
    g_startEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    g_startEquityReady = true;
    Print("[EA] Start equity captured: ", g_startEquity);

    return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    // if (!g_initDone)
    // {
    //     if (SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE) == SYMBOL_TRADE_MODE_FULL)
    //     {
    //         Init();
    //     }
    //     else
    //     {
    //         Print("[EA] Waiting for market to open...");
    //         return;
    //     }
    // }

    HedgeStart();
    HedgeSqueeze();
    ClosePositionByTP();
    CloseAllPendingOrders();
    //PlacePostions();
    //Reset();
}
//+------------------------------------------------------------------+

void PlacePostions()
{
    PlacePostion(2026, 4, 1, 1, 30, 0, initPosType == 0 ? POSITION_TYPE_BUY : POSITION_TYPE_SELL, initPosVolume);
    //PlacePostions(2026, 4, 1, 1, 35, 0, POSITION_TYPE_BUY, 0.085);
    //PlacePostions(2026, 4, 1, 1, 45, 0, POSITION_TYPE_BUY, 0.089);
}

void CloseAllPendingOrders()
{
    if (PositionsTotal() == 0 && OrdersTotal() > 0)
    {
        for (int i = OrdersTotal() - 1; i >= 0; i--)
        {
            ulong ticket = OrderGetTicket(i);
            if (OrderSelect(ticket))
            {
                int order_type = (int)OrderGetInteger(ORDER_TYPE);
                if (order_type == ORDER_TYPE_BUY_STOP || order_type == ORDER_TYPE_SELL_STOP)
                {
                    if (trade.OrderDelete(ticket))
                        Print("[EA] Pending order deleted: ticket=", ticket);
                    else
                        Print("[EA] Error deleting order: ticket=", ticket, " error=", _LastError);
                }
            }
        }
    }
}

void HedgeStart()
{
    double totalBuyVolume = 0;
    double totalSellVolume = 0;

    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == _Symbol)
        {
            int posType = (int)PositionGetInteger(POSITION_TYPE);
            double vol = PositionGetDouble(POSITION_VOLUME);
            if (posType == POSITION_TYPE_BUY)
                totalBuyVolume += vol;
            else if (posType == POSITION_TYPE_SELL)
                totalSellVolume += vol;
        }
    }

    double diff = 0;

    if (OrdersTotal() == 0)
    {
        if (totalBuyVolume > totalSellVolume)
        {
            diff = NormalizeDouble(totalBuyVolume - totalSellVolume, VolDigits);
            if (diff <= 0)
                return;
            double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double orderPrice = NormalizeDouble(currentBid - Threshold_Pip * SymbolPoint, _Digits);
            double tp = NormalizeDouble(orderPrice - HedgeTP_Pip * SymbolPoint, _Digits);
            if (trade.SellStop(diff, orderPrice, _Symbol, 0, 0))
                Print("[EA] SellStop placed: price=", orderPrice, " vol=", diff);
            else
                Print("[EA] Error placing SellStop: price=", orderPrice, " vol=", diff, " error=", _LastError);
        }
        else if (totalSellVolume > totalBuyVolume)
        {
            diff = NormalizeDouble(totalSellVolume - totalBuyVolume, VolDigits);
            if (diff <= 0)
                return;
            double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double orderPrice = NormalizeDouble(currentAsk + Threshold_Pip * SymbolPoint, _Digits);
            double tp = NormalizeDouble(orderPrice + HedgeTP_Pip * SymbolPoint, _Digits);
            if (trade.BuyStop(diff, orderPrice, _Symbol, 0, 0))
                Print("[EA] BuyStop placed: price=", orderPrice, " vol=", diff);
            else
                Print("[EA] Error placing BuyStop: price=", orderPrice, " vol=", diff, " error=", _LastError);
        }
    }
}

void SetPositionTP()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == _Symbol)
        {
            int posType = (int)PositionGetInteger(POSITION_TYPE);
            double price = PositionGetDouble(POSITION_PRICE_OPEN);
            double currentTP = PositionGetDouble(POSITION_TP);
            double tp = 0;

            if (currentTP == 0)
            {
                if (posType == POSITION_TYPE_BUY)
                    tp = NormalizeDouble(price + HedgeTP_Pip * SymbolPoint, _Digits);
                else if (posType == POSITION_TYPE_SELL)
                    tp = NormalizeDouble(price - HedgeTP_Pip * SymbolPoint, _Digits);

                double currentSL = PositionGetDouble(POSITION_SL);
                if (trade.PositionModify(ticket, currentSL, tp))
                    Print("[EA] PositionModify TP set: ticket=", ticket, " tp=", tp);
                else
                    Print("[EA] Error modifying position TP: ticket=", ticket, " error=", _LastError);
            }
        }
    }
}

void ClosePositionByTP()
{
    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        double positionTPUSD = 0;
        double currentTP = 0;
        if (PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == _Symbol)
        {
            double price = PositionGetDouble(POSITION_PRICE_OPEN);
            int posType = (int)PositionGetInteger(POSITION_TYPE);
            double posVolume = PositionGetDouble(POSITION_VOLUME);

            if (posType == POSITION_TYPE_BUY)
                currentTP = NormalizeDouble(price + HedgeTP_Pip * SymbolPoint, _Digits);
            else if (posType == POSITION_TYPE_SELL)
                currentTP = NormalizeDouble(price - HedgeTP_Pip * SymbolPoint, _Digits);

            double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

            if (currentTP > 0 && ((posType == POSITION_TYPE_BUY && currentPrice >= currentTP) ||
                                  (posType == POSITION_TYPE_SELL && currentPrice <= currentTP)))
            {
                if (posType == POSITION_TYPE_BUY)
                    positionTPUSD = posVolume * (currentTP - price) / SymbolPoint;
                else
                    positionTPUSD = posVolume * (price - currentTP) / SymbolPoint;

                if (trade.PositionClose(ticket))
                {
                    Print("[EA] Position closed at TP: ", currentTP, " posPrice=", price, " profit USD=", positionTPUSD, " vol=", posVolume);
                    HedgeTrim(posType, posVolume, positionTPUSD);
                }
                else
                    Print("[EA] Error closing position at TP: ", _LastError);
            }
        }
    }
}

void HedgeTrim(int posTPType, double posTPVolume, double posTPUSD)
{
    if (PositionsTotal() == 0 || SymbolPoint <= 0)
        return;

    // double volStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    // double minVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    // double maxVol = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

    double keepUSD = posTPVolume * 100;
    double paidUSD = posTPUSD - keepUSD;
    Print("[EA] HedgeTrim start: paidUSD=", paidUSD, " keepUSD=", keepUSD, " posTPUSD=", posTPUSD, " posTPVolume=", posTPVolume);

    if (paidUSD <= 0)
        return;

    // Nếu lệnh đóng là sell → trim buy, và ngược lại
    int targetType = (posTPType == POSITION_TYPE_SELL) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;

    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // Thu thập và sắp xếp các position theo khoảng cách giảm dần (xa nhất trước)
    ulong tickets[];
    double distances[];
    int count = 0;

    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if (PositionSelectByTicket(ticket) && PositionGetString(POSITION_SYMBOL) == _Symbol)
        {
            if ((int)PositionGetInteger(POSITION_TYPE) == targetType)
            {
                double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
                double distance = MathAbs(currentPrice - openPrice);
                ArrayResize(tickets, count + 1);
                ArrayResize(distances, count + 1);
                tickets[count] = ticket;
                distances[count] = distance;
                count++;
            }
        }
    }

    // Sắp xếp bubble sort theo distance giảm dần
    for (int a = 0; a < count - 1; a++)
        for (int b = a + 1; b < count; b++)
            if (distances[b] > distances[a])
            {
                double tmpD = distances[a];
                distances[a] = distances[b];
                distances[b] = tmpD;
                ulong tmpT = tickets[a];
                tickets[a] = tickets[b];
                tickets[b] = tmpT;
            }

    double remainingPaidUSD = paidUSD;

    for (int i = 0; i < count && remainingPaidUSD > 0; i++)
    {
        if (!PositionSelectByTicket(tickets[i]))
            continue;

        int pType = (int)PositionGetInteger(POSITION_TYPE);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double posVol = PositionGetDouble(POSITION_VOLUME);

        double closePrice = (pType == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID)
                                                         : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

        double pnlUSD = 0;
        if (pType == POSITION_TYPE_BUY)
            pnlUSD = posVol * (closePrice - openPrice) / SymbolPoint;
        else
            pnlUSD = posVol * (openPrice - closePrice) / SymbolPoint;

        double absPnLUSD = MathAbs(pnlUSD);
        if (absPnLUSD <= 0)
            continue;

        // Tính theo từng lệnh: trimVolume = NormalizeVolume(remainingPaidUSD / profit/loss_lenh * posTPVolume)
        double trimVolume = NormalizeDouble(remainingPaidUSD * posVol / absPnLUSD, VolDigits);
        if (trimVolume <= 0)
            continue;

        Print("[EA] HedgeTrim calc: ticket=", tickets[i], " remainingPaidUSD=", remainingPaidUSD,
              " absPnLUSD=", absPnLUSD, " trimVolume=", trimVolume, " posVol=", posVol, " openPrice=", openPrice, " closePrice=", closePrice);
        Print("[EA] HedgeTrim prices: openPrice=", openPrice, " closePrice=", closePrice);
        
        //Print("[EA] HedgeTrim params: SymbolPoint=", SymbolPoint, " volStep=", volStep, " minVol=", minVol, " maxVol=", maxVol);

        if (trimVolume <= posVol)
        {
            bool ok = false;
            if (trimVolume < posVol)
                ok = trade.PositionClosePartial(tickets[i], trimVolume);
            else
                ok = trade.PositionClose(tickets[i]);

            if (ok)
            {
                double usedUSD = absPnLUSD * (trimVolume / posVol);
                double lostUSD = (pnlUSD < 0) ? usedUSD : 0;
                Print("[EA] HedgeTrim close one: ticket=", tickets[i], " closeVol=", trimVolume,
                      " usedUSD=", usedUSD, " lost USD=", lostUSD);
                return;
            }
            else
                Print("[EA] Error close one (trim): ticket=", tickets[i], " closeVol=", trimVolume, " error=", _LastError);
        }
        else
        {
            if (trade.PositionClose(tickets[i]))
            {
                double usedUSD = absPnLUSD;
                double lostUSD = (pnlUSD < 0) ? usedUSD : 0;
                remainingPaidUSD -= usedUSD;
                Print("[EA] HedgeTrim close full and continue: ticket=", tickets[i], " closeVol=", posVol,
                      " usedUSD=", usedUSD, " lost USD=", lostUSD, " remainingPaidUSD=", remainingPaidUSD);
            }
            else
                Print("[EA] Error close full (trim): ticket=", tickets[i], " error=", _LastError);
        }
    }
}

bool FindNearestPositionPrice(int targetPosType, double refPrice, double &outPrice)
{
    double minDistance = DBL_MAX;
    bool found = false;

    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong posTicket = PositionGetTicket(i);
        if (PositionSelectByTicket(posTicket) && PositionGetString(POSITION_SYMBOL) == _Symbol)
        {
            if ((int)PositionGetInteger(POSITION_TYPE) == targetPosType)
            {
                double p = PositionGetDouble(POSITION_PRICE_OPEN);
                double d = MathAbs(p - refPrice);
                if (d < minDistance)
                {
                    minDistance = d;
                    outPrice = p;
                    found = true;
                }
            }
        }
    }

    return found;
}

void HedgeSqueeze()
{
    if (OrdersTotal() != 1)
        return;

    double totalBuyVolume = 0;
    double totalSellVolume = 0;

    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong posTicket = PositionGetTicket(i);
        if (PositionSelectByTicket(posTicket) && PositionGetString(POSITION_SYMBOL) == _Symbol)
        {
            int posType = (int)PositionGetInteger(POSITION_TYPE);
            double vol = PositionGetDouble(POSITION_VOLUME);
            if (posType == POSITION_TYPE_BUY)
                totalBuyVolume += vol;
            else if (posType == POSITION_TYPE_SELL)
                totalSellVolume += vol;
        }
    }

    double newVolume = NormalizeVolume(MathAbs(totalBuyVolume - totalSellVolume));
    if (newVolume <= 0)
        return;

    ulong ticket = OrderGetTicket(0);
    if (!OrderSelect(ticket))
        return;

    int orderType = (int)OrderGetInteger(ORDER_TYPE);
    double orderPrice = OrderGetDouble(ORDER_PRICE_OPEN);
    double threshold = Threshold_Pip * SymbolPoint;

    double nearestPrice = 0;
    bool hasNearest = false;

    if (orderType == ORDER_TYPE_SELL_STOP)
    {
        double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        if (currentBid - orderPrice > threshold)
        {
            double newPrice = NormalizeDouble(currentBid - threshold, _Digits);
            hasNearest = FindNearestPositionPrice(POSITION_TYPE_BUY, currentBid, nearestPrice);
            if (!hasNearest || MathAbs(newPrice - nearestPrice) > threshold)
            {
                if (trade.OrderDelete(ticket) && trade.SellStop(newVolume, newPrice, _Symbol, 0, 0))
                    Print("[EA] SellStop squeezed: oldTicket=", ticket, " oldPrice=", orderPrice, " newPrice=", newPrice, " newVol=", newVolume);
                else
                    Print("[EA] Error squeezing SellStop: ticket=", ticket, " error=", _LastError, " newVol=", newVolume);
            }
            else
            {
                //Print("[EA] Skip squeeze SellStop: too close to nearest BUY price=", nearestPrice);
            }
        }
    }
    else if (orderType == ORDER_TYPE_BUY_STOP)
    {
        double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        if (orderPrice - currentAsk > threshold)
        {
            double newPrice = NormalizeDouble(currentAsk + threshold, _Digits);
            hasNearest = FindNearestPositionPrice(POSITION_TYPE_SELL, currentAsk, nearestPrice);
            if (!hasNearest || MathAbs(newPrice - nearestPrice) > threshold)
            {
                if (trade.OrderDelete(ticket) && trade.BuyStop(newVolume, newPrice, _Symbol, 0, 0))
                    Print("[EA] BuyStop squeezed: oldTicket=", ticket, " oldPrice=", orderPrice, " newPrice=", newPrice, " newVol=", newVolume);
                else
                    Print("[EA] Error squeezing BuyStop: ticket=", ticket, " error=", _LastError, " newVol=", newVolume);
            }
            else
            {
                //Print("[EA] Skip squeeze BuyStop: too close to nearest SELL price=", nearestPrice);
            }
        }
    }
}

void Init()
{
    // delay
    // Sleep(delayInit * 1000);
    double lot = NormalizeVolume(initPosVolume);
    if (lot <= 0)
    {
        Print("[EA] Init skipped: invalid lot size");
        return;
    }

    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    if (price == 0)
    {
        Print("[EA] Market is not ready, current price too low: ", SymbolInfoDouble(_Symbol, SYMBOL_ASK));
        return;
    }

    if (initPosType == 0)
    {
        if (trade.Buy(lot, _Symbol, 0, 0, 0))
        {
            g_initDone = true;
            Print("[EA] Init BUY opened: lot=", lot, " price=", SymbolInfoDouble(_Symbol, SYMBOL_ASK));
        }
        else
            Print("[EA] Init BUY failed: error=", _LastError);
    }
    else if (initPosType == 1)
    {
        if (trade.Sell(lot, _Symbol, 0, 0, 0))
        {
            g_initDone = true;
            Print("[EA] Init SELL opened: lot=", lot, " price=", SymbolInfoDouble(_Symbol, SYMBOL_BID));
        }
        else
            Print("[EA] Init SELL failed: error=", _LastError);
    }
    else
    {
        Print("[EA] Init skipped: invalid initPosType=", initPosType);
    }
}

void PlacePostion(int year, int month, int day, int hour, int minute, int second, int positionType, double volume)
{
    MqlDateTime targetStruct;
    targetStruct.year = year;
    targetStruct.mon = month;
    targetStruct.day = day;
    targetStruct.hour = hour;
    targetStruct.min = minute;
    targetStruct.sec = second;

    datetime targetTime = StructToTime(targetStruct);
    if (targetTime <= 0)
    {
        //Print("[EA] PlacePostions skipped: invalid target time");
        return;
    }

    datetime currentTime = TimeCurrent();
    if (currentTime < targetTime)
        return;

    static datetime placedTargets[];
    int placedCount = ArraySize(placedTargets);
    for (int i = 0; i < placedCount; i++)
    {
        if (placedTargets[i] == targetTime)
            return;
    }

    double lot = NormalizeVolume(volume);
    if (lot <= 0)
    {
        Print("[EA] PlacePostions skipped: invalid volume=", volume);
        return;
    }

    bool placed = false;
    if (positionType == POSITION_TYPE_BUY)
        placed = trade.Buy(lot, _Symbol, 0, 0, 0);
    else if (positionType == POSITION_TYPE_SELL)
        placed = trade.Sell(lot, _Symbol, 0, 0, 0);
    else
    {
        Print("[EA] PlacePostions skipped: invalid positionType=", positionType);
        return;
    }

    if (placed)
    {
        ArrayResize(placedTargets, placedCount + 1);
        placedTargets[placedCount] = targetTime;
        Print("[EA] PlacePostions success: type=", positionType, " vol=", lot, " target=", targetTime, " currentTime=", currentTime);
    }
    else
        Print("[EA] PlacePostions failed: type=", positionType, " vol=", lot, " error=", _LastError);
}

void Reset()
{
    if (!g_startEquityReady || SymbolPoint <= 0)
        return;

    double currentEquity = AccountInfoDouble(ACCOUNT_EQUITY);
    double equityDelta = currentEquity - g_startEquity;
    double resetThresholdUSD = initPosVolume / SymbolPoint;
    if (equityDelta < resetThresholdUSD)
        return;

    Print("[EA] Reset triggered: equityDelta=", equityDelta, " threshold=", resetThresholdUSD,
          " startEquity=", g_startEquity, " currentEquity=", currentEquity);

    for (int i = PositionsTotal() - 1; i >= 0; i--)
    {
        ulong posTicket = PositionGetTicket(i);
        if (PositionSelectByTicket(posTicket))
        {
            if (trade.PositionClose(posTicket))
                Print("[EA] Reset close position success: ticket=", posTicket);
            else
                Print("[EA] Reset close position failed: ticket=", posTicket, " error=", _LastError);
        }
    }

    for (int i = OrdersTotal() - 1; i >= 0; i--)
    {
        ulong orderTicket = OrderGetTicket(i);
        if (OrderSelect(orderTicket))
        {
            if (trade.OrderDelete(orderTicket))
                Print("[EA] Reset delete order success: ticket=", orderTicket);
            else
                Print("[EA] Reset delete order failed: ticket=", orderTicket, " error=", _LastError);
        }
    }
}
