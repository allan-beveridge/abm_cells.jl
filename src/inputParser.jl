#using Agents
using DataFrames
using CSV
#include("Cell.jl")

include("parser.jl")
include("Events.jl")
include("parseCell.jl")

function getDataType(varType)
    #println("getDataType:",varType)
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

#"""
#parses the main input file
#"""
"parses the main input file"
function parseInputFile(inputFile)
    if(!isfile(inputFile))
        abort__("Error, invalid file:" * inputFile)
    end
    nCycles = 200
    outputVariables = ""
    #cellEventsMap = Dict{String,Vector{String}}()
    #cellEventsMap = Dict{String,(String,Bool,Vector{Pair{String, String}})}()
    #cellEventsMap = Dict{String,Any}()
    cellEventsInstanceMap = Dict{String,Any}()
    cellEventDataList = []
    modelEventInstanceList = []
    output = nothing
    modelEventsMap = nothing
    modelEvents = nothing
    cellList = nothing
    steadyStateList = nothing
    #modelEventsList = nothing
    EventsMap = Dict{String,Main.AbstractEvent}()
    modelEventsMap = Dict{String,Main.AbstractEvent}()
    cellMap = Dict{String,Any}()
    u0_map = Dict{String,Vector{Pair{Symbol,Float64}}}()
    list = readTextFile(inputFile)
    list = removeBlankLines(list)
    list = removeCommentLines(list,"#")
    dataMap = Dict{String,Any}()
    for line in list
        text = strip(line)
        text = removeComment(strip(line),"#")
        cols = split(strip(text),":")
        if(length(cols) != 2)
            abort__(text,"Error, invalid input\n")
        end
        command = strip(cols[1])
        if(command == "Cell") # parse catalyst reaction data, Cell:A cell_a.dat
            cols = split(strip(cols[2]))
            if(length(cols) != 2)
                abort__(text,"Error, invalid input\n")
            end
            cellType = strip(cols[1])
            cellFile = strip(cols[2])
            if(!isfile(cellFile))
                abort__(text,"Error, invalid file:" * cellFile * "\n")
            end
            if( endswith(cellFile,".dat") )
                modelParams = parseCell(cellFile)
                #println(modelParams.rn_)
                #println(modelParams.u0_)
                #println(modelParams.p_)
                cellMap[cellType] = modelParams
            elseif(endswith(cellFile,".dict"))
                cols = split(strip(line))
                label = strip(cols[1])
                label = replace(label,"Cell:" => "")
                dictionaryFile = strip(cols[2])
                map = parseDictionary(dictionaryFile)
                dataMap[label] = map
            end
        elseif(command == "ModelEvents") # parses, ModelEvents:model_events.dat
            eventsFile = checkFilename__(text,cols[2])
            readEventsFile(modelEventsMap,eventsFile)
        elseif(command == "CellEvents") # parses, CellEvents:cell_events.dat
            eventsFile = checkFilename__(text,cols[2])
            readEventsFile(EventsMap,eventsFile)
        elseif(command == "Events") 
            # parses Events:A updateGrowth{updateGrowth(growthLimit=0.01,fraction=0.55)}
            columns = split(cols[2])
            type = strip(columns[1])
            eventList = parseEventInstance(text,columns[2:length(columns)])
            if(type == "model")
                modelEventInstanceList = vcat(modelEventInstanceList,eventList)
            else
                if(haskey(cellEventsInstanceMap,type))
                    eventList = vcat(cellEventsInstanceMap[type],eventList)
                end
                cellEventsInstanceMap[type] = eventList
            end
        elseif(command == "Initialise")
            cellFile = strip(cols[2])
            if(!isfile(cellFile))
                abort__("Error, invalid file:" * cellFile * "\n")
            end
            cellList = readCells(cellFile)
        elseif(command == "Output")
            output = parseOutput(line)
            if(output[1] == nothing)
                abort__(line,"Error, invalid input:" * line * "\n\n")
            end
        #elseif(startswith(line,"Dictionary:"))
        #    cols = split(strip(line))
        #    label = strip(cols[1])
        #    dictionaryFile = strip(cols[2])
        #    map = parseDictionary(dictionaryFile)
        #    println(label,":",map)
        #    exit()
        elseif(command == "u0")
            columns = split(strip(cols[2]))
            cellType = columns[1]
            u0 = parse_u0__(line,columns[2:end])
            u0_map[cellType] = u0
        elseif(command == "nCycles")
            nCycles = parseValue__(Int64,strip(cols[2]))
            if(nCycles == nothing)
                abort__(line,"Error, expected integer:" * cols[2])
            end
        elseif(command == "Write")
            outputVariables *= strip(cols[2]) * ";"
        elseif(command == "ENV")
            key = cols[1]
            value = cols[2]
        else
            abort__(line,"parseInputFile() Error, invalid key word:" * command * "\n")
        end
    end
    if(output == nothing)
        abort__("Error, output has not been specified")
    end
    for (key,eventInstanceDataList) in cellEventsInstanceMap
        error = validateEventInstances__(eventInstanceDataList,EventsMap)
        if(error != nothing)
            abort__("\n" * error * "\n")
        end
        checkEventInstances__(eventInstanceDataList,EventsMap)
    end
    checkEventInstances__(modelEventInstanceList,modelEventsMap)


    dataMap["u0"] = u0_map
    dataMap["nCycles"] = nCycles
    dataMap["output"] = output
    dataMap["cellMap"] = cellMap
    dataMap["CellEventsMap"] = EventsMap
    dataMap["modelEventsMap"] = modelEventsMap
    #dataMap["modelEventsList"] = modelEventsList
    dataMap["cellList"] = cellList
    dataMap["outputMap"] = parseOutputVariables_(outputVariables)

    dataMap["modelEventsInstanceList"] = modelEventInstanceList
    dataMap["cellEventsInstanceMap"] = cellEventsInstanceMap
    return(dataMap)
