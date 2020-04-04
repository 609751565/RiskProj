function get_prev_payment_day(referenceDate::Date)
    nextpayment = get_next_payment_day(referenceDate)


    paymentDays = get_payment_days(referenceDate)
    DecDay = maximum(paymentDays)
    filter!(day -> day < nextpayment, paymentDays)
    if !isempty(paymentDays)
        return maximum(paymentDays)
    else
        unadjusted = DecDay - Year(1)
        return tobday("WeekendsOnly", Date(year(unadjusted), month(unadjusted), 20), forward = true)
    end
end