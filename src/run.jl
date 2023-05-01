include("main.jl")
include("CommandParser.jl")

function help()

    println("\n==========================================================================\n")
    println("Need to run a simulation in two steps")
    println("Step 1 builds the model\n")
    println("julia run.jl -build demo.dat\n")
    println("reads demo.dat and builds a serialized model, which is output to demo.jls\n")
    println("Step 2 runs the simulation\n")
    println("julia run.jl -model demo.jls -n 200\n")
    println("\nreads the model (demo.jls) and runs the simulation; -n = number of cycles\n")
    println("\n==========================================================================\n")
    return

end

function errorMessage__(message)
    write(Base.stderr,"\n" * message * "\n")
    exit()
end

function checkFile(file)
    if(!isfile(file))
        errorMessage__("Error, invalid input file:" * file * "\n\n")
    end
    return
end

"function which runs the program"
function run_(option,inputFile,nCycles)
    println("run:",option," ",inputFile)
    modelName = nothing
    if(option == "build")
        checkFile(inputFile)
        modelName = replace(inputFile,".dat" => "")
        createModel(inputFile,modelName)
    elseif(option == "model")
        checkFile(inputFile)
        suffix = ".jls"
        if(endswith(inputFile,suffix))
            modelName = replace(inputFile,suffix => "")
        else
            errorMessage__("Error, invalid input file:" * inputFile * "\n Input file must be " * suffix * "\n\n")
        end
        runModel(modelName,inputFile,nCycles)
    end
    return
end

function parseOptions(optionsFile)
    ENV["GKSwstype"] = 100
    parameterDictionary = CommandParser.readParameters(optionsFile)
    dict = CommandParser.parse(parameterDictionary,ARGS)

    if(length(dict) == 0)
        help()
    end

    nCycles = 100
    inputFile = nothing
    run = nothing
    if (haskey(dict,"-build"))
       run = "build"
       inputFile = dict["-build"]
    elseif (haskey(dict,"-model"))
       run = "model"
       inputFile = dict["-model"]
    end
    if (haskey(dict,"-n"))
       nCycles = dict["-n"]
    end
    run_(run,inputFile,nCycles)
    return
end

function main()
    optionsFile = "run.dat"
    parseOptions(optionsFile)
    return
end

main()


