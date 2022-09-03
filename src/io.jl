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

function write_ascii(filename::AbstractString, dat::AbstractArray, args::NamedTuple; kwargs...)
    write_ascii(filename, dat; args..., kwargs...)
end

"""
    write_ascii(filename::AbstractString; kwargs...)

Writes data and header in an [AAIGrid](https://gdal.org/drivers/raster/aaigrid.html) raster file.

# Argument

 - `dat`: the `AbstractArray` of data to write

# Keywords

 - `ncols` and `nrows`: numbers of columns and rows
 - `xll` and `yll`: coordinates of the lower-left corner
 - `dx` and `dy`: dx and dy cell sizes in coordinate units per pixel
 - `nodatavalue`: a value that should be considered as holding no data

 - `detecttype`: when set to `true`, elements of `dat` are assumed to be of the same type as `nodatavalue`. Leave `false` to coerce everything (both `dat` and `nodatavalue` to `Float32`).

Returns the written file name.
"""
function write_ascii(filename::AbstractString, dat::AbstractArray{T, 2}; ncols::Int, nrows::Int, xll::Real, yll::Real, dx::Real, dy::Real, nodatavalue::Union{AbstractFloat, Int32, Int64}, detecttype = false) where T
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