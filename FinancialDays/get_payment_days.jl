function get_payment_days(referenceDate::Date)
    MarPayDay = tobday("WeekendsOnly", Date(year(referenceDate), March, 20), forward = true)
    JunPayDay = tobday("WeekendsOnly", Date(year(referenceDate), June, 20), forward = true)
    SepPayDay = tobday("WeekendsOnly", Date(year(referenceDate), September, 20), forward = true)
    DecPayDay = tobday("WeekendsOnly", Date(year(referenceDate), December, 20), forward = true)
    payment_days = [MarPayDay, JunPayDay, SepPayDay, DecPayDay]

    return payment_days

end

