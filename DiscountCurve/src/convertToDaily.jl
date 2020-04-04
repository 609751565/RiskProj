function convertToDaily(TS::TermStructure; method = "linear")
    @unpack TSall = TS
    if lowercase(method) == "linear"
        method = 1
    elseif lowercase(method) == "quadratic"
        method = 2
    elseif lowercase(method) == "cubic"
        method = 3
    end
    coupleData = [0 0; TSall.ACT TSall.ZR].|>Float64
    maxACT = maximum(TSall.ACT)
    spl = Spline1D(coupleData[:,1], coupleData[:,2];k=method)
    ZR = map(x->spl(x),collect(0:maxACT))
    valueDate = Array{Date}(repeat([TSall.valueDate[1]],maxACT+1))
    ACT = collect(0:maxACT)
    maturity = valueDate .+ Day.(ACT)
    TSdaily = DataFrame(
    valueDate = valueDate,
    maturity = maturity,
    ACT = ACT,
    ZR = ZR
    )
    TSdaily.DF = (1 .+ TSdaily.ZR) .^ ( - (TSdaily.ACT ./ 365) )
    return TSdaily
end
