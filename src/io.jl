"""
    read_ascii(filename::AbstractString) => Union{Tuple{Array, NamedTuple}, NamedTuple}

Reads an ASCII file. Parameters are parsed according to the [AAIGrid](https://gdal.org/drivers/raster/aaigrid.html) format.

# Keywords

 - `lazy`: when set to `true`, only the header of `filename` will be read, and only the `NamedTuple` of parameters be returned.

If not `lazy`, Returns a `Tuple` with: an `Array` of the data and a `NamedTuple` of the header information.
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
        NA = parse(Float64, match(r"NODATA_value (.+)", readline(file)).captures[1])

        params = (nrows = nr, ncols = nc, xll = xll, yll = yll, dx = dx, dy = dy, nodatavalue = NA)

        if !lazy
            out = Array{Float64}(undef, nr, nc)

            for row in 1:nr
                out[row, :] = parse.(Float64, split(readline(file), " ")[2:end]) # data lines start with a space
            end
            output = (out, params)
        else
            output = params
        end
    end

    return output
end

function write_ascii(filename::AbstractString, args::NamedTuple)
    write_ascii(filename; args...)
end

"""
    write_ascii(filename::AbstractString; kwargs...)

Writes data and header in an [AAIGrid](https://gdal.org/drivers/raster/aaigrid.html) raster file.

# Keywords

 - `ncols` and `nrows`: numbers of columns and rows
 - `xll` and `yll`: coordinates of the lower-left corner
 - `dx` and `dy`: dx and dy cell sizes in coordinate units per pixel
 - `nodatavalue`: a value that should be considered as holding no data
 - `dat` : an `AbstractArray` of the raster data. Only two-dimensional arrays are supported.
"""
function write_ascii(filename::AbstractString; ncols, nrows, xll, yll, dx, dy, nodatavalue, dat::AbstractArray{T, 2})
    size(dat) == (nrows, ncols) || throw(ArgumentError("$nrows rows and $ncols cols incompatible with array of size $(size(dat))"))
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
        for col in 1:nrows # ascii format is column by column
            write(f, " " * join(dat[:, col], " ") * "\n")
        end
    end
    return filename
end