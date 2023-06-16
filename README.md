# ASCIIrasters.jl

[![Build Status](https://github.com/JuliaGeo/ASCIIrasters.jl/actions/workflows/CI.yml/badge.svg?branch=master)](https://github.com/JuliaGeo/ASCIIrasters.jl/actions/workflows/CI.yml?query=branch%3Amaster)
[![Coverage](https://codecov.io/gh/jguerber/ASCIIrasters.jl/branch/master/graph/badge.svg)](https://codecov.io/gh/jguerber/ASCIIrasters.jl)

Simple read and write functions for ASCII raster files. The ASCII format convention used is [AAIGrid](https://gdal.org/drivers/raster/aaigrid.html) (the QGIS default for ASCII rasters). 

## Exported functions

`read_ascii(filename::AbstractString)` reads a file and returns its contained data and corresponding header information in a `Tuple`.

`write_ascii(filename, dat; kwargs...)` writes a file. Required keywords arguments are (see docs): `ncols`, `nrows`, `xll`, `yll`, `dx`, `dy` and `nodatavalue`.
