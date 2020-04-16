module DiscountCurve
using Dates
using BusinessDays
using DataFrames
using DataFramesMeta
using CSV
using NLsolve
using Plots
using Parameters
using Dierckx

const S = Day(1)
const W = Week(1)
const M = Month(1)
const Y = Year(1)
const Quartely = Month(3)
const SemiAnnually = Month(6)
const Annual = Year(1)

mutable struct TermStructure
    dayCount::Int64
    calender::Symbol
    FixValueGap::Day
    effectivehDate::Date
    freq::Symbol
    dataDiscount::DataFrame
    dataSwap::DataFrame
    allData::DataFrame
    termStructure::DataFrame
    TSdiscount::DataFrame
    TSall::DataFrame
    TSdaily::DataFrame
    TermStructure() = new()
end

include("./src/collateRateFromData.jl")
include("./src/DF_DR_ZR.jl")
include("./src/collateWithConvention.jl")
include("./src/calculateTS.jl")
include("./src/bootstrap.jl")
include("./src/convertToDaily.jl")

export TSdef

function TSdef(testDate, tdLibor, tdSwap, freq, interpolationMethod)
    #read config
    dayCount = 360
    calender = :UKSettlement
    #freq = :SemiAnnually
    FixValueGap = Day(0)
    #effectivehDate = Date(2020,01,10)
    effectivehDate = testDate
    #liborData =  CSV.read("./sampleRateLibor.csv")|>DataFrame
    liborData = tdLibor
    #swapData = CSV.read("./sampleRateSwap.csv")|>DataFrame
    swapData = tdSwap
    #read config
    global TS = TermStructure()
    ###
    TS.dayCount = dayCount
    TS.effectivehDate = effectivehDate
    TS.calender = calender
    TS.freq = freq
    TS.FixValueGap = FixValueGap
    ###
    TS.dataDiscount = collateWithConvention(liborData, TS; rateType = "DepositRate")
    TS.dataSwap = collateWithConvention(swapData, TS; rateType = "SwapRate")
    TS.allData = vcat(TS.dataDiscount,TS.dataSwap)
    ###
    TS.TSdiscount = calculateTS(TS,"TSdiscount")
    TS.termStructure = calculateTS(TS,"termStructure")
    TS.TSall = calculateTS(TS,"TSall")
    TS.TSdaily = convertToDaily(TS; method = interpolationMethod)
    return TS
end


end # module
