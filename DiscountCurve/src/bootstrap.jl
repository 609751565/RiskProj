function bootstrap(TS,termStructure)
    NoCyearly = Month(12).value / Month(eval(TS.freq)).value |> Int64

    while ismissing.(termStructure.DF)|>any
        theBlock = seperateToBlock(termStructure)
        coupon = theBlock.rate[end]/NoCyearly
        if .!ismissing.(theBlock.rate)|>all
            # No need for interpolation. Just do Bootstrap
            println("Simple Bootstrap is used for tenor: $(theBlock.quantity[end]) month")
            lastDF = (1 .- coupon .* sum(theBlock.DF[2:end-1])) ./ (1 + coupon)
            theBlock.DF[end] = lastDF
            _,theBlock.ZR[end] =  DF_DR_ZR(theBlock.ACT[end],TS["dayCount"],theBlock.DF[end];inputType = "discountFactor")
        elseif (unique(filter(!ismissing,theBlock.type)) .== "DepositRate")|>all
            #in this case, only interpolation on ZR, use constant forward rate
            missingIdx = findall(ismissing,theBlock.ZR)
            missingPeriodFR = (1+theBlock.ZR[missingIdx[end]+1])^(theBlock.quantity[missingIdx[end]+1]/12) /
                            (1+theBlock.ZR[missingIdx[1]-1])^(theBlock.quantity[missingIdx[1]-1]/12)
            a = 1/ missingPeriodFR ^ (1/(length(missingIdx)+1))
            for i in findall(ismissing,theBlock.DF)
                theBlock.DF[i] = theBlock.DF[i-1]*a
                _,theBlock.ZR[i] =  DF_DR_ZR(theBlock.ACT[i],theBlock.dayCount,theBlock.DF[i];inputType = "discountFactor")
            end
            for i in findall(ismissing,theBlock.rate)
                theBlock.rate[i] = (1 - theBlock.DF[i]) ./ sum(theBlock.DF[2:i])
            end
            for i in findall(ismissing,theBlock.type)
                theBlock.type[i] = "Interpolated by ConstFR"
            end
        else
            # Now use constant forward rate method to interpolate
            println("Constant Forward Rate method is used for tenor: $(@where(theBlock,:rate .|>ismissing).quantity) month")
            ## solving NL equation
            misIdx = findall(ismissing,theBlock.rate)
            global LHSpara = Array{Float64}(repeat([coupon],length(misIdx)+1));LHSpara[end] += 1
            global LHSpower = collect(1:length(misIdx)+1)
            global RHS = (1 .- coupon .* sum(theBlock.DF[2:misIdx[1]-1]))./theBlock.DF[misIdx[1]-1]
            function f!(F,x)
                global LHSpara, LHSpower, RHS
                F[1] = LHSpara' * (repeat([x[1]],length(misIdx)+1) .^ LHSpower) - RHS
            end
            a = nlsolve(f!,[1.0]).zero[1]
            FR = a^(-2) -1
            for i in findall(ismissing,theBlock.DF)
                theBlock.DF[i] = theBlock.DF[i-1]*a
                _,theBlock.ZR[i] =  DF_DR_ZR(theBlock.ACT[i],theBlock.dayCount,theBlock.DF[i];inputType = "discountFactor")
            end
            for i in findall(ismissing,theBlock.rate)
                theBlock.rate[i] = (1 - theBlock.DF[i]) ./ sum(theBlock.DF[2:i])
            end
            for i in findall(ismissing,theBlock.type)
                theBlock.type[i] = "Interpolated by ConstFR"
            end
        end
        termStructure[1:nrow(theBlock),:] = theBlock
    end
    return termStructure
end

function seperateToBlock(termStructure)
    blockIdx = []
    for i in 2:nrow(termStructure)
        if !ismissing(termStructure.rate[i]) && ismissing(termStructure.rate[i-1])
            blockIdx = push!(blockIdx,i)
        end
    end
    theBlock = termStructure[1:blockIdx[1],:]
    return theBlock
end
