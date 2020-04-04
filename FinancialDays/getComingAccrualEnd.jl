"""
Get the up coming accrual ends for CDS.
Except the last accrual end, all are one day before the payment date (business day adjusted following)
The last accrual end is the unadjusted maturity date (on Mar/Jun/Sep/Dec 20th)

`getComingAccrualEnd(effectiveDate::Date, NYears::Int)`
"""
function getComingAccrualEnd(effectiveDate::Date, NYears::Int)
    maturity_day = get_maturity_day(effectiveDate, NYears)
    res = [get_next_payment_day(effectiveDate)]
    while res[end] < maturity_day
        push!(res, get_next_payment_day(res[end]))
    end
    res = map(d->d >= maturity_day ? maturity_day : d - Day(1), res)
    return res

end

