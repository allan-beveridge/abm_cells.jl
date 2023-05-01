using Random
include("main.jl")


function testIntegrate__(abm_data,outPrefix,cellIndex=0)
    Random.seed!(6549)
    outputDir, outputPrefix = abm_data["output"]
    createDirectory(outputDir)
    outputDir = abspath(outputDir)
    println("O:",outputDir, " ", outputPrefix)
    model = initialiseModel(abm_data,cellIndex)

    cellMap = abm_data["cellMap"]
    data_a = cellMap["A"]
    modelParams = data_a
    maxTime = modelParams.tspan_[2]
    nCycles = Int64(maxTime/modelParams.deltat_)
    nCycles = abm_data["nCycles"]
    #nCycles = 400000
    println("nCycles:",nCycles)
    println("testIntegrate__:",modelParams.deltat_)
    run_info = "dt=" * string(modelParams.deltat_) * "_maxt=" * string(maxTime)
    aList = [:r,:e_t,:e_m,:q,:m_r,:m_t,:m_m,:m_q,:c_r,:c_t,:c_m,:c_q,:a,:s_i]
    aList = [:id_,:r,:e_t,:e_m,:q,:m_r,:m_t,:m_m,:m_q,:c_r,:c_t,:c_m,:c_q,:a,:s_i]

    agentResults, modelResults = run!(model, no_events_update_cell!, no_events_update_model!, nCycles; mdata = [], adata = aList)
    #agentResults, modelResults = run!(model, no_events_update_cell!, no_events_update_model!, nCycles; mdata = [])

    roundColumns(agentResults,aList)
    csvFile = outputDir * "/" * outPrefix * "_general_abm_cell.csv"
    CSV.write(csvFile,agentResults)
    println(csvFile)

    plotPrefix = outPrefix * "_" * run_info
    ("prefix::",plotPrefix)
    agentPlot(agentResults,model.nAgents,outputDir,plotPrefix)
    return
end

function run_demo1(inputFile)
    ENV["GKSwstype"] = 100
    Random.seed!(6549)
    println("run_demo1")
    abm_data = parseInputFile(inputFile)
    nCycles = abm_data["nCycles"]
    outputDir, outputPrefix  = abm_data["output"]
println(outputDir," ",outputPrefix)
    cellIndex = 0
    testIntegrate__(abm_data,"demo",cellIndex)
    println("finished")
    return
end

function run_demo2()

end

#run_demo2()
#exit()
run_demo1("demo1.dat")

