# 1. E_discount: Expectation value of the protection, before considering recovery rate
function E_discount(discountCurve::DataFrame, pdCurves::DataFrame, T::Date; Δt = 1/360)
    R = size(discountCurve, 1)
    t = discountCurve.Date[1] - Day(1) # trade date
    daysToAccrualEnd = Dates.value(T - t) # t'_k - t

    # Reshape the array to enable calculation for all companies at the same time
    ϕ_table = reshape(pdCurves.ϕ, (R, :))[1:daysToAccrualEnd, :];
    f_table = reshape(pdCurves.f, (R, :))[1:daysToAccrualEnd, :];
    h_table = reshape(pdCurves.h, (R, :))[1:daysToAccrualEnd, :];

    # bottleneck
    _P = interpolate_P(1, daysToAccrualEnd, discountCurve.InstAnnualRate[1:daysToAccrualEnd],
    f_table, fix=:q, interpolate = true)
    res= sum(exp.(-(discountCurve.LocalAvgRate[1:daysToAccrualEnd] .+ ϕ_table) .*
    (collect(1:daysToAccrualEnd) ./ 360)) .*
    (f_table + h_table .* _P) * Δt,
    dims = 1) |> vec

    return res
end
#=
day-t (notion ommited) discounted forward probability of the reference entity
of the CDS being terminated, including successions, over the days `t + s, ..., t + q`
=#
function P(s::Int, q::Int, f_table::Array{Float64, 2}, r_plus_f::Array{Float64, 2};
    Δt = 1/360)

    cumSumΔt = cumsum(r_plus_f[s:q, :], dims =1) * Δt;
    res = vec(sum(
    (exp.(-cumSumΔt ) .* f_table[s:q, :] * Δt), dims = 1
    ));

    return res
end

#=
generate an array of values for P, with either `s` or `q`
fixed. With an interval of 45 days, we calculate P(s, q) and
interpolate values in between
=#
function interpolate_P(s::Int, q::Int, r::Array{Float64, 1}, f_table::Array{Float64, 2};
    Δt = 1/360, tmp_zero = false, fix=:s, interval=45, interpolate = true)

    itp = pyimport("scipy.interpolate")

    if tmp_zero
        r_plus_f = f_table
    else
        r_plus_f = (r .+ f_table);
    end


    res = Array{Float64, 2}(undef, size(f_table))
    rows = collect(s:interval:q)
    if rows[end] != q
        push!(rows, q)
    end

    # we need at least 4 points for Cspline
    if q-s+1 <= 4
        rows = collect(s:q)
    elseif length(rows) < 4
        rows = sort([s, q, round(Int, s+(q-s)/3), round(Int, q-(q-s)/3)])
    end
    if !interpolate
        rows = collect(s:q)
    end


    if fix == :s
        map(q_i -> res[q_i, :] = P(s, q_i, f_table, r_plus_f; Δt = Δt), rows)
    elseif fix == :q
        map(s_i -> res[s_i, :] = P(s_i, q, f_table, r_plus_f; Δt = Δt), rows)
    else
        error("Either fix s (front) or q (end)")
    end

    if interpolate && length(rows) < q-s+1
        f = itp.interp1d(rows, transpose(res[rows, :]), kind="cubic")
        res[setdiff(s:q, rows), :] = vcat(transpose(f.(setdiff(s:q, rows)))...)
    end
    return res

end

# 2. Accrual_discount_E: value of premium paied, subject to exprectation of default
function Accrual_discount_E(discountCurve::DataFrame, pdCurves::DataFrame, T::Date)
    f_table = reshape(pdCurves.f, (size(discountCurve, 1), :));
    t = discountCurve.Date[1] - Day(1)
    df = get_t_k(discountCurve, T)
    # accrual period is inclusive on two ends,
    # here the formula may look different from techinical report
    # the daycount is ACT360
    df.Accrual = map(df.i) do i
        A = i == 0 ? missing :
        yearfrac(
        max(df.payment[df.i .== i-1][1], t + Day(1)),
        df.accrualEnd[df.i .== i][1] + Day(1), Actual360)
        return A
    end

    dropmissing!(df, disallowmissing = true)
    rename!(df, :payment => :Date)
    fulldf = join(df, discountCurve, on = :Date, kind = :left); rename!(fulldf, :Date => :payment)


    E_table = map(fulldf.i) do i
        q = Dates.value(fulldf[fulldf.i .== i, :accrualEnd][1] - t)
        res =  Array(transpose(
        1 .- P(1, q, f_table[1:q, :], f_table[1:q, :])))
        return res
    end |> x->vcat(x...)

    fulldf.discount = exp.(-fulldf.LocalAvgRate .* Dates.value.(fulldf.payment .- t)/360)
    res_table = fulldf.Accrual .* fulldf.discount .* E_table

    res = vec(sum(res_table, dims = 1))


    return res
end

#3. Expectation value of premium paied, before default
function E_Accrual_discount(discountCurve, pdCurves, T; Δt = 1/360)
    t = discountCurve.Date[1] - Day(1)
    df = get_t_k(discountCurve, T)
    f_table = reshape(pdCurves.f, (size(discountCurve, 1), :));


    res = map(df[df.i .>= 1, :i]) do i
        s_tmp = Dates.value(max(df[df.i .== i-1, :payment][1], t + Day(1))-t)
        q_tmp = Dates.value(df[df.i .== i, :accrualEnd][1] - t)
        P_tmp = interpolate_P(s_tmp, q_tmp,
        discountCurve.InstAnnualRate[1:q_tmp], f_table[1:q_tmp, :];
        fix =:q, interpolate = true)
        qmin = max(df[df.i .== i-1, :payment][1], t + Day(1))
        qmax = df[df.i .== i, :accrualEnd][1]
        accrualStart = max(df[df.i .== i-1, :payment][1], t + Day(1))
        numRows = Dates.value(qmax-qmin+Day(1))

        AccTerm = map(d-> yearfrac(accrualStart, d+Day(1), Actual360),
        collect(qmin:Day(1):qmax))
        ExpTerm = exp.(
        -(discountCurve[qmin .<= discountCurve.Date .<= qmax, :LocalAvgRate] .+
        reshape(
        pdCurves[Dates.value(qmin-t) .<= pdCurves.u .<=
        Dates.value(qmax-t), :ϕ], numRows, :)) .*
        Dates.value.(collect(qmin:Day(1):qmax) .- t) ./ 360.0
        )
        localres = AccTerm .* ExpTerm .* (
        reshape(
        pdCurves[Dates.value(qmin-t) .<= pdCurves.u .<=
        Dates.value(qmax-t), :f], numRows, :) .+
        reshape(
        pdCurves[Dates.value(qmin-t) .<= pdCurves.u .<=
        Dates.value(qmax-t), :h], numRows, :) .*
        P_tmp[Dates.value.(collect(qmin:Day(1):qmax) .- t), :]) * Δt
        return vec(sum(localres, dims = 1))


    end |> x->hcat(x...) |>
    x->sum(x, dims = 2);

    return res

end


#get the series of payments days, together with the first day
function get_t_k(discountCurve, T)
    tradeDate = discountCurve.Date[1]- Day(1)
    @assert day(T) == 20 "T = $T should be a maturity date"
    paymentDates = FinancialDays.get_payment_days_up_to(tradeDate, T)
    push!(paymentDates, FinancialDays.get_prev_payment_day(tradeDate)); sort!(paymentDates);
    df = DataFrame(payment = paymentDates)
    df.i = 0:length(df.payment)-1
    df.accrualEnd = df.payment .- Day(1)
    df.accrualEnd[end] = T

    return df
end
