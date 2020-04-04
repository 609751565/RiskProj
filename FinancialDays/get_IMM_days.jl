"""
get the unadjusted IMM dates
"""
function get_IMM_days(referenceDate::Date)
    MarIMMDay = Date(year(referenceDate), March, 20)
    JunIMMDay = Date(year(referenceDate), June, 20)
    SepIMMDay = Date(year(referenceDate), September, 20)
    DecIMMDay = Date(year(referenceDate), December, 20)
    IMM_days = [MarIMMDay, JunIMMDay, SepIMMDay, DecIMMDay]

    return IMM_days

end

