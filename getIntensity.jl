function getIntensity(CompanyID,risk_factors,alphas,betas)
    riskfactor_fields = [ :Stock_Index_Return, :Three_Month_Rate_After_Demean,
        :DTD_Level, :DTD_Trend,
        :Liquidity_Level_NonFinancial, :Liquidity_Trend_NonFinancial,
        :NI_Over_TA_Level, :NI_Over_TA_Trend, :Size_Level, :Size_Trend,
        :M_Over_B, :SIGMA,
        :Liquidity_Level_Financial, :Liquidity_Trend_Financial,
        :DTD_Median_Financial, :DTD_Median_NonFinancial,
        :dummy_for_NorthAmerica]
    risk_factors = risk_factors[:,riskfactor_fields]
    # three month rate is stored in percentage, here we divide it by 100
    risk_factors[!, :Three_Month_Rate_After_Demean] = risk_factors[:, :Three_Month_Rate_After_Demean]  ./ 100

    intensity = DataFrame(u = alphas.u)
    intensity[!, :U3_ID] .= CompanyID
    intensity[!, :f] = exp.(Matrix(alphas[:, 2:end]) *  vcat([1],vec(Matrix(risk_factors))) )
    intensity[!, :h] = exp.(Matrix(betas[:, 2:end]) *  vcat([1],vec(Matrix(risk_factors))) )
    intensity.ϕ = (cumsum(intensity.f) + cumsum(intensity.h) ) ./ intensity.u # ϕ_t(1, q) in report
    return intensity
end
