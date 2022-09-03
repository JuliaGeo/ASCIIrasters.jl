"""
    read_ascii(filename::AbstractString) => Union{Tuple{Array, NamedTuple}, NamedTuple}

Reads an ASCII file. Parameters are parsed according to the [AAIGrid](https://gdal.org/drivers/raster/aaigrid.html) format. Data elements are assumed to be of the same type as the nodatavalue header parameter.

# Keywords

 - `lazy`: when set to `true`, only the header of `filename` will be read, and only the `NamedTuple` of parameters be returned.

If not `lazy`, returns a `Tuple` with: an `Array` of the data and a `NamedTuple` of the header information.
"""
function read_ascii(filename::AbstractString; lazy = false)
    isfile(filename) || throw(ArgumentError("File $filename does not exist"))
    output = open(filename, "r") do file
        nc = parse(Int, match(r"ncols (.+)", readline(file)).captures[1])
        nr = parse(Int, match(r"nrows (.+)", readline(file)).captures[1])
        xll = parse(Float64, match(r"xllcorner (.+)", readline(file)).captures[1])
        yll = parse(Float64, match(r"yllcorner (.+)", readline(file)).captures[1])
        dx = parse(Float64, match(r"dx (.+)", readline(file)).captures[1])
        dy = parse(Float64, match(r"dy (.+)", readline(file)).captures[1])
        na_str = match(r"NODATA_value (.+)", readline(file)).captures[1]

        # no floating point in nodata ? datatype is considered int
        datatype = isnothing(match(r"[.]", na_str)) ? Int32 : Float32
        NA = parse(datatype, na_str)

        params = (nrows = nr, ncols = nc, xll = xll, yll = yll, dx = dx, dy = dy, nodatavalue = NA)

        if !lazy
            out = Array{datatype}(undef, nr, nc)

            for row in 1:nr
                out[row, :] = parse.(datatype, split(readline(file), " ")[2:end]) # data lines start with a space
            end
            output = (out, params)
        else
            output = params
        end
    end

    return output
end

"""
    _read_header

Reads the first lines that don't start with a space. Converts them to a Dict
with 9 entries with all the parameters we need both for assessing data type and keeping header parameters.
"""
function _read_header(filename::AbstractString)
    header = Dict{String, Any}()
    open(filename, "r") do f
        line = readline(f)
        while line[1] != ' '
            # split line
            spl = split(line, ' ')
            # remove "" elements
            clean = deleteat!(spl, findall(x -> x == "", spl))
            # add to header
            header[clean[1]] = clean[2]

            # continue reading
            line = readline(f)
        end
    end

    # store number of header lines in file
    header["nlines"] = length(header)

    # check required arguments and parse them to correct types
    header = _check_and_parse_required(header)

    # handle optional cellsize
    header = _cellsize_or_dxdy(header)

    header = _check_nodata(header)

    return header
end

function _read_data(filename::AbstractString, header::Dict{String, Any})
    # only store data lines in a variable
    raw = open(readlines, filename)[(header["nlines"]+1):end]

    raw = map(l -> split(l, ' ')[2:end], raw) # remove spaces:  this is now a
    # vector of vector of strings

    if header["datatype"] == Any # if datatype is undetermined yet
        ncheck = min(header["nrows"], 10) # check 10 rows or less
        found_float = false
        for i in 1:ncheck
            if !all(map(w -> match(r"[.]", w) === nothing, raw[i]))
                found_float = true
                break
            end
        end

        datatype = found_float ? Float32 : Int32
    else
        datatype = header["datatype"]
    end
    out = map(l -> parse.(datatype, l), raw)
    return mapreduce(permutedims, vcat, out) # convert to matrix
end

