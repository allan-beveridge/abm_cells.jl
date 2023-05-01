include("demo_events.jl")
include("output.jl")
include("exit.jl")
include("script_struct.jl")

struct Output
    directory_::String
    filePrefix_::String
    header_::String
    cellList_
    modelList_
    sortBy_::String
    out_::(IOStream)
end

function modelDummy__(event)
end

function dummySave(model,cell,event)
end

function genericCellFunction(model,cell,event)
    name = getfield(event,:name_)
    #println("genericCellFunction:",name)
    Script.executeCellCommands(model,cell,event)
    return
end

function genericModelFunction(model,cell,event)
    #println("genericModelFunction")
    Script.executeModelCommands(model,cell,event)
    return
end

function exitModelFunction(model,cell,event)
    #println("exitModelFunction")
    eventData = getfield(event,:data_)
    condition = eventData[":exit"]
    varMap = getAllEventVariables__(model,cell,event)
    res = testCondition__(condition,varMap)
    #println("RES:",res)
end

function testCondition__(condition,varMap)
    #println("testCondition__:",condition)
    code =  parseCondition(condition,varMap)
    ex = Meta.parse(code)
    res = eval(ex)
    return(res)
end

function do_nothing(model,cell,event)
    return
end

function do_nothing(event)
    return
end

function do_nothing()
    return
end

function testEventCondition__(model,cell,event)
    eventData = getfield(event,:data_)
    test = eventData[":testCondition"]
    #println("testEventCondition__:",test)
    script = eventData["script"]
    Script.updateScriptVariables_(model,cell,eventData,script.variableMap_)


    res = testCondition__(test,script.variableMap_)
    return(res)
end

function always_true(model,cell,event)
    return(true)
end

function updateEvent__(model,cell,event)
    return(true)
end

function generateEventPairList(nameList,eventData)
    pairList = []
    for key in nameList
        pair = nothing
        if(haskey(eventData,key))
            value = Events.getEventVariable(key,eventData)
            pair = Pair(key,value)
        else
            pair = Pair(key,nothing)
        end
        push!(pairList,pair)
    end
    return(pairList)
end

function openOutput(event)
    eventData = getfield(event,:data_)

    cell = nothing
    model = nothing
    path = nothing
    outputPrefix = nothing
    sortBy = nothing
    cellList = nothing
    header = nothing
    keyList = ["cell","model","path","outputPrefix","sortBy","cellList","header"]
    pairList =  generateEventPairList(keyList,eventData)
    cell = nothing
    model = nothing
    path = nothing
    outputPrefix = nothing
    sortBy = nothing
    cellList = nothing
    header = nothing
    for pair in pairList
        if(pair.second != nothing)
            if(pair.first == "cell")
                cell = pair.second
            elseif(pair.first == "model")
                model = pair.second
            elseif(pair.first == "path")
                path = abspath(pair.second)
            elseif(pair.first == "outputPrefix")
                outputPrefix = pair.second
            elseif(pair.first == "sortBy")
                sortBy = pair.second
            elseif(pair.first == "cellList")
                cellList = split(pair.second,",")
            elseif(pair.first == "header")
                header = pair.second
            end
        end
    end

    if !isdir(path)
        path = mkdir(path)
    else
       println("Warning, directory already exists:" * path)
    end

    textFile = path * "/" * outputPrefix * ".csv"
    mode = "w"
    out = open(textFile,mode)
    output = Output(path,outputPrefix,header,cellList,model,sortBy,out)
    eventData["_output"] = (output,Output)

    _out, varType = eventData["_out"]
    Events.setEventVariable("_out",out,eventData)
    return
end

function openTextFile(event)
    eventData = getfield(event,:data_)
    textFile = Events.getEventVariable("textFile",eventData)
    mode = Events.getEventVariable("_mode",eventData)
    mode = "w"
    out = open(textFile,mode)
    if(haskey(eventData,"header"))
        header = Events.getEventVariable("header",eventData)
        write(out,header * "\n")
    end
    _out, varType = eventData["_out"]
    Events.setEventVariable("_out",out,eventData)
    return
end

function saveCellEvents(model)
    for cell in allagents(model)
        eventList = getfield(cell,:events_)
        for event in eventList
            event.save(model,cell,event)
        end
    end
end

function update_nutrients(model,cell,event)
    eventData = getfield(event,:data_)
    nutrients = eventData["nutrients"]
    #println("update_nutrients:",model.nutrients)
    for (key,data) in nutrients
        nutrient = data[1]
        value = data[2]
        symbol = Symbol(data[3])
        for cell in allagents(model)
            cellValue = getproperty(cell,symbol)
            value -= cellValue
        end
        nutrients[key] = (nutrient,value,symbol)
    end
    return
