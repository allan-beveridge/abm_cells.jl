using Serialization

function abort__(line,message)
    write(Base.stderr,"\n" * line * "\n")
    write(Base.stderr,message)
    write(Base.stderr,"\n")
    exit()
end

function abort__(message)
    write(Base.stderr,"\n")
    write(Base.stderr,message)
    write(Base.stderr,"\n")
    exit()
end

function readTextFile(inputFile)
    if(!isfile(inputFile))
        error = "Error, invalid file:" * inputFile
        println(error)
        exit()
        return(nothing)
    end
    nLines = countlines(inputFile)
    list = String[]
    f = open(inputFile,"r")
    for line in eachline(f)
        push!(list,String(line))
    end
    close(f)
    return(list)
end

function removeBlankLines(textList)
    list = String[]
    for line in textList
        text = strip(line)
        if(length(text) > 0)
            push!(list,line)
        end
    end
    return(list)
end

function removeCommentLines(textList,commentStr)
    list = String[]
    for line in textList
        text = strip(line)
        if(!startswith(text,commentStr))
            push!(list,line)
        end
    end
    return(list)
end

function removeComment(line,commentStr)
    text = strip(line)
    index = findfirst(commentStr,text)
    if(index != nothing)
        text = SubString(text,1,index[1]-1)
        text = rstrip(text)
    end
    return(text)
end

function findText(str,textList,index)
    nLines = length(textList)
    while(index < nLines)
        index +=1
        line = strip(textList[index])
        if(startswith(line,str))
            return(index)
        end
    end
    return(nothing)
end

function validateVariable_(var)
#    println("validateVariable_:",var)
    if(!endswith(var,")"))
        return("invalid variable:" * var)
    end
    var = replace(var,")" => "")
    cols = split(var,"(")
    if(length(cols) != 2)
        return("invalid variable:" * var)
    end
    return(nothing)
end

function parseVariable(line) # variable_name(Float64) = 0.00005
    text = strip(line)
    cols = split(strip(text),"=")
    if(length(cols) != 2)
        abort__(line,"Error, invalid variable\n")
    end
    var = strip(cols[1])
    vtext = strip(cols[2])
    error = validateVariable_(var)
    if(error != nothing)
        abort__(line,error * "\n")
    end
    cols = split(var,"(")
    varName = strip(cols[1])
    varType = chop(cols[2])
    dataType = getfield(Main, Symbol(varType))

    value, error = parseValue(vtext,varType)
    if(error != nothing)
        abort__(line,error * "\n")
    end
    return(varName,value,varType)
end

function parseValue(vtext,varType)
    error = nothing
    dataType = getfield(Main, Symbol(varType))
    if( startswith(vtext,"[")  && endswith(vtext,"]") )
        valueList = vtext[2:length(vtext)-1]
        varList = parseVariableList(valueList,dataType)
        if(varList == nothing)
            write(Base.stderr,line * "\n")
            write(Base.stderr,"Error parsing:" * vtext * "\n")
            exit()
        end
        return(varList,error)
    elseif(dataType == IOStream)
        return(vtext,error)
    elseif(dataType == String)
        return(vtext,error)
    elseif(dataType == Any)
        return(vtext,error)
    elseif(dataType == Symbol)
        return(Symbol(vtext),error)
    else
        try
            value = Base.parse(dataType,vtext)
            return(value,error)
        catch e # ArgumentError
            error = "Error, invalid value:" * vtext
            return(vtext,error)
        end
    end
end

function parseVariableList(text,dataType)
    text = strip(text)
    cols = split(text,",")
    varList = []
    for i in 1:length(cols)
        try
            value = Base.parse(dataType,cols[i])
            push!(varList,value)
        catch e # ArgumentError
            write(Base.stderr,sprint(showerror,e) * "\n")
            return(nothing)
        end
    end
    return(varList)
end

function findTaggedText(text,tag1,tag2)
    index1 = findall.(tag1, text)
    index2 = findall.(tag2, text)
    error = nothing
    if(length(index1) == 0)
        error = "Error, missing:" * tag1
        return(0,0,error)
    end
    if(length(index1) > 1)
        error = "Error, found extra:" * tag1
        return(0,0,error)
    end
    if(length(index2) == 0)
        error = "Error, missing:" * tag2
        return(0,0,error)
    end
    if(length(index2) > 1)
        error = "Error, found extra:" * tag2
        return(0,0,error)
    end
    posn1 = index1[1][1]
    posn2 = index2[1][1]
    if(posn1 > posn2)
        error = "Error, invalid input:" * tag2 * " appears before " * tag1
    end
    return(posn1,posn2,error)
end

function readSerializedData(binaryFile)
    data = deserialize(binaryFile)
    return(data)
end

function writeSerializedData(data,binaryFile)
    mode = "w"
    out = open(binaryFile,mode)
    serialize(out,data)
    close(out)
    return(nothing)
end

