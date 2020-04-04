function collateRateFromData(termStructure,sourceData,selectedRate)
    data = deepcopy(sourceData)
    data.DF,data.ZR =  DF_DR_ZR(data.ACT,data.dayCount,data.rate,;inputType = "discountRate")
    data = data[:,[:quantity,:unit,selectedRate...]]
    for i in 1:nrow(data)
        if data[i,:].quantity ==1 && data[i,:].unit == :S
            data[i,:].quantity = 0
            data[i,:].unit = :M
        end
        if  data[i,:].unit == :Y
            data[i,:].quantity = Month(data[i,:].quantity * eval(data[i,:].unit)).value
            data[i,:].unit = :M
        end
    end
    data = @where(data, string.(:unit) .== "M")[:,Not(:unit)]
    termStructure = join(termStructure, data, on=:quantity, kind=:left)
    return termStructure
end
