module Equations

    struct Equation
        formula_::String
        variables_::Vector{String}
        symbolChar::String
    end

    function generateEquation(equation,symbolChar = "\$")
        #println("generateEqn:",equation)
        char = " "
        eqn = replace(equation,"(" => " ")
        eqn = replace(eqn,")" => char)
        eqn = replace(eqn,"+" => char)
        eqn = replace(eqn,"-" => char)
        eqn = replace(eqn,"*" => char)
        eqn = replace(eqn,"/" => char)
        cols = split(strip(eqn))
        start = 1
        eqn = ""
        s2 = equation * " "
        posn = 1
        for key in cols
            s1, s2 = splitString__(s2,key)
            eqn *= s1 * symbolChar * key
        end
        return(Equation(eqn,cols,symbolChar))
    end

    function splitString__(s,substr)
        index = findfirst(substr,s)
        s1 = s[1:index[1]-1]
        s2 = s[index[1]:end]
        s2 = replace(s2,substr => "",count=1)
        return(s1,s2)
    end

    function execute__(code)
        ex = Meta.parse(code)
        try
            res = eval(ex)
            return(res)
        catch ex
            #println("ex:",ex)
            println("Error, illegal equation")
            return(nothing)
        end
    end

    function check_eqn(varMap,eqn)
        equation = generateEquation(eqn)
        println("E:",equation)
        code = generateCode(equation,varMap)
        println(code)
        res = execute__(code)
        if(res == nothing)
            return(false)
        end
        println("res:",res)
        return(true)
    end

    function generateCode(equation,varMap)
        formula = equation.formula_
        for var in equation.variables_
            var = equation.symbolChar * var
            value = varMap[var]
            formula = replace(formula,var => value)
        end
        return(formula)
    end

    function execute_eqn(varMap,eqn)
        println(varMap)
        println(eqn)
        equation = Event.generateEquation(eqn)
        println(equation.formula_)
        println(equation.variables_)
        println(equation.symbolChar)
        value = "1"
        formula = equation.formula_
        for var in equation.variables_
            var = equation.symbolChar * var
            formula = replace(formula,var => value)
            println(var)
        end
        println(formula)
    end

function evaluateEquation(equation,parameterMap,symbolChar = "\$")
    #println("p:",parameterMap)
    #println("e:",equation)
    eqn = equation.formula_
    for var in equation.variables_
        key = symbolChar * var
        value = parameterMap[key]
        #println(var, " ", value, " ", typeof(value))
        eqn = replace(eqn,key => value)
    end
    #println(eqn)
    ex = Meta.parse(eqn)
    res = eval(ex)
    return(res)
end

    function test__()
        eqn = "((c_q + c_m + c_t + c_r) * (γ_max*a/(K_γ + a)))/M"
        varMap = Dict{}()
        varMap["\$c_q"] = 1.0
        varMap["\$c_1"] = 1.0
        varMap["\$c_m"] = 1.0
        varMap["\$c_t"] = 1.0
        varMap["\$c_r"] = 1.0
        varMap["\$c_1"] = 1.0
        varMap["\$γ_max"] = 1.0
        varMap["\$a"] = 1.0
        varMap["\$K_γ"] = 1.0
        varMap["\$M"] = 1.0
        if(!Equations.check_eqn(varMap,eqn))
            println("eqn:",eqn)
            exit()
        end
        return
    end

end # module Equation

#Equations.test__()


