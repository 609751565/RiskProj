function calculateTS(TS::TermStructure,type)
    if lowercase(type) in ["tsdiscount"]
        @unpack dataDiscount = TS
        TSdiscount = hcat(
        dataDiscount,
        DataFrame(hcat(DF_DR_ZR(dataDiscount.ACT,dataDiscount.dayCount,dataDiscount.rate;inputType = "discountRate")...),[:DF,:ZR])
        )
        return TSdiscount
    end

    if lowercase(type) in ["termstructure"]
        @unpack dataDiscount, allData = TS
        #start construncting TermStructure
        largestDate = allData[findmax(allData.maturity)[2],:]
        quantity = collect(0 : Month(eval(TS.freq)).value : Month(largestDate.quantity * eval(largestDate.unit)).value)
        valueDate = Array{Date}(repeat([allData.valueDate[1]],length(quantity)))
        maturity = Array{Date}(undef,length(quantity))

        termStructure = DataFrame(
        valueDate = valueDate,
        maturity = maturity,
        quantity = quantity,
        unit = Array{Symbol}(repeat([:M],length(quantity)))
        )|>ts->getValueAndMaturityDate(ts,TS.calender;onlyMaturity=true)

        insertcols!(
        termStructure,
        findfirst(isequal(:maturity),names(termStructure))+1,
        ACT = (termStructure.maturity .- termStructure.valueDate).|>Dates.value
        )

        termStructure = collateRateFromData(termStructure,allData,[:dayCount,:rate,:type])
        termStructure = collateRateFromData(termStructure,dataDiscount,[:DF,:ZR])

        ##fill in missing dayCount
        for i in 1:nrow(termStructure)
            if ismissing(termStructure.dayCount[i])
                termStructure.dayCount[i] = findnext(!ismissing,termStructure.dayCount,i)|>idx->termStructure.dayCount[idx]
            end
        end
        ##fill the first row
        if @where(termStructure,:quantity .== 0)|> isempty
            ###
        else
            termStructure[termStructure.quantity.==0,:rate] .= 0
            termStructure[termStructure.quantity.==0,:DF] .= 1
            termStructure[termStructure.quantity.==0,:ZR] .= 0
        end

        termStructure = bootstrap(TS,termStructure)
        return termStructure
    end

    if lowercase(type) in ["tsall","all"]
        TSdiscount = []; termStructure=[]
        try
            @unpack TSdiscount = TS
        catch
            TSdiscount = calculateTS(TS,"TSdiscount")
        end
        try
            @unpack termStructure = TS
        catch
            termStructure = calculateTS(TS,"termStructure")
        end

        TSall = vcat(@select(TSdiscount,names(termStructure)), @where(termStructure,:type .!= "DepositRate"))|>df->sort!(df,:ACT)
        return TSall
    end
end
