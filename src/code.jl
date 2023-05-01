module Code

    struct equation_
        resultVariable_::String
        operator_::String
        formula_::String
        variableList_
    end

    function parseError__(line,message)
        write(Base.stderr,"\n" * line * "\n")
        write(Base.stderr,message)
        write(Base.stderr,"\n")
        exit()
        return
    end

    function validate__(equation)
        cols = split(strip(equation))
        nCols = length(cols)
        if(nCols < 3)
            parseError__("\n","Error, invalid equation:" * equation * "\n")
        end
        remainder = mod(nCols,2)
        if(remainder != 1)
            parseError__("\n","Error, parsing equation:" * equation * "\n")
        end
    
        if(findfirst("",cols[2]) == nothing)
            parseError__("\n","Error, invalid equation:" * equation * "\n")
        end
        if(cols[2]!="=" && cols[2]!="+=" && cols[2]!="-=" && cols[2]!="*=" && cols[2]!="/=")
            parseError__("\n","Error, invalid equation:" * equation * "\n")
        end
        return(cols)
    end

    function checkVariables__(cols,varMap,symbolChar="@")
        nCols = length(cols)
        for i in 1:2:nCols
            #var = symbolChar * cols[i]
            var = cols[i]
            if (!haskey(varMap,var))
                if(tryparse(Float64, cols[i]) == nothing)
                    return("checkVariables__(), Error parsing equation, invalid variable:" * cols[i] * "\n")
                end
            end
        end
        return(nothing)
    end

    function generateEquation(equation,varMap,symbolChar="@")
        cols = Code.validate__(equation)
        error = Code.checkVariables__(cols,varMap)
        if(error != nothing)
            parseError__(equation,error)
        end
        nCols = length(cols)
        res = cols[1]
        operator = cols[2]
        
        variableList = []
        if(tryparse(Float64, cols[3]) != nothing)
            variable = cols[3]
        else
            variable = symbolChar * cols[3]
            push!(variableList,variable)
        end
        eqn = variable
        index = 4
        for i in 4:2:nCols
            operator = cols[i]
            if(tryparse(Float64, cols[i+1]) != nothing)
                variable = cols[i+1]
            else
                variable = symbolChar * cols[i+1]
                push!(variableList,variable)
            end
            eqn *= " " * operator * " " * variable
        end
        #println("END generateEquation:",equation)
        return(equation_(res,cols[2],eqn,variableList))
    end

    function calculate(equation,varMap)
        code = equation.formula_
        for variable in equation.variableList_
            value = varMap[variable[2:end]]
            code = replace(code,variable => string(value))
        end
        ex = Meta.parse(code)
        value = eval(ex)
        return(equation.resultVariable_,value)
    end

end # module