end

"""
   function parseOutputVariables_(text)\n
text: contains a set of output variables.\n
e.g. Cell A c1 c2 c3; Model m1 m2 m3.\n
text is split into a list by ';'.\n
Each list is parsed, and the variables extracted\n
Cell A c1 c2 c3 -> [c1,c2,c2]\n
Model m1 m2 m3 -> [m1,m2,m3]\n
parsed results are returned in a dictionary
"""
function parseOutputVariables_(text)
    text = chop(strip(text))
    outputLists = split(text,";")
    outputMap = Dict{String,Any}()
    for output in outputLists
        cols = split(output)
        if(cols[1] == "Cell")
            outputMap[cols[2]] = []
        elseif(cols[1] == "Model")
            outputMap[cols[1]] = []
        end
    end

    for output in outputLists
        cols = split(output)
        if(cols[1] == "Model")
            list = outputMap["Model"] 
            outputMap["Model"] = vcat(list,cols[2:end])
        else
            list = outputMap[cols[2]] 
            outputMap[cols[2]] = vcat(list,cols[3:end])
        end
    end
    return(outputMap)
end

"""
function called by validateEventInstances__() when an error has occured.\n
The invalid Event Instance is converted to a string and printed out as part of the error.\n
"""
function convertEventInstanceDataToString__(eventTuple)
    s = eventTuple[1] * "{"
    s *= eventTuple[2] * "("
    for pair in eventTuple[4]
        s *= pair[1] * "=" * pair[2] * ","
    end
    s = chop(s) * ")}"
    return(s)
end

