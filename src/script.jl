
#import .Equation

module Script

include("script_struct.jl")
    using Agents
    include("Equation.jl")
    include("code.jl")
    #include("Events.jl")

function abort__(line,message)
    write(Base.stderr,"\n" * line * "\n")
    write(Base.stderr,message)
    write(Base.stderr,"\n")
    exit()
end

function abort__(message)
    write(Base.stderr,"\n")
    write(Base.stderr,message)
    write(Base.stderr,"\n")
    exit()
end

    function xxx_validateCommands(commandList)
        for command in commandList
            columns = split(strip(command))
            if(columns[1] == "evaluate")
                if(length(columns) != 2)
                    abort__(command,"Error, invalid command:" * command * "\n\n")
                end
                cols = split(columns[2],"=")
                if(length(cols) != 2)
                    abort__("Error, invalid equation:" * columns[2] * "\n\n")
                end
            elseif(columns[1] == "decrement")
                if(length(columns) != 2)
                    abort__(command,"Error, invalid command:" * command * "\n\n")
                end
                cols = split(strip(columns[2]),",")
                if(length(cols) != 2)
                    abort__("Error, invalid input:" * command * "\n\n")
                end
            elseif(columns[1] == "increment")
                if(length(columns) != 2)
                    abort__(command,"Error, invalid command:" * command * "\n\n")
                end
                cols = split(strip(columns[2]),",")
                if(length(cols) != 2)
                    abort__("Error, invalid input:" * command * "\n\n")
                end
            else
                println("Error, invalid command:" * command * "\n\n")
                ##abort__(command,"Error, invalid command:" * command * "\n\n")
            end
        end
        return
    end

    function executeModelCommands(model,cell,event)
        executeModelScript_(model,cell,event)
    end

    function executeCellCommands(model,cell,event)
        executeCellScript_(model,cell,event)
        return
    end

    function updateGlobalVariables__(varName,value,model,cell)
        if(haskey(model.variables,varName))
            var, var_type = model.variables[varName]
            model.variables[varName] = (value,var_type)
        end
        if(cell == nothing)
            return()
        end
        #println("cv:",cell.variables_)
        if(haskey(cell.variables_,varName))
            var, var_type = cell.variables_[varName]
            cell.variables_[varName] = (value,var_type)
        end
    end

    function updateVariable__(variableName,value,varMap,symbolChar="\$")
        varMap[variableName] = value
        varName = symbolChar * variableName
        if(haskey(varMap,varName))
            return(variableName)
        end
        return(nothing)
    end

    function updateCellVariables__(cell,updateMap)
        cellVariables = getproperty(cell,:variables_)
        for (key,value) in updateMap
            if(haskey(cellVariables,key))
                cellVariables[key] = value
            end
        end
        return
    end

    function calculate__(eqn,varMap)
        cols = split(eqn)
        result = strip(cols[1])
        if(cols[2] == "=")
            var1 = varMap[cols[3]]
            operator = cols[4]
            var2 = varMap[cols[5]]
            code = string(var1) * " " * operator * " " * string(var2)
            ex = Meta.parse(code)
            value = eval(ex)
            return(result,value)
        end
    end

    function assign__(eqn,map)
        cols = split(eqn,"=")
        result = strip(cols[1])
        if(length(cols) == 2)
            var2 = strip(cols[2])
            value = map[var2]
            return(result,value)
        end
        return(nothing)
    end

    function evaluate__(text,eventData,varMap)
        cols = split(strip(text),"=")
        varName, eqn = split(strip(text),"=")
        equation = eventData[eqn]
        value = Equations.evaluateEquation(equation,varMap)
        varMap[varName] = value
        return(varName,value)
    end

    function decrement__(variables,eventData,varMap)
        var1, var2 = split(strip(variables),",")
        currentValue = Events.getEventVariable(var1,eventData)
        dec_value = varMap[var2]
        currentValue -= dec_value
        Events.setEventVariable(var1,currentValue,eventData)
        return(var1,currentValue)
    end

    function increment__(variables,eventData,varMap)
        var1, var2 = split(strip(variables),",")
        currentValue = Events.getEventVariable(var1,eventData)
        dec_value = varMap[var2]
        currentValue += dec_value
        Events.setEventVariable(var1,currentValue,eventData)
        return(var1,currentValue)
    end

function getAllEventVariables(model,cell,event,symbolChar="\$")
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

    function calculate(equation)
    end

# NEW

    function executeAllCellCalculations_(model,scriptVarMap,event,command)
        #eventData = getfield(event,:data_)
        #modelVarMap = eventData[":model"]
        #println("model:",modelVarMap)
        command = strip(command)
        varName = nothing
        totalValue = 0
        for cell in allagents(model)
            #cellVarMap = eventData[":cell"]
            #println("cell:",cellVarMap)
            cellVarMap = getAllEventVariables(model,cell,event)
            eqn = Code.generateEquation(command,cellVarMap)
            varName, value = Code.calculate(eqn,cellVarMap)
            totalValue += value
            var_name = updateVariable__(varName,value,cellVarMap)
            if(var_name != nothing)
                updateGlobalVariables__(var_name,value,model,cell)
            end
        end
        var_name = updateVariable__(varName,totalValue,scriptVarMap)
        if(var_name != nothing)
            updateGlobalVariables__(var_name,totalValue,model,cell)
        end
        return


        for cell in allagents(model)
            cellVarMap = getAllEventVariables(model,cell,event)
            eqn = Code.generateEquation(strip(command),cellVarMap)
            varName, value = Code.calculate(eqn,cellVarMap)
            totalValue += value
            var_name = updateVariable__(varName,value,cellVarMap)
            if(var_name != nothing)
                updateGlobalVariables__(var_name,value,model,cell)
            end
        end
        var_name = updateVariable__(varName,totalValue,modelVarMap)
        if(var_name != nothing)
            updateGlobalVariables__(var_name,value,model,cell)
        end
    end

    function executeModelScript_(model,cell,event)
        name = getfield(event,:name_)
        eventData = getfield(event,:data_)
        script = eventData["script"]
        updateScriptVariables_(model,cell,eventData,script.variableMap_)