end

function countCells(model,cell,event)
    #println("countCells:",model.nSteps)
    cellLineage = getfield(cell,:lineage_)
    #println(cellLineage.status_)
    eventData = getfield(event,:data_)
    agent_id = getfield(cell,:id)
    label = getfield(cell,:label_)
    currentTimeStep, varType = eventData["currentTimeStep"]
    currentTimeStep = Events.getEventVariable("currentTimeStep",eventData)
    previousTimeStep, varType = eventData["previousTimeStep"]
    previousTimeStep = Events.getEventVariable("previousTimeStep",eventData)

    if(cellLineage.status_ == "divided")
        timeStepList, varType = eventData["timeStepList" * label]
        timeStepList = Events.getEventVariable("timeStepList" * label,eventData)
        cellCountList, varType = eventData["cellCountList" * label]
        cellCountList = Events.getEventVariable("cellCountList" * label,eventData)
        cellCount, varType = eventData["cellCount" * label]
        cellCount = Events.getEventVariable("cellCount" * label,eventData)
        cellCount += 1
        #println(model.nSteps," ==cell:",agent_id, "-", label, " " , cellCount)
        eventData["cellCount" * label] = (cellCount,varType)
        Events.setEventVariable("cellCount" * label,cellCount,eventData)
        if(model.nSteps == currentTimeStep)
            currentIndex = length(cellCountList)
            cellCountList[currentIndex] = cellCount
        else
            previousTimeStep = currentTimeStep
            currentTimeStep = model.nSteps
            push!(cellCountList,cellCount)
            push!(timeStepList,currentTimeStep)
        end
    end
    return
end

function saveCellCounts(model,cell,event)
    #println("saveCellCounts")
    eventData = getfield(event,:data_)
    agent_id = getfield(cell,:id)
    label = getfield(cell,:label_)
    timeStepList, varType = eventData["timeStepList" * label]
    timeStepList = Events.getEventVariable("timeStepList" * label,eventData)
    cellCountList, varType = eventData["cellCountList" * label]
    cellCountList = Events.getEventVariable("cellCountList" * label,eventData)
    df = DataFrame(timeStep=timeStepList,cellCount=cellCountList)
    csvFile = "cell_count_" * label * ".csv"
    CSV.write(csvFile,df)
    return
end

function writeData(model,cell,event,delimiter = "\t")
    #println("writeData")
    eventData = getfield(event,:data_)
    index = Events.getEventVariable("_index",eventData)
    index += 1
    Events.setEventVariable("_index",index,eventData)

    variables = Events.getEventVariable("cellList",eventData)
    list = split(variables,",")
    variableList = []
    for var in list
        push!(variableList,var)
    end

    textList = getCellOutput(index,model,variableList)
    out = Events.getEventVariable("_out",eventData)
    for text in textList
        write(out,text * "\n")
    end
    return()
end

function saveData(model,cell,event)
    delimiter = "\t"
    eventData = getfield(event,:data_)
    variables = Events.getEventVariable("variableList",eventData)
    list = split(variables,",")
    variableList = []
    for var in list
        push!(variableList,var)
    end
    index = Events.getEventVariable("_index",eventData)
    index += 1
    Events.setEventVariable("_index",index,eventData)
    textList = []
    for cell in allagents(model)
        #println("cell:",cell)
        #println("u0_:",cell.u0_)
        p_id = getproperty(cell,:id)
        cell_id = getproperty(cell,:id_)
        parameterMap = Events.getCellParameters(cell,"")
        #println(parameterMap)
        s = string(index) * delimiter * string(p_id)
        for var in variableList
            if (haskey(parameterMap,var))
                value = parameterMap[var]
                #println("v:",value," ", typeof(value))
                s *= delimiter * string(value)
            else
                println("Error:",var)
                println(parameterMap)
                exit()
            end
        end
        push!(textList,strip(s))
    end
    #println("T:",textList)
    #println("model:",model)
    out = Events.getEventVariable("_out",eventData)
    for text in textList
        write(out,text * "\n")
    end
    return()
end