"""
   validateEventInstanceVariables__(event,variableList)\n
   variableList: contains all instance variables\n
   event: is the Event which corresponds to the instance\n
   This function checks each instance variable.\n
   An error is generated if an instance variable can not be converted to the type defined by the Event.

"""
function validateEventInstanceVariables__(event,variableList)
    eventData = getfield(event,:data_)
    error = nothing

    for pair in variableList
        if(!haskey(eventData,pair[1]))
            error = "Error, invalid variable:" * pair[1]
            return(error)
        end
        variableTuple = eventData[pair[1]]
        variableType = pair[2]
       value,error = parseValue(pair[2],variableTuple[2])
       if(error != nothing)
           return(error)
       end
    end
    return(nothing)
end

"""
    function validateEventInstances__(eventInstanceDataList,eventsMap)\n
    eventInstanceDataList: contains a list of Event instances\n
    eventsMap:dictionary containing predefined Events\n
    This function validates Event Instances.\n
    It checks each instance matches an Event in eventsMap.\n
    It also checks each Instance variable.\n
"""
function validateEventInstances__(eventInstanceDataList,eventsMap)
    error = nothing
    for data in eventInstanceDataList
        eventLabel = data[1]
        eventType = data[2]
        variableData = data[4]
        if(!haskey(eventsMap,eventType))
            eventData = convertEventInstanceDataToString__(data)
            error = eventData * "\nError, invalid event instance:" * eventLabel
            return(error)
        end
        event = eventsMap[eventType]
        error = validateEventInstanceVariables__(event,data[4])
        if(error != nothing)
            eventData = convertEventInstanceDataToString__(data)
            return(eventData * "\n" * error)
        end
    end
    return(error)
end

"""
   function checkEventInstances__(eventInstanceDataList,eventMap)\n
   eventInstanceDataList:list of Event Instances\n
   eventMap:dictionary of predefined Events\n
   each Event Instance is checked to ensure it matches an Event in eventMap\n
"""
function checkEventInstances__(eventInstanceDataList,eventMap)
    for data in eventInstanceDataList
        eventLabel = data[1]
        eventType = data[2]
        if(!haskey(eventMap,eventType))
            abort__("Error, invalid event instance :" * eventLabel * "\n")
        end
    end
    return(nothing)
end

# check file exists
function checkFilename__(inputLine,filename)
    filename = strip(filename)
    cols = split(filename)
    if(length(cols) != 1)
       abort__(inputLine,"Error, invalid filename:" * filename * "\n")
    end
    if(!isfile(filename))
       abort__(inputLine,"Error, invalid file:" * filename * "\n")
    end
    return(filename)
end

function parse_u0__(line,columns)
    nCols = length(columns)
    scalingFactor = 1.0
    csvFile = columns[1]
    if(nCols < 3)
        checkFilename__(line,csvFile)
        if(nCols == 2)
            try
                scalingFactor = Base.parse(Float64,columns[2])
            catch e # UndefVarError
                error = "Invalid float:" * columns[2] * "\n" * sprint(showerror,e)
                abort__(error * "\n")
            end
        end
    else
       abort__(line,"Error, invalid input-1:" * columns[2] * "\n")
    end
    pairList = readSteadyState(csvFile,scalingFactor)
    return(pairList)
end

"""
   function readEventsFile(eventsMap,eventsFile)\n
   parses predefined events file (e.g. cellEvents.dat, modelEvents.dat).\n
   parameters: an Events file and a dictionary for appending parsed Events.\n
   parsed Events are added to the dictionary {String,Main.AbstractEvent}\n
   This function also calls parseEvents(), which calls Events.parseEvent_().\n
"""
function readEventsFile(eventsMap::Dict{String,Main.AbstractEvent},eventsFile)
    println("reading events file:",eventsFile)
    if(!isfile(eventsFile))
        abort__("Error, invalid file:" * eventsFile * "\n")
    end
    list = readTextFile(eventsFile)
    list = removeBlankLines(list)
    list = removeCommentLines(list,"#")
    error = parseEvents(eventsMap,list)
    if(error != nothing)
        message = "Error reading:" * eventsFile * "\n" * error * "\n"
        abort__(message)
    end
    return(nothing)
