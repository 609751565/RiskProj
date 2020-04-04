function collateWithConvention(originalData,TS;rateType="NotSpecified")
    fixDate = valueDate = maturity = Array{Date}(undef, nrow(originalData))
    fixDate .= TS.effectivehDate

    data = DataFrame(fixDate=fixDate,valueDate=valueDate,
    maturity=maturity)|>df->hcat(df,originalData);data.unit = Symbol.(data.unit)
    data = getValueAndMaturityDate(data,TS.calender)
    #data.ACT = (data.maturity .- data.valueDate).|>Dates.value

    insertcols!(
    data,
    findfirst(isequal(:maturity),names(data))+1,
    ACT = (data.maturity .- data.valueDate).|>Dates.value
    )

    type = []; couponFreq = []
    if rateType == "NotSpecified"
        type = Array{String}(repeat(["NotSpecified"], nrow(originalData)))
        couponFreq = Array{Union{String,Month,Year}}(repeat(["/"], nrow(originalData)))
        insertcols!(
        data,
        findfirst(isequal(:ACT),names(data))+1,
        dayCount = Array{Int64}(repeat([TS.dayCount],nrow(data)))
        )
    elseif lowercase(rateType) in ["depositrate","depositRate"]
        type = Array{String}(repeat(["DepositRate"], nrow(originalData)))
        couponFreq = Array{Union{String,Month,Year}}(repeat(["/"], nrow(originalData)))
        insertcols!(
        data,
        findfirst(isequal(:ACT),names(data))+1,
        dayCount = Array{Int64}(repeat([TS.dayCount],nrow(data)))
        )
    elseif lowercase(rateType) in ["swaprate","swap"]
        type = Array{String}(repeat(["SwapRate"], nrow(originalData)))
        couponFreq = Array{Union{String,Month,Year}}(repeat([eval(TS.freq)], nrow(originalData)))
        insertcols!(
        data,
        findfirst(isequal(:ACT),names(data))+1,
        dayCount = Array{Int64}(repeat([TS.dayCount],nrow(data)))
        )
    end


    insertcols!(
    data,
    findfirst(isequal(:rate),names(data))+1,
    type = type
    )

    insertcols!(
    data,
    findfirst(isequal(:type),names(data))+1,
    couponFreq = couponFreq
    )

    return data
end

function getValueAndMaturityDate(data,calender;rule="Libor",onlyMaturity=false)
    if rule == "Libor"
        BusinessDays.initcache(calender)
        if onlyMaturity == false
            for i in 1:nrow(data)
                #decide valueDate
                if data[i,:].unit == :S
                    data[i,:].valueDate = data[i,:].fixDate
                else
                    data[i,:].valueDate = advancebdays(calender, data[i,:].valueDate, TS.FixValueGap.value)
                end
            end
        end

        for i in 1:nrow(data)
            #decide maturity
            data[i,:].maturity = data[i,:].valueDate + data[i,:].quantity*eval(data[i,:].unit)
            if !isbday(calender,data[i,:].maturity)
                if tobday(calender, data[i,:].maturity)|>month != data[i,:].maturity|>month && data[i,:].unit != :S && data[i,:].unit != :W
                    data[i,:].maturity = tobday(calender, data[i,:].maturity; forward = false)
                else
                    data[i,:].maturity = tobday(calender, data[i,:].maturity)
                end
            end
        end
    end
    return data
end