function demoModelCellCount(model,cell,event)
    #println("demoModelCellCount:",model.nSteps)
    countA = 0
    countB = 0
    for cell in allagents(model)
        agent_id = getfield(cell,:id)
        label = getfield(cell,:label_)
        #println("cell:",agent_id, " ", label)
        if(label == "A")
            countA += 1
        elseif(label == "B")
            countB += 1
        end
    end
    eventData = getfield(event,:data_)
    cellCountList = Events.getEventVariable("cellCountA",eventData)
    timeStepList = Events.getEventVariable("timeStepA",eventData)
    index = length(cellCountList)
    nCells = cellCountList[index]
    if(countA > nCells)
        push!(cellCountList,countA)
        push!(timeStepList,model.nSteps)
    end
    #println("A:",cellCountList)
    #println("t:",timeStepList)

    cellCountList = Events.getEventVariable("cellCountB",eventData)
    timeStepList = Events.getEventVariable("timeStepB",eventData)
    index = length(cellCountList)
    nCells = cellCountList[index]
    if(countB > nCells)
        push!(cellCountList,countB)
        push!(timeStepList,model.nSteps)
    end
    #println("B:",cellCountList)
    #println("t:",timeStepList)
    return
end

function saveModelCellCount(event)
    #println("saveModelCellCount")
    data = getfield(event,:data_)
    #println(data["timeStepB"])
    #println(data["cellCountB"])
    timeStepList = Events.getEventVariable("timeStepA",data)
    cellCountList = Events.getEventVariable("cellCountA",data)
    df = DataFrame(timeStep=timeStepList,cellCount=cellCountList)
    CSV.write("demo_model_count_A.csv",df)
    timeStepList = Events.getEventVariable("timeStepB",data)
    cellCountList = Events.getEventVariable("cellCountB",data)
    df = DataFrame(timeStep=timeStepList,cellCount=cellCountList)
    CSV.write("demo_model_count_B.csv",df)
    return
end

function saveCellCount(event)
    #println("saveCellCount")
    data = getfield(event,:data_)
    cellCountFile = data["cellCountFile"]
    #println("cellCountFile:",cellCountFile)
    df = DataFrame(timeStep=data["timeStep"],cellCount=data["cellCount"])
    CSV.write(cellCountFile,df)
end

function updateCellCount(model,cell,event)
    nCells = length(model.agents)
    #println("updateCellCount:",nCells, " ", model.nSteps)
    data = getfield(event,:data_)
    cellCountList = data["cellCount"]
    timeStepList = data["timeStep"]
    index = length(cellCountList)
    lastCount = cellCountList[index]
    if(nCells > lastCount)
        push!(cellCountList,nCells)
        push!(timeStepList,model.nSteps)
    end
end

function timeToDivide(model,cell,event)
    #println("timeToDivide:",event.data_, " maxSteps:",event.data_["maxSteps"])
    eventData = getfield(event,:data_)
    #println("d:",eventData)
    nutrient, varType = eventData["nutrient"]
    nutrient = Events.getEventVariable("nutrient",eventData)
    nCells = length(model.agents)
    #max = 0.05 - nCells * 0.00005
    max = 0.05 - nCells * nutrient
    nSteps = getfield(cell,:nSteps_)
    probability = nSteps * rand(Uniform(0.0,max))
    if(probability > 1.0)
        #println("timeToDivide:",model.nSteps)
        return(true)
    end
    return(false)
end

function divide_cell(model,cell,event)
    agent_id = getfield(cell,:id)
    #println("DIVIDE CELL::",agent_id, " ", typeof(agent_id))
    nextAgent = model.lastCell + 1
    p_id = getproperty(cell,:id)
    cell_id = getproperty(cell,:id_)
    cellIndex = cell_id - agent_id
    model.lastCell += 2

    name = getfield(event,:name_)
    data = getfield(event,:data_)
    fraction, varType = data["fraction"]
    fraction = Events.getEventVariable("fraction",data)
    u1 = divideResources(cell,fraction)
    u2 = divideResources(cell,1.0-fraction)

    cellLineage = getfield(cell,:lineage_)
    cellLineage.status_ = "divided"
    cell1 = createNewCell(model,cell,nextAgent,u1,(0.0,0.0),cellIndex)
    cell2 = createNewCell(model,cell,nextAgent+1,u2,(0.0,0.0),cellIndex)
    kill_agent!(cell,model)
    return()
