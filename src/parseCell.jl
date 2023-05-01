using Catalyst

#include("parser.jl")
#include("Events.jl")
include("CellFunctions.jl")

struct cell_params
    nCycles_::Int64
    nCells_::Int64
    tspan_
    deltat_::Float64
    p_
    u0_
    steadyStateList_
    rn_
    nutrients_
    eventList_
    variables_::Dict{String,Any}
    # envList_ #::Vector{String}
end

function convertString_(line,str,vtype)
    try
        value = parse(vtype,str)
        return(value)
    catch
        message = "Error, invalid value:" * str * " , expecting:" * string(vtype)
        abort__(line,message)
    end
end


function parseParameters(text)
    pairList = Vector{Pair{Symbol,Float64}}()
    cols = split(text,"\t")
    if(length(cols) < 2)
        return(nothing)
    end
    for col in cols[2:length(cols)]
        col = strip(col)
        columns = split(col,"=")
        if(length(columns) != 2)
            abort__(text,"\nInvalid input:" * text * "\n\n")
        end
        symbol = Symbol(strip(columns[1]))
        try
            value = parse(Float64,strip(columns[2]))
            push!(pairList,Pair(symbol,value))
        catch e # UndefVarError
            abort__(text,"\nInvalid variable:" * col * "\n\n")
        end
    end
    return(pairList)
end

function parseResources(line)
    text = replace(line,"resources:" => "")
    text = strip(text)
    index1 = findfirst("{",text)
    if(index1 == nothing)
        write(Base.stderr,"\nInvalid input:" * line * "\n\n")
        return(nothing)
    end
    index2 = findfirst("}",text)
    if(index2 == nothing)
        write(Base.stderr,"\nInvalid input:" * line * "\n\n")
        return(nothing)
    end
    text = SubString(text,index1[1]+1,index2[1]-1)
    text = strip(text)
    resourceList = split(text,";")
    map = Dict{String,Any}()
    for text in resourceList
        columns = split(text,"->")
        if(length(columns) != 2)
            write(Base.stderr,"\nInvalid input:" * line * "\n\n")
            return(nothing)
        end
        cols = split(columns[1],"=")
        if(length(cols) != 2)
            write(Base.stderr,"\nInvalid input:" * line * "\n\n")
            return(nothing)
        end
        variable = cols[1]
        value = Base.parse(Float64,cols[2])
        map[variable] = (variable,value,columns[2],line)
    end
    return(map)
end

function parseEnv(line)
    text = strip(line)
    #println("parseEnv:",text)
    m = match(r"ENV\[(.+)\]\s=\s(.+)",text)
    #println("m:",m)
    if(m == nothing)
        return(false)
    end
    if(length(m) != 2)
        return(false)
    end
    return(true)
end

function parseCell(inputFile)
    list = readTextFile(inputFile)
    list = removeBlankLines(list)
    list = removeCommentLines(list,"#")
    index = 0
    nLines = length(list)
    catalystFile = nothing
    reactionList = nothing
    nCells = nothing
    nSteps = nothing
    rn = nothing
    p = nothing
    u0 = nothing
    steadyStateList = nothing
    tspan = nothing
    dt = nothing
    nutrientMap = nothing
    eventList = Vector{CellEventData}()
    envList = Vector{String}()
    while index < nLines
        index += 1
        line = list[index]
        text = strip(line)
        if(startswith(text,"catalyst:"))
            catalystFile = replace(text,"catalyst:" => "",count=1)
            if(!isfile(catalystFile))
                abort__(line,"\nInvalid catalyst file:" * catalystFile * "\n\n")
            end
        elseif(startswith(text,"p\t"))
            p = parseParameters(text)
        elseif(startswith(text,"u0\t"))
            u0 = parseParameters(text)
        elseif(startswith(text,"steadystate\t"))
            steadyStateList = parseSteadyState_(text)
        elseif(startswith(text,"nCells"))
            text = replace(text,"nCells" => "")
            text = replace(text,"=" => "")
            nCells = convertString_(line,strip(text),Int32)
        elseif(startswith(text,"nSteps"))
            text = replace(text,"nSteps" => "")
            text = replace(text,"=" => "")
            nSteps = convertString_(line,strip(text),Int32)
        elseif(startswith(text,"timespan"))
            tspan = parseTimeSpan_(line,text)
        elseif(startswith(text,"dt"))
            text = replace(text,"dt" => "")
            text = replace(text,"=" => "")
            dt = convertString_(line,strip(text),Float64)
        elseif(startswith(text,"resources:"))
            resourceMap = parseResources(text)
            if(resourceMap == nothing)
                exit(0)
            end
        elseif(startswith(text,"cell_event:"))
            event = parseCellEvent(text)
            push!(eventList,event)
        elseif(startswith(text,"nutrients:"))
            nutrientMap = parseResources(text)
            if(nutrientMap == nothing)
                exit(0)
            end
        elseif(startswith(text,"ENV["))
            #if(parseEnv(text))
            #    push!(envList,strip(text))
            #end
        else
            message = "\nerror parsing, " * inputFile * ":" * text * "\n\n"
            abort__(message)
        end
    end
    if(catalystFile == nothing)
        message = "\nError parsing, " * inputFile * ": catalyst file missing \n\n"
        abort__(message)
    end
    rn = readCatalystFile(catalystFile)
    #writeSerializedData(rn,"catalyst.jls")
    variables = Dict{String,Any}()
    params =  cell_params(nSteps,nCells,tspan,dt,p,u0,steadyStateList,rn,nutrientMap,eventList,variables)
    return(params)
end

function parseTimeSpan_(line,text)
    text = replace(text,"timespan" => "")
    text = replace(text,"=" => "")
    cols = split(text,",")
    t1 = convertString_(line,strip(cols[1]),Int32)
    t2 = convertString_(line,strip(cols[2]),Int32)
    return(t1,t2)
end

function readCatalystFile(catalystFile)
    if(catalystFile == nothing)
        message = "\nError parsing, " * catalystFile * ": catalyst file missing \n\n"
        abort__(message)
    end
    rn = nothing
    if(endswith(catalystFile,".jls"))
        rn = readSerializedData(catalystFile)
    else
        reactionList = readTextFile(catalystFile)
        rn = generateReactionSystem(reactionList)
    end
    #println("RN:",rn)
    return(rn)
end

function parseSteadyState_(line)
    cols = split(line,"\t")
    steadyStateFile = strip(cols[2])
    scalingFactor = 1.0
    if(length(cols) == 3)
        try
            scalingFactor = Base.parse(Float64,cols[3])
        catch e # UndefVarError
            error = "\nInvalid input:" * line
            abort__(error * "\n")
        end
    end
    if(!isfile(steadyStateFile))
        abort__(line,"\nInvalid file:" * steadyStateFile * "\n\n")
    end
    df = DataFrame(CSV.File(steadyStateFile))
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

function generateReactionSystem(reactionList)
    if(reactionList == nothing)
        return(nothing)
    end
    code = join(reactionList,"\n")
    #println("generateReactionSystem:",code)
    ex = Meta.parse(code)
    eval(ex)
    return(rn_lamda)
end

function xxx_test_event(inputFile)
end

function testParseCell(inputFile)
    parseCell(inputFile)
end

#test_event("event.dat")

#modelParams = parseCell("cell_1.dat")