end

"""
    function parseEvents(eventMap,list)\n
    called by readEventsFile()\n
    This function calls Events.parseEvents() to parse each Event\n
"""
function parseEvents(eventMap::Dict{String,Main.AbstractEvent},list)
    #println("==parseEvents")
    nLines = length(list)
    index = 0
    while index < nLines
        index += 1
        line = strip(list[index])
        if(startswith(line,"Events"))
            index2 =  findText("end",list,index)
            if(index2 != nothing)
                #extract text between lines beginning with 'Events' and 'end'
                error = Events.parseEvents(eventMap,list[index:index2])
                return(error)
            else
                error = "parseEvents() error, invalid input:" * line * "\n"
                return(error)
            end
            break
        end
    end
    return(nothing)
end

"""
   function readCells(cellFile)\n
   called by parseInputFile()\n
   parses a file containing a list of (initial) cells.\n
   Format: 'Cell A 1 (x-coord,y-coord)'.\n
   <Cell> is a key word which must be followed by a <cell label> and then \n
   a cell id <unique integer>.
   Calls parseCells()
"""
function readCells(cellFile)
    println("reading cell file:",cellFile)
    list = readTextFile(cellFile)
    list = removeBlankLines(list)
    list = removeCommentLines(list,"#")
    return(list)
end

"""
    function parseCells(textList)\n
    called by parseCells() to parse a list of cells\n
    calles parseCellData()
"""
function parseCells(textList)
    cellList = Vector{Any}()
    for line in textList
        data =  parseCellData(line) # Cell A 1 (0.0,0.0)
        push!(cellList,data)
    end
    return(cellList)
end

"""
    function parseCellData(text)
    text: 'Cell A 1 (0.0,0.0)'
    parses text
    returns tuple(cellType,cell_id,(x,y)) 
    called by parseCells()
"""
function parseCellData(line)
    text = strip(line)
    cols = split(strip(text))
    posn1,posn2 =  findTaggedText(text,"(",")")
    coordinates = text[posn1+1:posn2-1]
    text = text[1:posn1-1]
    cols = split(text)
    if(cols[1] != "Cell")
        abort__(line,"Error, invalid input:" * cols[1] * "\n\n")
    end
    cellType = cols[2]
    index = cols[3]
    cell_id, error =  parseValue(cols[3],"Int64")
    if(error != nothing)
        abort__(line,"Error: invalid input, expected integer:" * cols[3] * "\n\n")
    end
    cols = split(coordinates,",")
    if(length(cols) != 2)
        abort__(line,"Error: invalid input, expected 2 coords:" * coordinates * "\n\n")
    end
    x = cols[1]
    x, error =  parseValue(strip(cols[1]),"Float64")
    if(error != nothing)
        abort__(line,"Error: invalid coordinate:" * cols[1] * "\n\n")
    end
    y = cols[2]
    y, error =  parseValue(strip(cols[2]),"Float64")
    if(error != nothing)
        abort__(line,"Error: invalid coordinate:" * cols[2] * "\n\n")
    end
    return( (cellType,cell_id, (x,y)) )
end

"""
    function parseEventInstance(inputLine,columnList)\n
    called by parseInputFile()\n
    Used to parse instances of model and cell events\n
    e.g Events:A updateGrowth{updateGrowth(growthLimit=0.01,fraction=0.55)}\n
    The instance definitions\n
         e.g. 'updateGrowth{updateGrowth(growthLimit=0.01,fraction=0.55)}'\n
    are converted to a list of tuples\n
         (instance-name,event-name,global,[parsed-variables])\n
    Calls parseEventInstance__() to parse each instance.\n
"""
function parseEventInstance(inputLine,columnList)
    instanceList = Vector{}()
    for i in 1:length(columnList)
        instanceData = parseEventInstance__(inputLine,columnList[i])
        push!(instanceList,instanceData)
    end
    return(instanceList)