end

    function divideResources(cell,fraction)
        agent_id = getfield(cell,:id)

        nSymbols = length(cell.u0_)
        u = zeros(nSymbols)
        for i in 1:nSymbols
            u[i] = fraction * getproperty(cell,cell.u0_[i])
        end
        return(u)
    end

    function convertToPairedList_(cell,u0List)
        integrator = getfield(cell,:integrator_)
        u0_vec = Vector{Pair{Symbol, Float64}}()
        index = 1
        for field in cell.u0_
            push!(u0_vec,Pair(field,u0List[index]))
            index += 1
        end
        return(u0_vec)
    end

    function createNewCell(model,cell,agent_id,u0,pos,cellIndex)
        label = getfield(cell,:label_)
        cell_id = agent_id + cellIndex

        _rn =  getReactionNetwork(model,label)
        _p = cell.p_
        _u0 = convertToPairedList_(cell,u0)

        integrator = model.createIntegrator(_rn,u0,_p,model.tspan)
        d = getCellDictionary(agent_id,cell_id,pos,_u0,integrator)

        cellLineage = getfield(cell,:lineage_)
        ancestors = deepcopy(cellLineage.ancestors_)
        push!(ancestors,string(cell.id))
        created = cellLineage.timeSteps_
        lineage = Lineage(string(agent_id), created,cellLineage.deltaT_,"alive",1,ancestors)
        events = copyCellEvents(cell)

        newCell = add_agent!(pos,model,d,lineage,integrator,events,label,0)
        newCell.variables_ = deepcopy(cell.variables_)
        newCell.p_ = deepcopy(cell.p_)
        Events.resetEvents(newCell,events)

#printCell__(newCell)
        return(newCell)
    end

function printCellEventData(cell,eventName)
    cell_id = getfield(cell,:id)
    println(eventName, " cell:",cell_id)
    eventList = getfield(cell,:events_)
    for event in eventList
        name = getfield(event,:name_)
        println("NAME:",name)
        if(name == eventName)
            eventData = getfield(event,:data_)
            println("dd:",eventData)
        end
    end
end

function printCellEvents(cell)
    cell_id = getfield(cell,:id)
    println("cell events:",cell_id)
    eventList = getfield(cell,:events_)
    println("EVENTS:", length(eventList))
    for event in eventList
        #println("E:",event)
        eventData = getfield(event,:data_)
        println("D:",eventData)
    end
    return
end

"""
    function copyCellEvents(cell)
    makes a copy of a cell's Event list
    called by createNewCell()
"""
function copyCellEvents(cell)
    #println("copyEvents")
    cellEvents = getfield(cell,:events_)
    #println(cellEvents)
    eventList = Vector{Any}()
    label = getfield(cell,:label_)
    #println("Lbel:",label)
    for event in cellEvents
        _global = getfield(event,:global_)
        #println("g:",_global)
        if(_global)
            copy = event
        else
            copy = deepcopy(event)
        end
        push!(eventList,copy)
    end
    return(eventList)
end


"""
   Defintion of an AbstractEvent
   Events are used throughout to interface code with the Agents package
"""
abstract type AbstractEvent end

"""
   Defintion of an ExitEvent
"""
mutable struct ExitEvent <: AbstractEvent
    name_::String
    data_::Dict{String,Any}
    functions_::Dict{Symbol,Any}
    global_::Bool
    commandList_ # ::Vector{String}
    function ExitEvent(name,data,functions,glob,commandList=nothing)
        name_ = name
        data_ = data
        functions_ = functions
        global_ = glob
        commandList_ = commandList
        functions_[:initialise] = getfield(Main, Symbol("do_nothing"))
        new(name_,data_,functions_,global_,commandList_)
    end
end

Base.getproperty(x::ExitEvent, property::Symbol) = getfield(x, :functions_)[property]
Base.setproperty!(x::ExitEvent, property::Symbol, value) = getfield(x, :functions_)[property] = value
Base.propertynames(x::ExitEvent) = keys(getfield(ExitEvent, :functions_))

"""
   Defintion of an GenericEvent
"""
mutable struct GenericEvent <: AbstractEvent
    name_::String
    data_::Dict{String,Any}
    functions_::Dict{Symbol,Any}
    global_::Bool
    commandList_ # ::Vector{String}
    function GenericEvent(name,data,functions,glob,commandList=nothing)
        name_ = name
        functions_ = functions
        global_ = glob
        commandList_ = commandList
        resetData = Dict{String,Any}()
        _data = deepcopy(data)
        for (key,value) in data
            if(isa(value,Dict))
                resetData[key] = deepcopy(value)
            elseif(isa(value,Tuple))
                resetData[key] = deepcopy(value)
            end
        end
        new(name_,_data,functions_,global_,commandList_)
    end
end

Base.getproperty(x::GenericEvent, property::Symbol) = getfield(x, :functions_)[property]
Base.setproperty!(x::GenericEvent, property::Symbol, value) = getfield(x, :functions_)[property] = value
Base.propertynames(x::GenericEvent) = keys(getfield(GenericEvent, :functions_))

