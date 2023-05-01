
function getCellOutput(timeStep,model,variableList,delimiter="\t")
    textList = []
    for cell in allagents(model)
        p_id = getproperty(cell,:id)
        cell_id = getproperty(cell,:id_)
        parameterMap = Events.getCellParameters(cell,"")
        s = string(timeStep) * delimiter * string(p_id)
        for var in variableList
            if (haskey(parameterMap,var))
                value = parameterMap[var]
                s *= delimiter * string(value)
            else
                println("=====Error:",var,"::")
                println(parameterMap)
                exit()
            end
        end
        push!(textList,strip(s))
    end
    return(textList)
end
