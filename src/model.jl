
function createCatalystIntegrator(rn,u0,p,tspan)
    prob = ODEProblem(rn,u0,tspan,p)
    integrator = OrdinaryDiffEq.init(prob, OrdinaryDiffEq.Rodas4(); advance_to_tstop = true)
    return(integrator)
end

"""
    function initialiseModel(abm_data)\n
    uses abm_data, genereated by parseInputFile(), to build the ABM\n
    calls initialiseCells()
"""
function initialiseModel(abm_data,cellIndex=0)
    #println("initialiseModel")
    cellMap = abm_data["cellMap"]
    keyList = collect(keys(cellMap))
    data = cellMap[keyList[1]]
    nCells = data.nCells_
    tspan = data.tspan_
    dt = data.deltat_
    outputMap = abm_data["outputMap"]

    prob = ODEProblem(data.rn_, data.u0_, data.tspan_, data.p_)
    integrator = OrdinaryDiffEq.init(prob, OrdinaryDiffEq.Rodas4(); advance_to_tstop = true)

    model = ABM(
        CellData; #Cell1;
        properties = Dict(
            :tspan => data.tspan_,
            :cellParamsMap => cellMap,
            :outputMap => outputMap,
            :events => nothing,
            :variables => Dict{String,Any}(),
            :createIntegrator => createCatalystIntegrator,
            :genVarMap_ => Dict{String,Any}(),
            :tspan => tspan, 
            :lastCell => nCells, 
            :nAgents => nCells, 
            :i => integrator, # The OrdinaryDiffEq integrator,
            :dt => dt, 
            :exit => false,
            :nSteps => 0
        ),
    )
    initialiseCells(model,abm_data,cellIndex)
    modelEventsMap =  getModelEvents(abm_data)
    model.events =  collect(values(modelEventsMap))

    model.genVarMap_ = Dict{String,Any}()
    #initialiseModelVariables(model)

    #variables = Events.getAgentVariables(":model",model.events)
    #model.variables = variables
    return(model)
end

"""
    initialiseCells(model,abm_data)\n
    uses abm_data, genereated by parseInputFile(), to generate the\n
    initial list of cells.\n
    called by initialiseModel()
"""
function initialiseCells(model,abm_data,cellIndex=0)
    cellMap = abm_data["cellMap"]
    cellList = parseCells(abm_data["cellList"])
    u0_map = abm_data["u0"]
    nCells = length(cellList)
    cell_u0 = nothing
    for i in 1:nCells
        cellType, cell_id, position = cellList[i]
        #println(cellType, " ", cell_id, " ", position)
        cellParams = cellMap[cellType]

        events = getCellEvents(abm_data,cellType)

        if(haskey(u0_map,cellType))
            cell_u0 = deepcopy(u0_map[cellType])
        else
            cell_u0 = deepcopy(cellParams.u0_)
        end
        u0 = convertPairsToFloats(cell_u0)

        rn =  getReactionNetwork(model,cellType)
        integrator = model.createIntegrator(rn,u0,cellParams.p_,cellParams.tspan_)
        #integrator = createIntegrator(cellParams.rn_,u0,cellParams.p_,cellParams.tspan_)

        #prob = generate_ode_problem(cellParams,u0,cellParams.tspan_)
        ##prob = ODEProblem(model.rn, u0, cellParams.tspan_, cellParams.p_)
        #integrator = OrdinaryDiffEq.init(prob, OrdinaryDiffEq.Rodas4(); advance_to_tstop = true)

        lineage = Lineage(string(i),1,cellParams.deltat_,"alive",1,Vector{String}())
        cell_id = cellIndex + i
        d = getCellDictionary(i,cell_id,position,cell_u0,integrator)
        #d = getCellDictionary(i,cell_id,position,cellParams.u0_,integrator)
        d[Symbol("label__")] = i
        d[Symbol("label")] = i
        cell = add_agent!(position,model,d,lineage,integrator,events,cellType,0)
        cell.p_ = cellParams.p_
        # cell.rn_ = cellParams.rn_
        cellEvents = getfield(cell,:events_)
        cell.variables_ = Events.getAgentVariables(":cell",cellEvents)
    end
    model.nAgents = nCells
    model.lastCell = nCells
    #initialiseModelVariables(model)
    #println("====mvm:",model.variables)
    return()
end

function initialiseModelVariables(model)
    modelVariables = Dict{String,Any}()
    for cell in allagents(model)
        cellEvents = getfield(cell,:events_)
        cellModelVariables = Events.getAgentVariables(":model",cellEvents)
        for (key,data) in cellModelVariables
            modelVariables[key] = data
        end
    end
    for event in model.events
        modelEventVariables = Events.getAgentVariables(":model",model.events)
        for (key,data) in modelEventVariables
            modelVariables[key] = data
        end
    end
    model.variables = modelVariables
end