"""
   Defintion of an Event 
   Event is used for both Cell and Model Events
"""
mutable struct Event <: AbstractEvent
    name_::String
    data_::Dict{String,Any}
    functions_::Dict{Symbol,Any}
    global_::Bool
    commandList_ # ::Vector{String}
    #function Event(name,data,functions,glob)
    #    println("Event-4")
    #    exit()
    #end
    function Event(name,data,functions,glob,commandList=nothing)
        name_ = name
        functions_ = functions
        global_ = glob
        commandList_ = commandList
        resetData = Dict{String,Any}()
        _data = deepcopy(data)
        for (key,value) in data
            if(isa(value,Dict))
                resetData[key] = deepcopy(value)
            elseif(isa(value,Tuple))
                resetData[key] = deepcopy(value)
            end
        end
        new(name_,_data,functions_,global_,commandList_)
    end
end

#Event(name,data,functions,global_) = Event(name,data,functions,global_,nothing)

Base.getproperty(x::Event, property::Symbol) = getfield(x, :functions_)[property]
Base.setproperty!(x::Event, property::Symbol, value) = getfield(x, :functions_)[property] = value
Base.propertynames(x::Event) = keys(getfield(Event, :functions_))

module Events
    using OrderedCollections
    using Agents
    include("parser.jl")
    include("Equation.jl")
include("script.jl")
include("script_struct.jl")

    function getDataType__(varType)
        code = "dataType = " * strip(varType)
        try
            ex = Meta.parse(code)
            dataType = eval(ex)
            return(dataType)
        catch e # UndefVarError
            error = sprint(showerror,e)
            write(Base.stderr,error)
            return(nothing)
        end
    end

"""
    function setNewResetValues(event)
    event: Cell or Model Event
    called by generateEvents__()
"""
    function setNewResetValues(event)
        eventData = getfield(event,:data_)
        resetData = eventData["reset"]
        for (key,data) in resetData
            if(isa(data,Dict))
                resetData[key] = eventData[key]
            elseif(isa(data,Tuple))
                resetData[key] = eventData[key]
            end
            if(key == "reset")
                println("RESET???")
                exit()
            end
        end
        #for (key,value) in resetData
        #     println("reset ", key,"::",value)
        #end
        return
    end

"""
    function resetEvents(cell,eventList)\n
    resets a cells event list.\n
    This will normalls happen when a cell divides. The daughter cells\n
    inherit copies of the parent's events. Some of the new daughter events\n
    may require resetting.\n
    called by createNewCell()\n
"""
    function resetEvents(cell,eventList)
        for event in eventList
            name = getfield(event,:name_)
            eventData = getfield(event,:data_)
            resetData = eventData["reset"]
            resetValueMap = Dict{String,Any}()
            for(key,data) in resetData
                if(isa(data,Tuple))
                    value = data[1]
                    dataType = data[2]
                    resetValueMap[key] = value
                    setEventVariable(key,value,eventData)
                end
            end
            cellVarMap = eventData[":cell"]
            #modelVarMap = eventData[":model"]
            resetCellEventVariables__(cell,resetValueMap,cellVarMap) # NEED TO RE-CHECK demo 3
        end
    end

"""
    function resetCellEventVariables__()\n
    called by resetEvents() to reset cell Event variables\n
"""
    function resetCellEventVariables__(cell,resetValueMap,cellVarMap)
        #println("resetCellEventVariables")
        for (key,data) in cellVarMap
            resetData = resetValueMap[key]
            cellVarMap[key] = (resetData,data[2])
            cell.variables_[key] = (resetData,data[2])
        end
        return
    end

    function checkEventHeader__(text)
        cols = split(text)
        if(length(cols) > 1)
           abort__(text,"Error, invalid 'Event'")
        end
        return
    end

"""
    function parseEvents(eventMap::Dict{String,Main.AbstractEvent},textList)\n
    textList: list of predefined Cell/Model Events (e.g. defined in cellEvents.dat)\n
    This function splits the textList into individual Events which are then\n
    parsed by parseEvent_()\n
    parsedEvents are added to eventMap\n
"""
    function parseEvents(eventMap::Dict{String,Main.AbstractEvent},textList::Vector{String})
        nLines = length(textList)
        index = 0
        eventIndex = 0
        eventPrefix = nothing
        text = nothing
        while(index < nLines)
            index += 1
            line = textList[index]
            text = strip(line)
            if(startswith(text,"ModelEvent:"))
                eventIndex = index
                eventPrefix = "ModelEvent:"
                break
            elseif(startswith(text,"CellEvent:"))
                eventPrefix = "CellEvent:"
                eventIndex = index
                break
            elseif(startswith(text,"GenericEvent:"))
                eventPrefix = "GenericEvent:"
                eventIndex = index
                break
            elseif(startswith(text,"ExitEvent:"))
                eventPrefix = "ExitEvent:"
                eventIndex = index
                break
            end
        end
        if(eventIndex == 0)
            return("no events found")
        end
        checkEventHeader__(text)

        eventFlag = false
        while index < nLines
            index += 1
            line = textList[index]
            text = strip(line)
            if(startswith(text,"ModelEvent:") )
                eventFlag = true
            elseif(startswith(text,"CellEvent:") )
                eventFlag = true
            elseif(startswith(text,"GenericEvent:") )
                eventFlag = true
            elseif(startswith(text,"ExitEvent:") )
                eventFlag = true
            elseif(startswith(text,"end"))
                eventFlag = true
            end
            if(eventFlag)
                checkEventHeader__(text)
                event = parseEvent_(textList[eventIndex:index-1])
                name = getfield(event,:name_)
                eventMap[getfield(event,:name_)] = event
                eventIndex = index
                eventFlag = false
            end
        end
        return(nothing)
    end