count = 1
        scriptVarMap = script.variableMap_
        for command in script.commandList_
            command = strip(command)
            cols = split(command)
#            println(count, " C:",command)

            if(startswith(command,"{") && endswith(command,"}"))
                command = strip(command[2:length(command)-1])
                executeAllCellCalculations_(model,scriptVarMap,event,command)
            else
                eqn = Code.generateEquation(command,scriptVarMap)
                resVar, value = Code.calculate(eqn,scriptVarMap)
                var_name = updateVariable__(resVar,value,scriptVarMap)
                if(var_name != nothing)
                    #cell_ = script._cell_
                    #model_ = script._model_
                    model_ = model
                    cell_ = cell
                    updateGlobalVariables__(var_name,value,model_,cell_)
                end
            end
count += 1
        end
    end

    function executeCellScript_(model,cell,event)
        name = getfield(event,:name_)
        #println("executeCellScript:",name)
        eventData = getfield(event,:data_)
        script = eventData["script"]
        varMap = script.variableMap_
        updateScriptVariables_(model,cell,eventData,varMap)
        for command in script.commandList_
            cols = split(strip(command))
            if(cols[1] == "evaluate")
                varName, value = evaluate__(cols[2],eventData,varMap)
                var_name = updateVariable__(varName,value,varMap)
                if(var_name != nothing)
                    #cell_ = script._cell_
                    #model_ = script._model_
                    model_ = model
                    cell_ = cell
                    updateGlobalVariables__(var_name,value,model_,cell_)
                end
            else
                eqn = Code.generateEquation(strip(command),varMap)
                resVar, value = Code.calculate(eqn,varMap)
                var_name = updateVariable__(resVar,value,varMap)
                if(var_name != nothing)
                    #cell_ = script._cell_
                    #model_ = script._model_
                    model_ = model
                    cell_ = cell
                    updateGlobalVariables__(var_name,value,model_,cell_)
                end
            end
        end
    end

    function generateScript(model,cell,event)
        name = getfield(event,:name_)
        eventData = getfield(event,:data_)
        #println("data:",eventData)
        #println("cell:",cell)
        commandList = getfield(event,:commandList_)
        varMap = collectEventVariables_(model,cell,event)
        script = GenericScript(event,commandList,varMap)
        #script = GenericScript(model,cell,event,commandList,varMap) # circular ?
        eventData["script"] = script
        return(script)
    end

    function collectEventVariables_(model,cell,event,symbolChar="\$")
        name = getfield(event,:name_)
        #println("model.variables:",model.variables)
        map = Dict{}()
        eventData = getfield(event,:data_)
        cellPrefix = "cell."
        getPrefixedEventData(cellPrefix,eventData,map)

        if(cell != nothing)
            for s in cell.u0_
                map[symbolChar*string(s)] = getproperty(cell,s)
                map[string(s)] = getproperty(cell,s) ## temp fix
                #println("cell.u0_:",symbolChar*string(s), "=", getproperty(cell,s))
            end
            for (key,value) in cell.p_
                map[symbolChar * string(key)] = value
                #println("cell.p_:",symbolChar*string(key), "=", value)
            end
        end

        for (var,value) in model.variables
            map[symbolChar * var] = value
            map[var] = value
            #println("model.v_:",symbolChar*string(var), "=", value)
        end
        if(cell != nothing)
            for (var,value) in cell.variables_
                map[symbolChar * var] = value
                map[var] = value
                #println("model.c_:",symbolChar*string(var), "=", value)
            end
        end
        map[symbolChar *"dt"] = (model.dt,typeof(model.dt))
        map["dt"] = (model.dt,typeof(model.dt))
        map = removeTuples__(map)
        return(map)
    end

    function removeTuples__(varMap)
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

    function getPrefixedEventData(prefix,eventData,map)
        for (key,value) in eventData
            if(isa(value,Tuple))
                #println("ev:",key," ", value)
                if(startswith(key,prefix) && cell != nothing)
                    var = Symbol(replace(key,prefix => ""))
                    value = getproperty(cell,var)
                    #println("var:",var, " ", value)
                    map[key] = value
                else
                    map[key] = value[1]
                end
            end
        end
    end

    function updateScriptVariables_(model,cell,eventData,varMap,symbolChar="\$")
        cellVarMap = eventData[":cell"]
        modelVarMap = eventData[":model"]
        if(cell != nothing)
            for (key,data) in cellVarMap
                value,varType = cell.variables_[key]
                cellVarMap[key] = (value,varType)
                varMap[key] = value
                varMap[symbolChar*key] = value
                #val = getproperty(cell,key)
                #println("v:",val)
            end
        end
        if(length(modelVarMap) == 0)
            return()
        end
        for (key,data) in modelVarMap
            for (key,data) in modelVarMap
                value,varType = model.variables[key]
                modelVarMap[key] = (value,varType)
                varMap[key] = value
                varMap[symbolChar*key] = value
            end
        end
        return
    end

end # module