end

"""
    function parseEventInstance__(inputLine,text)\n
    called by parseEventInstance()\n
    text: contains instance data,\n
    e.g. updateGrowthA{updateGrowth(growthLimit=0.01,fraction=0.55)}\n
    returns a tuple (eventLabel,eventName,global_,variableList)\n
    e.g. (updateGrowthA,updateGrowth,global,[list of variables])\n
    calls parseEventInstanceData__()\n
"""
function parseEventInstance__(inputLine,text)
    cols = split(text,"{")
    if(length(cols) == 1)
        abort__(inputLine,"Error-1, invalid input:" * text * "\nmissing bracket:{\n\n")
    elseif(length(cols) > 2)
        abort__(inputLine,"Error-2, invalid input:" * text * "\ntoo many brackets:{\n\n")
    end
    eventLabel = strip(cols[1])
    eventData = strip(cols[2])
    if( !endswith(eventData,"}") )
        abort__(inputLine,"Error-3, invalid input:" * text * "\nmissing bracket:}\n\n")
    end
    cols = split(eventData,"}")
    if(length(cols) != 2)
        abort__(inputLine,"Error-4, invalid input:" * text * "\n")
    end
    eventName,global_,variableList = parseEventInstanceData__(inputLine,strip(cols[1]))
    return(eventLabel,eventName,global_,variableList)
end

"""
    function parseEventInstanceData__(inputLine,text)\n
    text: string\n
    Format: <event-name>(<var-name-1>=<value1> , <var-name-2>=<value2>)\n
    e.g. updateGrowth(growthLimit=0.01,fraction=0.55)\n
    returns tuple(eventName,global_,[parsed-variable-list])
"""
function parseEventInstanceData__(inputLine,data)
    text = strip(data)
    variableList = Vector{Pair{String,String}}()
    global_ = false
    if(endswith(text,")") )
        text = text[1:length(text)-1]
        cols = split(text,"(")
        if(length(cols) != 2)
            abort__(inputLine,"Error-5, invalid input:" * text * "\n")
        end
        eventName = strip(cols[1])
        columns = split(strip(cols[2]),",")
        for col in columns
            cols = split(col,"=")
            if(length(cols) > 2)
                abort__(inputLine,"Error-6, invalid input:" * col * "\n")
            elseif(length(cols) == 2)
                pair = Pair(strip(cols[1]),strip(cols[2]))
                push!(variableList,pair)
            elseif(strip(cols[1]) == "global")
                global_ = true
            end
        end
    else
        eventName = text
    end
    return(eventName,global_,variableList)
end

function parseValue__(dataType,text)
    try
        value = Base.parse(dataType,text)
        return(value)
    catch e # ArgumentError
        write(Base.stderr,sprint(showerror,e) * "\n")
        return(nothing)
    end
end

function parseOutput(text)
    text = replace(text,"Output:" => "")
    cols = split(text)
    if(length(cols) != 2)
        return(nothing,nothing)
    end
    output = (strip(cols[1]),strip(cols[2]))
    return(output)
end

"""
    function getModelEvents(abm_data::Dict)\n
    called by initialiseModel()\n
    retrieves all predefined model events from abm_data\n
    retrieves all model event instances from abm_data\n
    generates a list of required model Events by combining the list of model\n
    instances with the predefined model events\n
    returns the required model Events in an OrderedDict
"""
function getModelEvents(abm_data)
    modelEventsMap = abm_data["modelEventsMap"] # ALL defined model events
    modelEventsInstanceList = abm_data["modelEventsInstanceList"] # model event instances
    eventList = Vector{Any}()
    eventsMap = OrderedDict{String,Main.AbstractEvent}()
    currentEvent = nothing
    for data in modelEventsInstanceList
        #println("data:",data)
        eventLabel = data[1]
        eventName = data[2]
        global_ = data[3]
        variableList = data[4]
        if(!haskey(modelEventsMap,eventName))
            abort__("Error, invalid event:" * eventName)
        end
        if(haskey(eventsMap,eventName))
            currentEvent = eventsMap[eventName]
        else
            currentEvent = modelEventsMap[eventName]
        end
        if(global_)
            event = currentEvent
        else
            event = deepcopy(currentEvent)
        end
        resetEventVariables(event,variableList)
        eventsMap[eventLabel] = event
    end
    return(eventsMap)