"""
    function parseReset__(eventData,text)\n
    text: string\n
    Format: <var-name> = <value> , <var-name> = value\n
    e.g. growthProg = 0.0,growthIncrease = 0.0\n
    parses the 'reset' variables\n
    called by Event.parseEvent_()\n
"""
    function parseReset__(eventData,text)
        #println("parseReset__:",text)
        resetData = replace(strip(text),"reset:" => "")
        if(resetData == "none")
            eventData["reset"] = nothing
            return
        end
        defaultResetData = eventData["reset"]
        dataCols = split(resetData,",")
        resetMap = Dict{String,Any}()
        value = nothing
        for data in dataCols
            cols = split(data,"=")
            varName = strip(cols[1])
            if(length(cols) > 2)
                abort__(data,"Error, invalid 'reset' input:" * data * "\n")
            end
            if(!haskey(eventData,varName))
                abort__(data,"Error, invalid 'event' variable:" * varName * "\n")
            end
            val, var_type = eventData[varName]
            if(length(cols) == 1)
                value = val
            elseif(length(cols) == 2)
                dataType = getDataType__(var_type)
                try
                    value = Base.parse(dataType,strip(cols[2]))
                catch e # ArgumentError
                    abort__(data,"Error, invalid value:" * value * "\n")
                end
            end
            resetMap[varName] = value
        end
        defaultCellVarMap = defaultResetData[":cell"]
        defaultModelVarMap = defaultResetData[":model"]
        resetVarMap = Dict{String,Any}()
        resetCellMap = Dict{String,Any}()
        resetModelMap = Dict{String,Any}()
        for (key,data) in resetMap
            if(haskey(defaultCellVarMap,key))
                defaultData = defaultCellVarMap[key]
                resetVarMap[key] = (data,defaultData[2])
                resetCellMap[key] = (data,defaultData[2])
            elseif(haskey(defaultModelVarMap,key))
                defaultData = defaultModelVarMap[key]
                resetVarMap[key] = (data,defaultData[2])
                resetModelMap[key] = (data,defaultData[2])
            else
                defaultData = defaultResetData[key]
                resetVarMap[key] = (defaultData)
            end
        end
        resetVarMap[":cell"] = resetCellMap
        #resetVarMap[":model"] = resetModelMap
        eventData["reset"] = resetVarMap
        return
    end

"""
    function parseEventFunction__(prefix,text)\n
    parses, text, and extracts function name\n
    text format: <keyword>:<function name>\n
    e.g. execute:divideByGrowth\n
    prefix: is the type of function e.g. 'test','execute', or 'save'\n
    called by Events.parseEvent_()\n
"""
    function parseEventFunction__(prefix,text)
        functionName = replace(text,prefix => "")
        functionName = strip(functionName)
        try
            fnc = getfield(Main, Symbol(functionName))
            #println("fnc:",fnc)
            return(fnc)
        catch e # UndefVarError
            println("parseEventFunction__:",text)
            error = "Invalid function:" * functionName * "\n" * sprint(showerror,e)
            abort__(error * "\n")
        end
    end

"""
   function getEventType__(text)\n
   text: contains 'CellEvent:<event-name>'
   e.g. CellEvent:updateGrowth\n
   returns the Event name\n
   called by parseEvents()\n
"""
    function getEventType__(text)
        cols = split(strip(text),":")
        return(cols[1])
    end


