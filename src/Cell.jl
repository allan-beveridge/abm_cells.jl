 # include("Events.jl")

function convertPairsToFloats(pairList)
    list = []
    for pair in pairList
        push!(list,pair.second)
    end
    return(list)
end

function getCellDictionary(agent_id,id_,position,u0,integrator)
    #println("getCellDictionary:",id_)
    d = Dict{Symbol,Any}()
    d[Symbol("label__")] = 0
    d[Symbol("id")] = agent_id
    d[Symbol("id_")] = id_
    d[Symbol("pos_")] = position
    fieldList = Vector{Symbol}()
    for pair in u0
        push!(fieldList,pair.first)
        d[pair.first] = pair.second
    end
    d[Symbol("u0_")] = fieldList
    #d[Symbol("integrator_")] = integrator
    #lineage = Lineage(string(id),1,data.deltat_,"alive",1,Vector{String}())
    #d[Symbol("lineage_")] = lineage
    return(d)
end

function getReactionNetwork(model,cellType)
    cellData = model.cellParamsMap[cellType]
    return(cellData.rn_)
end

Base.@kwdef mutable struct Lineage
    id_::String
    created_::Int32
    deltaT_::Float64
    status_::String # alive, divided, dead
    timeSteps_::Int32
    ancestors_::Vector{String}
end

mutable struct CellData <: AbstractAgent
    id::Int
    pos::NTuple{2,Float64}

    properties::Dict{Symbol,Any}
    lineage_::Lineage
    integrator_
    events_::Vector{Main.AbstractEvent}
    label_::String
    nSteps_::Int64
end

Base.getproperty(x::CellData, property::Symbol) = getfield(x, :properties)[property]
Base.setproperty!(x::CellData, property::Symbol, value) = getfield(x, :properties)[property] = value
Base.propertynames(x::CellData) = keys(getfield(CellData, :properties))


"""
   function executeCellEvents(model,cell)\n
   Executes all of the events attached to a cell\n
   called by update_cell()\n
"""
function executeCellEvents(model,cell)
    #println("executeCellEvents")
    eventList = getfield(cell,:events_)
    for event in eventList
        name = getfield(event,:name_)
        #println("execute Cell Event:",name)
        if(event.test(model,cell,event))
            event.execute(model,cell,event)
        end
    end
    return
end

"""
   function executeModelEvents(model)\n
   Executes all of the events attached to a model\n
   called by update_model()\n
"""
function executeModelEvents(model)
    #println("executeModelEvents")
    if(model.events == nothing)
        return
    end
    eventList = model.events
    cell = nothing
    for event in eventList
        name = getfield(event,:name_)
        #println("execute Model Event:",name)
        if(event.test(model,cell,event))
            event.execute(model,cell,event)
        end
    end
    #println("END executeModelEvents")
    return
end

function no_events_update_cell!(agent, model)
    nSteps = getfield(agent,:nSteps_) + 1
    setfield!(agent,:nSteps_,nSteps)
    integrator = getfield(agent,:integrator_)
    OrdinaryDiffEq.step!(integrator, model.dt, true)
    index = 1
    for field in agent.u0_
        setproperty!(agent,field,integrator.u[index])
        index += 1
    end
    return
end

function no_events_update_model!(model) #2
    model.nSteps += 1
    return
end

function printCell__(cell)
    cell_id = getfield(cell,:id)
    s = "cell::" * string(cell_id )
    for field in cell.u0_
        value = getproperty(cell,field)
        s *= " " * string(field) * "=" * string(value)
    end
    println(s)
end

"""
    function update_cell!(agent, model)\n
    used by Agents to run simulation\n
    calls executeCellEvents()\n
"""
function update_cell!(agent, model)
    #println("update_cell!")
    nSteps = getfield(agent,:nSteps_) + 1
    setfield!(agent,:nSteps_,nSteps)
    integrator = getfield(agent,:integrator_)
    OrdinaryDiffEq.step!(integrator, model.dt, true)
    index = 1
    for field in agent.u0_
        setproperty!(agent,field,integrator.u[index])
        index += 1
    end
    executeCellEvents(model,agent)
    return()
end

"""
    function update_model!(model)\n
    used by Agents to run simulation\n
    calls executeModelEvents()
"""
function update_model!(model) 
    model.nSteps += 1
    executeModelEvents(model)
    return
end