end

function readSteadyState(csvFile, scalingFactor=1.00)
    df = DataFrame(CSV.File(csvFile))
    labelList = df[:,:label]
    valueList = df[:,:value]
    nValues = length(valueList)
    pairList = Vector{Pair{Symbol,Float64}}()
    for i in 1:nValues
        pair = Pair(Symbol(labelList[i]),scalingFactor*valueList[i])
        push!(pairList,pair)
    end
    return(pairList)
end

"""
    function getCellEvents(abm_data,cellType)\n
    retrieves the defined cell Events Dict from abm_data.\n
    retrieves the cell Events Instance Dict from abm_data.\n
    Then, retrieves the cell Events Instance list for the specified cellType\n
    calls generateEvents__() to generate the required list of cell Events\n
    This function is called by initialiseCells()
"""
function getCellEvents(abm_data,cellType)
    cell_events_map = abm_data["CellEventsMap"]
    if(cell_events_map == nothing)
        write(Base.stderr,"Error, getCellevents()\n")
        write(Base.stderr,"no events defined\n\n")
        exit()
    end
    cell_events_map_copy = deepcopy(cell_events_map)

    cellEventsInstanceMap = abm_data["cellEventsInstanceMap"]
    cellEventsInstanceList = cellEventsInstanceMap[cellType]
    eventsMap = generateEvents__(cellEventsInstanceList,cell_events_map_copy)
    eventList = collect(values(eventsMap))
    return(eventList)
end

"""
    generateEvents__(eventInstanceList, eventsMap)\n
    generates a list of required Events by combining the eventInstanceList\n
    with a defined Events Dict\n
"""
function generateEvents__(eventInstanceList, eventsMap)
    #println("generateEvents__:",eventInstanceList)
    generatedEventsMap = OrderedDict{String,Main.AbstractEvent}()

    currentEvent = nothing
    for data in eventInstanceList
        eventLabel = data[1]
        eventName = data[2]
        global_ = data[3]
        variableList = data[4]
        #println(eventName, " ", global_, " ", variableList)
        #println("G:",global_)
        if(!haskey(eventsMap,eventName))
            abort__("Error, invalid event:" * eventName)
        end
        if(haskey(generatedEventsMap,eventName))
            currentEvent = generatedEventsMap[eventName]
        else
            currentEvent = eventsMap[eventName]
        end
        if(global_)
            event = currentEvent
        else
            event = deepcopy(currentEvent)
        end
        resetEventVariables(event,variableList)
        generatedEventsMap[eventLabel] = event
        Events.setNewResetValues(event)
    end
    return(generatedEventsMap)
end

"""
    function resetEventVariables(event,variableList)
    variableList is used to reset the event data dictionary
    called by generateEvents__()
"""
function resetEventVariables(event,variableList)
    eventData = getfield(event,:data_)
    name = getfield(event,:name_)
    for pair in variableList
        value = nothing
        if (haskey(eventData,pair.first))
            currentValue, varType = eventData[pair.first]
            dataType = getDataType(varType)
            if(dataType == String)
                value = pair.second
            else
                value = Base.parse(dataType,pair.second)
            end
            eventData[pair.first] = (value,dataType)
        else
            println("ERROR")
            abort__("Error, invalid variable:" * pair.first)
        end
    end
    return(nothing)
end