"""
    function parseEvent_(textList)\n
    textList: data which defines the Event\n
    called by Events.parseEvents()\n
"""
    function parseEvent_(textList::Vector{String})
        #println(textList)
        eventType = getEventType__(textList[1])
        text = strip(textList[1])
        cols = split(strip(text),":")
        if(length(cols) != 2)
           println("Error:",textList[1])
           abort__(textList[1],"Error, invalid 'Event'")
        end
        commandList = []
        exitCondition = false
        testCondition = nothing
        label = strip(cols[2])
        testFunction = nothing
        executeFunction = nothing
        saveFunction = getfield(Main, Symbol("do_nothing"))
        initialiseFunction = getfield(Main, Symbol("do_nothing"))
        resetText = nothing
        global_ = false
        dataMap = Dict{String,Any}()
        modelVarMap = Dict{String,Any}()
        cellVarMap = Dict{String,Any}()
        nLines = length(textList)
        for i in 2:nLines
            line = textList[i]
            text = strip(line)
            if(startswith(text,"data:"))
                addEventVariable_(text,dataMap)
            elseif(startswith(text,"cell:"))
                addEventVariable_(text,cellVarMap)
            elseif(startswith(text,"model:"))
                addEventVariable_(text,modelVarMap)
            elseif(startswith(text,"condition:"))
                testCondition = parseTestCondition__(text)
                dataMap[":testCondition"] = testCondition
            elseif(startswith(text,"equation:"))
                eqnLabel,eqn = parseEquation_(text)
                dataMap[eqnLabel] = eqn
            elseif(startswith(text,"%:"))
                command = strip(replace(text,"%:" => ""))
                push!(commandList,command)
            elseif(startswith(text,"reset:"))
                resetText = text
            elseif(startswith(text,"test:"))
                testFunction = parseEventFunction__("test:",text)
            elseif(startswith(text,"execute:"))
                executeFunction = parseEventFunction__("execute:",text)
            elseif(startswith(text,"save:"))
                saveFunction = parseEventFunction__("save:",text)
            elseif(startswith(text,"exit:"))
                exitCondition = parseExitCondition__(text,eventType)
            elseif(startswith(text,"initialise:"))
                initialiseFunction = parseEventFunction__("initialise:",text)
            elseif(text == "copy")
                global_ = false
            elseif(text == "global")
                global_ = true
            else
                abort__(line,"Error, parsing Event::" * line)
            end
        end
        mergeEventVariables__(dataMap,cellVarMap,modelVarMap)
        resetData = initialiseResetData(dataMap)
        dataMap["reset"] = resetData
        if(resetText != nothing)
            parseReset__(dataMap,resetText)
        end
        if(length(commandList) == 0)
            commandList = nothing
        end
        if(testCondition != nothing)
            #println(testCondition)
            testFunction = getfield(Main, Symbol("testEventCondition__"))
        elseif(testFunction == nothing)
            testFunction = getfield(Main, Symbol("always_true"))
        end
        functions = Dict{Symbol,Any}()
        functions[:test] = testFunction
        functions[:execute] = executeFunction
        functions[:save] = saveFunction
        functions[:initialise] = initialiseFunction
        if(eventType == "ExitEvent")
            dataMap[":exit"] = exitCondition
            event = Main.ExitEvent(label,dataMap,functions,global_,commandList)
        elseif(eventType == "GenericEvent")
            event = Main.GenericEvent(label,dataMap,functions,global_,commandList)
        else
            event = Main.Event(label,dataMap,functions,global_,commandList)
        end
        return(event)
    end

    function parseTestCondition__(text)
        text = strip(replace(text,"condition:" => ""))
        return(text)
    end

    function parseExitCondition__(text,eventType)
        if(eventType != "ExitEvent")
            abort__(text,"Error, this option is only vallid for 'Exit' events")
        end
        cols = split(text,":")
        if(length(cols) != 2)
            abort__("Error, invalid input:", text)
        end
        return(strip(cols[2]))
    end

"""
    function initialiseResetData(data)\n
    data:Event data Dict\n
    The initial values of variables stored in an Event data Dict\n
    are used to generate another Dict containing default 'reset' values\n
    This is then returned\n
    called by Events.parseEvent_()\n
"""
    function initialiseResetData(data)
        resetData = Dict{String,Any}()
        for (key,value) in data
            if(isa(value,Tuple))
                resetData[key] = deepcopy(value)
            end
        end
        #data["reset"] = resetData
        cellVarMap = deepcopy(data[":cell"])
        resetData[":cell"] = cellVarMap
        modelVarMap = deepcopy(data[":model"])
        resetData[":model"] = modelVarMap
        #println("cvm:",cellVarMap)
        #println("mvm:",modelVarMap)
        return(resetData)
    end

"""
    function mergeEventVariables__(dataMap,cellVarMap,modelVarMap)\n
    adds cell and model variables to a data Dict\n
    called by Events.parseEvent_()\n
"""
    function mergeEventVariables__(dataMap,cellVarMap,modelVarMap)
        for (key,value) in cellVarMap
            dataMap[key] = value
        end
        for (key,value) in modelVarMap
            dataMap[key] = value
        end
        dataMap[":cell"] = cellVarMap
        dataMap[":model"] = modelVarMap
    end

