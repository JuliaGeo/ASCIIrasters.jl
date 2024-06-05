"""
    read_ascii(filename::AbstractString) => Union{Tuple{Array, NamedTuple}, NamedTuple}

Reads an ASCII file. Parameters are parsed according to the [AAIGrid](https://gdal.org/drivers/raster/aaigrid.html) format. Data elements are assumed to be of the same type as the nodatavalue header parameter if possible. If there is no nodata_value field in the header, data type is estimated by checking if there are any floating numbers in the first 10 data rows.

# Keywords

 - `lazy`: when set to `true`, only the header of `filename` will be read, and only the `NamedTuple` of parameters be returned.

If not `lazy`, returns a `Tuple` with: an `Array` of the data and a `NamedTuple` of the header information.
"""
function read_ascii(filename::AbstractString; lazy = false)
    isfile(filename) || throw(ArgumentError("File $filename does not exist"))

    header = _read_header(filename)

    pars = (
        nrows = header["nrows"],
        ncols = header["ncols"],
        xll = header["xllcorner"],
        yll = header["yllcorner"],
        dx = header["dx"],
        dy = header["dy"],
        nodatavalue = header["nodata_value"]
    )

    if !lazy
        data = _read_data(filename, header)

        return (data, pars)
    end

    return pars
end

"""
    _read_header

Reads the first lines that don't start with a number. Converts them to a Dict
with 9 entries with all the parameters we need both for assessing data type and keeping header parameters.
"""
function _read_header(filename::AbstractString)
    header = Dict{String, Any}()
    open(filename, "r") do f
        # read and split line
        spl = split(strip(readline(f)), ' ')
        while tryparse(Float64, spl[1])===nothing # header lines do not start with a number

            # remove "" elements
            clean = deleteat!(spl, findall(x -> x == "", spl))
            # add to header
            header[lowercase(clean[1])] = clean[2]

            # continue reading and split line
            spl = split(strip(readline(f)), ' ')
        end
    end

    # store number of header lines in file
    header["nlines"] = length(header)

    # check required arguments and parse them to correct types
    header = _check_and_parse_required(header)

    # handle optional cellsize
    header = _cellsize_or_dxdy(header)

    # check if nodata exists, if not sets to default
    header = _check_nodata(header)

    return header
end

"""
    _read_data

Looks in `header` for a number of lines to ignore, then writes the following lines in a matrix with required element type.
"""
function _read_data(filename::AbstractString, header::Dict{String, Any})
    # only store data lines in a variable
    io = open(filename)
    # read the header
    [readline(io) for i=1:header["nlines"]]

    # now read the rest of the file
    raw = split(read(io, String))

    if header["datatype"] == Any # if datatype is undetermined yet
        ncheck = min(header["nrows"]*header["ncols"], 100) # check 100 numbers or less
        found_float = false
        for i in 1:ncheck
            if match(r"[.]", raw[i]) !== nothing
                found_float = true
                break
            end
        end

        datatype = found_float ? Float32 : Int32
    else
        datatype = header["datatype"]
    end

    out = parse.(datatype, raw)

    return permutedims(reshape(out, header["ncols"], header["nrows"]))
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

If nodata_value is a header line, keep it as nodatavalue and detect its type. If
nodata_value is missing, we set it to -9999.0 and its type to Any.
"""
function _check_nodata(header::Dict{String, Any})
    if haskey(header, "nodata_value")
        # no floating point in nodata ? datatype is considered int
        datatype = isnothing(match(r"[.]", header["nodata_value"])) ? Int32 : Float32
        header["nodata_value"] = parse(datatype, header["nodata_value"])
        header["datatype"] = datatype
    else
        header["nodata_value"] = -9999.0
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