"""
    _check_and_parse

Checks that all required header parameters are here and parses them to the convenient types.
"""
function _check_and_parse_required(header::Dict{String, Any})
    haskey(header, "nrows") || _throw_missing_line("nrows")
    haskey(header, "ncols") || _throw_missing_line("ncols")
    haskey(header, "xllcorner") || _throw_missing_line("xllcorner")
    haskey(header, "yllcorner") || _throw_missing_line("yllcorner")

    header["nrows"] = parse(Int, header["nrows"])
    header["ncols"] = parse(Int, header["ncols"])
    header["xllcorner"] = parse(Float64, header["xllcorner"])
    header["yllcorner"] = parse(Float64, header["yllcorner"])

    return header
end

function _cellsize_or_dxdy(header::Dict{String, Any})
    
    if haskey(header, "cellsize")

        haskey(header, "dx") && @warn "Provided cellsize, ignoring dx"
        haskey(header, "dy") && @warn "Provided cellsize, ignoring dy"

        cs = parse(Float64, header["cellsize"])
        header["dx"] = cs
        header["dy"] = cs

        delete!(header, "cellsize")
    else
        haskey(header, "dx") || _throw_missing_line("dx")
        haskey(header, "dy") || _throw_missing_line("dy")

        header["dx"] = parse(Float64, header["dx"])
        header["dy"] = parse(Float64, header["dy"])
    end

    return header
end

"""
    _check_nodata

If NODATA_value is a header line, keep it as nodatavalue and detect its type. If
NODATA_value is missing, we set it to -9999.0 and its type to Any.
"""
function _check_nodata(header::Dict{String, Any})
    if haskey(header, "NODATA_value")
        # no floating point in nodata ? datatype is considered int
        datatype = isnothing(match(r"[.]", header["NODATA_value"])) ? Int32 : Float32
        header["NODATA_value"] = parse(datatype, header["NODATA_value"])
        header["datatype"] = datatype
    else
        header["NODATA_value"] = -9999.0
        header["datatype"] = Any
    end

    return header
end

function _throw_missing_line(par::String)
    throw("$par not found in file header")
end

function write_ascii(filename::AbstractString, dat::AbstractArray, args::NamedTuple; kwargs...)
    write_ascii(filename, dat; args..., kwargs...)
end

"""
    write_ascii(filename::AbstractString; kwargs...)

Writes data and header in an [AAIGrid](https://gdal.org/drivers/raster/aaigrid.html) raster file.

# Argument

 - `dat`: the `AbstractArray` of data to write

# Keywords

Required:

 - `ncols` and `nrows`: numbers of columns and rows
 - `xll` and `yll`: coordinates of the lower-left corner
 - `dx` and `dy`: dx and dy cell sizes in coordinate units per pixel

Optional:

 - `nodatavalue`: a value that should be considered as representing no data. Default is -9999.0
 - `detecttype`: when set to `true`, elements of `dat` are converted to the same type as `nodatavalue`. Leave `false` to coerce everything (both `dat` and `nodatavalue`) to `Float32`.

Returns the written file name.
"""
function write_ascii(filename::AbstractString, dat::AbstractArray{T, 2}; ncols::Int, nrows::Int, xll::Real, yll::Real, dx::Real, dy::Real, nodatavalue::Union{AbstractFloat, Int32, Int64}=-9999.0, detecttype = false) where T
    size(dat) == (nrows, ncols) || throw(ArgumentError("$nrows rows and $ncols cols incompatible with array of size $(size(dat))"))

    datatype = if detecttype
        typeof(nodatavalue) <: AbstractFloat ? Float32 : Int32 
    else
        Float32
    end
    
    # ensure right type for dat and nodatavalue
    dat = datatype.(dat)
    nodatavalue = datatype(nodatavalue)

    # Write
    open(filename, "w") do f
        write(f,
            """
            ncols        $(string(ncols))
            nrows        $(string(nrows))
            xllcorner    $(string(xll))
            yllcorner    $(string(yll))
            dx           $(string(dx))
            dy           $(string(dy))
            NODATA_value  $(string(nodatavalue))
            """
        )
        for row in 1:nrows # fill row by row
            write(f, " " * join(dat[row, :], " ") * "\n")
        end
    end
    return filename
end