function getEffectiveDate(tradeDate::Date, NYear::Int)
    firstpayDay = get_next_payment_day(tradeDate)
    maturityDay = get_maturity_day(tradeDate, NYear)
    @assert day(maturityDay) == 20 "Maturity day for CDS should always be on the 20th"
    return collect(tradeDate+Day(1):Day(1):maturityDay)

end

