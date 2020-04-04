using DataFrames
using DataFramesMeta
using Dates
using CSV
using XLSX
using Plots
using MAT
using PyCall
using DayCounts
using Statistics
#using ProdExtractor; const pe = ProdExtractor
include("./FinancialDays/FinancialDays.jl")
include("./DiscountCurve/DiscountCurve.jl")
include("./threeEls.jl")
include("./getIntensity.jl")
import .FinancialDays
import .DiscountCurve

## 0. company info
ExchangeID = 15
CompanyID = 27153
companyInfo = DataFrame(ExchangeID = ExchangeID, U3_ID = [CompanyID])
RecoveryRate = 0.4
historicalRiskfactors = CSV.read("./inputDataFromCRI/historicalRiskfactors.csv") |>df->@where(df,:Date .>= Date(2005,01,01))

## 1.Setup
## 1.1 Prepare Libor-Swap data
libor =matread("./inputDataFromCRI/HistoricalLiborAndSwap_Processed.mat")["OriginalData"]["Libor"]["RecordDatenum_15Rates"][:,[1,2,3,5,6,7,10,16]]|>
DataFrame|>df->rename!(df,[:Date,:ON,:W1,:M1,:M2,:M3,:M6,:M12])|>unique
libor.Date = rata2datetime.(libor.Date) .|>Date
swap = matread("./inputDataFromCRI/HistoricalLiborAndSwap_Processed.mat")["OriginalData"]["Swap"]["RecordDatenum_NRates"][:,collect(1:7)]|>
DataFrame|>df->rename!(df,[:Date,:USSW1,:USSW2,:USSW3,:USSW4,:USSW5,:USSW6])|>unique|>replaceNaNinUSSW6
swap.Date = rata2datetime.(swap.Date) .|>Date

CDSrate = DataFrame()

for testDate in historicalRiskfactors.Date
    ## 1.2 Setup Date and Maturity
    #testDate = Date(2020,02,06)
    println("testing $testDate")
    allMaturity = FinancialDays.getComingAccrualEnd(testDate,5)

    ## 1.3 get today's curve
    ## 1.3.1 get today's raw rate
    tdLibor = DataFrame( quantity = [1,1,1,2,3,6,1],
    unit = ["S","W","M","M","M","M","Y"],
    rate = @where(libor,:Date.>=testDate)[1,:][collect(2:8)]|>Array|>a->a./100)|>df->@where(df,.!isnan.(:rate))
    tdSwap = DataFrame( quantity = [2,3,4,5,6],
    unit = ["Y","Y","Y","Y","Y"],
    rate = @where(swap,:Date.>=testDate)[1,:][collect(3:7)]|>Array|>a->a./100)|>df->@where(df,.!isnan.(:rate))

    ## 1.3.2 intreporlate to DiscountCurve (ConstForward Rate Method)
    discountCurve = DataFrame()
    TS = DiscountCurve.TSdef(testDate, tdLibor, tdSwap ,:SemiAnnually, "linear")
    discountCurveRaw = @where(TS.TSdaily, :maturity .> testDate, :maturity .<= allMaturity[end])
    discountCurve.Date = discountCurveRaw.maturity
    discountCurve.Accrual_Period = discountCurveRaw.ACT ./ 360
    #transform ZeroRate to continous compounding form
    discountCurve.LocalAvgRate = (360 ./ discountCurveRaw.ACT) .* log.(1 .+ discountCurveRaw.ZR .* discountCurveRaw.ACT ./ 360)
    #get instaneous forward rate
    discountCurve.InstAnnualRate = getInstAnnualRate(discountCurve)
    #plot(discountCurve.Date,discountCurve.LocalAvgRate)

    ## 1.4 get intensity
    # we use the parameter calibrated by CRI in 2019.12
    alphas = CSV.read("./inputDataFromCRI/alphas.csv")[1:nrow(discountCurve),:]
    betas = CSV.read("./inputDataFromCRI/betas.csv")[1:nrow(discountCurve),:]
    risk_factors = @where(historicalRiskfactors, :Date .>= testDate)[1,:]|>DataFrame
    CDSdate = risk_factors.Date
    pdCurves = getIntensity(CompanyID,risk_factors,alphas,betas)

    ## 2 main calculation
    # we split the finaal calculation formula into independent parts for calculation and finally combine them.
    T = allMaturity[end]
    as = (1-RecoveryRate) * E_discount(discountCurve, pdCurves, T) ./
    (Accrual_discount_E(discountCurve, pdCurves, T) +
    E_Accrual_discount(discountCurve, pdCurves, T)) * 1e4
    cdsRateAppend = DataFrame(Date = CDSdate, CDS = as[1])
    global CDSrate = isempty(CDSrate) ? cdsRateAppend : vcat(CDSrate, cdsRateAppend)
end

plot(CDSrate.Date,CDSrate.CDS)

function getInstAnnualRate(rateDF::DataFrame)
    # difference in products
    incremental_log_gross_rates = diff(vcat(0, (rateDF.Accrual_Period .* rateDF.LocalAvgRate)))
    incremental_time = diff(vcat(0, rateDF.Accrual_Period))
    instantaneous_rate_annualized = incremental_log_gross_rates ./ incremental_time
    return instantaneous_rate_annualized
end

function replaceNaNinUSSW6(df)
    idx = findall(isnan.(df[:USSW6]))
    for i in idx
        df[:USSW6][i] = mean([df[:USSW6][i-1],df[:USSW6][i+1]])
    end
    return df
end
