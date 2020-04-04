"""
`startDate` doesn't have to be a payment date, `lastPayment` has to be a payment date

`startDate` is the first calendar unadjusted date after trade
date. The first coupon date is at least after `startDate`

# example from ISDA 2012
A trade on Wed 19Mar09 pays its first coupon three months later, Mon22Jun09 (for 94 days)
"""
function get_payment_days_up_to(startDate::Date, lastPayment::Date)
    res = [get_next_payment_day(startDate)]
    while res[end] < lastPayment
        push!(res, get_next_payment_day(res[end]))
    end

    if res[end] > lastPayment
        res[end] = lastPayment
    end

    return res

end