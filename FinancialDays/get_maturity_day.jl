"""
get the maturity date of a contract based on its tradedate
and the number of years of the contract
"""
function get_maturity_day(tradingDate::Date, numYear::Int, principle="full accrual periods")

    if principle == "full accrual periods"
        maturity_day = get_next_IMM_day(tradingDate + Year(numYear))

    elseif principle == "N year after first payment"
        nextPayment = get_next_payment_day(tradingDate)
        raw = nextPayment + Year(numYear)
        maturity_day = Date(year(raw), month(raw), 20)
    end

    return maturity_day
end