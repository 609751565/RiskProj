"""
# Verify
`get_next_payment_day(Date(2009, 3, 18))` returns `2009-03-20`
`get_next_payment_day(Date(2009, 3, 19))` returns `2009-06-22`
"""
function get_next_payment_day(referenceDate::Date)
    paymentDays = get_payment_days(referenceDate)
    MarDay = minimum(paymentDays)
    filter!(day -> day > referenceDate+Day(1), paymentDays)
    if !isempty(paymentDays)
        return minimum(paymentDays)
    else
        unadjusted = MarDay + Year(1)
        return tobday("WeekendsOnly", Date(year(unadjusted), month(unadjusted), 20), forward = true)
    end
end

