function get_next_IMM_day(referenceDate::Date; inclusive::Bool = false)
    IMMDays = get_IMM_days(referenceDate)
    MarDay = minimum(IMMDays)
    if inclusive
        filter!(day -> day >= referenceDate, IMMDays)
    else
        filter!(day -> day > referenceDate, IMMDays)
    end
    if !isempty(IMMDays)
        return minimum(IMMDays)
    else
        res = MarDay + Year(1)
        return res
    end
end

