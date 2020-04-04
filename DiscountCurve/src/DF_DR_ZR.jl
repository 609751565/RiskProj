function DF_DR_ZR(ACT,dayCount,DRorDF;inputType = "discountRate")
    if lowercase(inputType) in ["discountrate","dr"]
        discountRate  = DRorDF
        datDountFrac = ACT ./ dayCount
        discountFactor = 1 ./ (1 .+ datDountFrac .* discountRate)
        timePeriod = ACT ./ 365
        zeroRate = (1 ./ discountFactor .^ (1 ./ timePeriod)) .-1
        return discountFactor,zeroRate
    end
    if lowercase(inputType) in ["discountfactor","df"]
        discountFactor = DRorDF
        datDountFrac = ACT ./ dayCount
        discountRate = ((1 ./ discountFactor) .-1) ./ (datDountFrac)
        timePeriod = ACT ./ 365
        zeroRate = (1 ./ discountFactor .^ (1 ./ timePeriod)) .-1
        return discountRate,zeroRate
    end

end
