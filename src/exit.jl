
function parseCondition(text,varMap,symbolChar="\$")
    cols = split(text)
    nCols = length(cols)

    if(nCols > 2)
        operator = strip(cols[2])
        if(!isOperator(operator))
        end
        res = strip(cols[1])
        if(tryparse(Float64, res) != nothing)
            code = string(value) * opertor
        else
            label = symbolChar * res
            value = varMap[label]
            code = string(value) * " " * operator
        end
        for i in 3:nCols
            if(tryparse(Float64, cols[i]) != nothing)
                code *=  " " * string(cols[i])
            else
                label = symbolChar * cols[i]
                value = varMap[label]
                code *=  " " * string(value)
            end
        end
        return(code)
    end

end

function isOperator(char)
    if(char == "=" || char == "<" || char == ">")
        return(true)
    end
    return(false)
end

function executeTest(condition,varMap)
    println("executeTest:",condition)
    println("varMap:",varMap)
    code = parseCondition(condition,varMap,"")
    println(code)
    ex = Meta.parse(code)
    res = eval(ex)
    return(res)
end



function getAllEventVariables__(model,cell,event,symbolChar="\$")
    name = getfield(event,:name_)
    map = Dict{}()
    eventData = getfield(event,:data_)
    cellPrefix = "cell."
    for (key,value) in eventData
        if(isa(value,Tuple))
            if(startswith(key,cellPrefix) && cell != nothing)
                var = Symbol(replace(key,cellPrefix => ""))
                value = getproperty(cell,var)
                map[key] = value
            else
                map[key] = value[1]
            end
        end
    end

    if(cell != nothing)
            for s in cell.u0_
            map[symbolChar*string(s)] = getproperty(cell,s)
            map[string(s)] = getproperty(cell,s) ## temp fix
        end
        for (key,value) in cell.p_
            map[symbolChar * string(key)] = value
        end
    end

    for (var,value) in model.variables
        map[symbolChar * var] = value
        map[var] = value
    end
    if(cell != nothing)
        for (var,value) in cell.variables_
            map[symbolChar * var] = value
            map[var] = value
        end
    end
    map[symbolChar *"dt"] = (model.dt,typeof(model.dt))
    map["dt"] = (model.dt,typeof(model.dt))
    map = generateVariableMap__(map)
    return(map)
end

    function generateVariableMap__(varMap)
        map = Dict{}()
        for (key,value) in varMap
            if(isa(value,Tuple))
                map[key] = value[1]
            else
                map[key] = value
            end
        end
        return(map)
    end

