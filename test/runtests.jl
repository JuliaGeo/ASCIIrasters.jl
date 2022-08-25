using ASCIIrasters
using Test

@testset verbose = true "ASCIIrasters.jl" begin
    asc = read_ascii("../example/small.asc")
    @testset "read" begin
        @test read_ascii("../example/small.asc"; lazy = true) isa NamedTuple
        @test asc[1][2,3] == 3
        @test_throws ArgumentError read_ascii("doesntexist.asc")
    end

    @testset "write" begin
        pars = (
            ncols = 4,
            nrows = 4,
            xll = 15,
            yll = 12,
            dx = 1,
            dy = 1,
            nodatavalue = 1,
        )
        dat = [1 1 1 1;2 2 2 2;3 3 3 3;4 4 4 4]
        @test write_ascii("./test.asc", dat, pars) == "./test.asc"
    end

    @testset "read and write" begin
        @test read_ascii("test.asc") != asc
        example2 = write_ascii("../example/small2.asc", asc[1], asc[2])
        @test read_ascii("../example/small2.asc")[1] == asc[1]
    end
end
