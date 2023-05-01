using OrdinaryDiffEq
using Agents
using OrderedCollections

#include("demo_events.jl")
include("CommandParser.jl")
include("Events.jl")
include("inputParser.jl")
include("model.jl")
include("Cell.jl")
include("Equation.jl")
include("script.jl")
include("PlotCell.jl")

function createDirectory(directory)
    if !isdir(directory)
        path = mkdir(directory)
    else
       println("Warning, directory already exists:" * directory)
    end
    return
end

"""
    function generateModel(modelName,inputFile)\n
    inputFile: main data file\n
    modelName:string\n
    This function calls parseInputFile() and parses the main data file.\n
    parseInputFile returns a Dict (abm_data) with the parsed Data.\n
    This is used to generate a model which is then serialized and written\n
    to a .jls file\n
"""
function generateModel(modelName,inputFile)
    println("generating model:", modelName)
    println("reading:",inputFile)
    growthLimit  =  "GL"
    abm_data = parseInputFile(inputFile)
    outputDir, outputPrefix  = abm_data["output"]
    cellIndex = 0

    command = "export GKSwstype=\"100\""
    ex = Meta.parse(command)
    #eval(ex)
    #Random.seed!(6549)
    outputDir, outputPrefix = abm_data["output"]
    createDirectory(outputDir)
    outputDir = abspath(outputDir)
    println("O:",outputDir, " ", outputPrefix)
    model = initialiseModel(abm_data,cellIndex)

    modelFile = modelName * ".jls"
    writeSerializedData(model,modelFile)
    #model = readSerializedData(modelFile)
    println("finished:" * modelFile)
    exit()
    return
end

function checkInputFile(inputFile)
    if(inputFile == nothing)
        write(Base.stderr,"\nError, no input file specified\n")
        exit()
    end
    if(!isfile(inputFile))
        write(Base.stderr,"\nError, invalid input file:" * inputFile *"\n")
        exit()
    end
end

function runModel(modelName,inputFile,nCycles=100)
    println("runModel:", inputFile, " ", modelName)
    checkInputFile(inputFile)
    runModel_(modelName,inputFile,nCycles)
    exit()
end

function createModel(inputFile,modelName)
    checkInputFile(inputFile)
    generateModel(modelName,inputFile)
    exit()
end

function getOutputList(model,cellType)
    outputList = model.outputMap[cellType]
    list = []
    for label in outputList
        push!(list,Symbol(label))
    end
    return(list)
end

"""
    function runModel_(modelName,modelFile,nCycles)\n
    Main function for running Agents simulation\n
    modelFile: serialised model file (.jls)
"""
function runModel_(modelName,modelFile,nCycles)
    n=nCycles
    println("runModel_:",n)
    outputDir = "./" * modelName
    outputPrefix = modelName * "_"
    createDirectory(outputDir)
    outputDir = abspath(outputDir)
    println("O:",outputDir, " ", outputPrefix)
    model = readSerializedData(modelFile)


    Events.initialiseAllEvents(model)
    initialiseModelVariables(model)


    maxTime = model.tspan[2]
    nCycles = Int64(maxTime/model.dt)
    run_info = "dt=" * string(model.dt) * "_maxt=" * string(maxTime)
    aList = [:r,:e_t,:e_m,:q,:m_r,:m_t,:m_m,:m_q,:c_r,:c_t,:c_m,:c_q,:a,:s_i]
    aList = [:id_,:r,:e_t,:e_m,:q,:m_r,:m_t,:m_m,:m_q,:c_r,:c_t,:c_m,:c_q,:a,:s_i]
    aList = [:label__,:r,:e_t,:e_m,:q,:m_r,:m_t,:m_m,:m_q,:c_r,:c_t,:c_m,:c_q,:a,:s_i]
    aList = getOutputList(model,"A")

    println("nCycles:",n)
    #aList = []
    agentResults, modelResults = runModel!(model, update_cell!, update_model!,n,[],aList)
    #agentResults, modelResults = run!(model, update_cell!, update_model!, nCycles; mdata = [], adata = aList)
    #agentResults, modelResults = run!(model, update_cell!, update_model!, nCycles; mdata = [])
    #CSV.write("zzz_abm_cell.csv",agentResults)

    nDigits = 5
    roundColumns(agentResults,aList,nDigits)
    csvFile = outputDir * "/" * outputPrefix * "_general_abm_cell.csv"
    CSV.write(csvFile,agentResults)
    println(csvFile)

    #plotPrefix = "agent_model_dt=" * string(modelParams.deltat_) * "_maxt=" * string(maxTime)
    plotPrefix = outputPrefix * "_" * run_info
    println("prefix::",plotPrefix)
    agentPlot(agentResults,model.nAgents,outputDir,plotPrefix)

    println("runModel_ finished")
    return()
    saveCellEvents(model)
    eventList = model.events
    for event in eventList
        event.save(event)
    end
    return()
    end

function roundColumns(df,columnList,nDigits=3)
    for column in columnList
        name = Symbol(column)
        df[:,name] = round.(df[:,name];digits=nDigits)
    end
end

function parseCommandLine()

    ENV["GKSwstype"] = 100
    parameterDictionary = CommandParser.readParameters("options.dat")

    dict = CommandParser.parse(parameterDictionary,ARGS)
    #println(dict)
    inputFile = nothing
    outputDirectory = nothing
    modelName = nothing
    run = nothing
    cpus = 1
    demo = nothing
    if (haskey(dict,"-gm"))
       modelName = dict["-gm"]
       run = "generate-model"
    end
    if (haskey(dict,"-model"))
       modelName = dict["-model"]
       run = "run-model"
    end
    if (haskey(dict,"-demo"))
       demo = dict["-demo"]
       run = "demo"
    end
    if (haskey(dict,"-cpus"))
       cpus = dict["-cpus"]
    end
    if (haskey(dict,"-i"))
       inputFile = dict["-i"]
    end
    if (haskey(dict,"-o"))
       outputDirectory = dict["-o"]
    end
    if(run != nothing)
println("run:",run)
        if(run == "generate-model")
            createModel(inputFile,modelName)
        elseif(run == "run-model")
            nCycles = 100
            runModel(modelName,inputFile,nCycles)
        elseif(run == "demo")
            runDemo(demo)
        end
    end
    return
end

# https://juliadynamics.github.io/Agents.jl/stable/api/

should_we_collect(s, model, when::AbstractVector) = s ∈ when
should_we_collect(s, model, when::Bool) = when
should_we_collect(s, model, when) = when(model, s)

until(s, n::Integer, model) = s < n
until(s, n, model) = !n(model, s)

function runModel!(model,agent_step!, model_step!,n,mdata,adata)
    #adata = []
    #mdata = []
when = true
when_model = when

    df_agent = init_agent_dataframe(model, adata)
    df_model = init_model_dataframe(model, mdata)

    s = 0
    while until(s, n, model)
      #println("STEP:",s)
      if should_we_collect(s, model, when)
          collect_agent_data!(df_agent, model, adata, s)
      end
      if should_we_collect(s, model, when_model)
          collect_model_data!(df_model, model, mdata, s)
      end
      Agents.step!(model, agent_step!, model_step!, 1)
      s += 1
      if(model.exit)
          println("model.exit")
          break
      end
    end
    #println("END runModel!:",s)
    return df_agent, df_model
end

