function getZRandDF(tenor::Union{Date,String,Int64}; TS=TS)
    @unpack TSdaily = TS
    output
    if typeof(tenor) == Date
        output = @where(TSdaily, :maturity .== tenor)
    elseif typeof(tenor) == String
        output = @where(TSdaily, :maturity .== Date(tenor,"yyyymmdd"))
    elseif typeof(tenor) == Int64
        output = @where(TSdaily, :ACT .== tenor)
    end
    return output.ZR[1], output.DF[1]
end