"""
    function addEventVariable_(text,dataMap)\n
    text: string\n
    Format:  <keyword>(<type>) = <value>\n
    e.g. data:growthLimit(Float64) = 2.0\n
    keyword can be 'data:', 'cell:' or 'model:'\n
    parses text and adds a variable to a data Dict\n
    called by Events.parseEvent_()\n
"""
    function addEventVariable_(text,dataMap)
        cols = split(text,":")
        if(length(cols) != 2)
            abort__(text,"Error, invalid '" * cols[1] * "' variable")
        end
        var_cols = split(cols[2],";")
        for col in var_cols
            varData = parseVariable(col)
            if(varData == nothing)
                abort__(text,"Error, invalid 'Event' variable")
            end
            dataMap[varData[1]] = (varData[2],varData[3])
        end
    end

"""
    function parseEquation_(text)\n
    parses the equation defined by 'text'\n
    called by Events.parseEvent_()\n
"""
    function parseEquation_(text)
        text = replace(text, "equation:" => "")
        cols = split(strip(text),"=")
        if(length(cols) != 2)
            abort__("\nparseEquation_(), Error parsing equation:" * text * "\n")
        end
        label = strip(cols[1])
        equation = strip(cols[2])
        #eqn = Events.generateEquation(equation)
        eqn = Equations.generateEquation(equation)
        return(label,eqn)
    end

"""
    function getAgentVariables(label,eventList)\n
    label = cell|model\n
    finds the cell (or model) variables present in an Event list\n
    returns a Dict\n
"""
    function getAgentVariables(label,eventList)
        variableMap = Dict{String,Any}()
        for event in eventList
            eventData = getfield(event,:data_)
            if (haskey(eventData,label))
                varMap = eventData[label]
                for (key,val) in varMap
                    variableMap[key] = val
                end
            end
        end
        return(variableMap)
    end

#   ========================================

function initialiseAllEvents(model)
    #model.genVarMap_ = initialiseGenericEvents(model) # NEW
    for cell in allagents(model)
        eventList = getfield(cell,:events_)
        for event in eventList
            event.initialise(event)
            if(string(typeof(event)) == "GenericEvent")
                Script.generateScript(model,cell,event)
            end
        end
    end
    for event in model.events
        event.initialise(event)
        eventData = getfield(event,:data_)
        map = eventData[":model"]
        name = getfield(event,:name_)
        if(string(typeof(event)) == "GenericEvent")
            Script.generateScript(model,nothing,event)
        end
    end
end

function createCellMap(cell)
    cellMap = Dict{String,Any}()
    for s in cell.u0_
        value = getproperty(cell,s)
        cellMap[String(s)] = value
    end
    for (key,value) in cell.p_
        cellMap[String(key)] = value
    end
    return(cellMap)
end

function addSymbol__(map,symbolChar="\$")
    list = []
    for (key,data) in map
        push!(list,(symbolChar * key,data))
    end
    for tuple in list
        map[tuple[1]] = tuple[2]
    end
end

function mergeGenericVariables(cellVariableMap,cellEventVariables,symbolChar="\$")
    for (key,tuple) in cellEventVariables
        cellVariableMap[key] = tuple[1]
        #cellVariableMap[symbolChar * key] = tuple[1]
    end
end

function getGenericCellEvents(model)
    genericList = []
    map = OrderedDict{}()
    for cell in allagents(model)
        eventList = getfield(cell,:events_)
        for event in eventList
            if(string(typeof(event)) == "GenericEvent")
                map[event] = event
            end
        end
    end
    return(collect(keys(map)))
end

"""
   function getCellParameters(cell,symbolChar)\n
   copies u0 and p values from a cell into a Dict\n
   returns Dict\n
"""
function getCellParameters(cell,symbolChar="\$")
    map = Dict{}()
    for s in cell.u0_
        map[symbolChar*string(s)] = getproperty(cell,s)
    end
    for (key,value) in cell.p_
        map[symbolChar * string(key)] = value
    end
    return(map)
end

"""
   function getEventVariable(varName,eventData)\n
   returns the value of the variable (varName) stored in an Event data Dict\n
"""
function getEventVariable(varName,eventData)
    value, var_type = eventData[varName]
    return(value)
end

"""
   function setEventVariable(varName,value,eventData)\n
   sets the value of the variable (varName) stored in an Event data Dict\n
"""
function setEventVariable(varName,value,eventData)
    oldValue, var_type = eventData[varName]
    eventData[varName] = (value,var_type)
    return()
end

end # module Events

