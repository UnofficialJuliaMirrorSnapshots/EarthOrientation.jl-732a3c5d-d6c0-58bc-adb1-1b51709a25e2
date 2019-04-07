using Test
using EarthOrientation

using Dates: DateTime, Year, Hour, Second,
    datetime2julian, now

import EarthOrientation.OutOfRangeError

const FINALS = joinpath(@__DIR__, "finals.csv")
const FINALS_2000A = joinpath(@__DIR__, "finals2000A.csv")

push!(EOP_DATA, FINALS, FINALS_2000A)

"""
This is the langrangian interpolation routine from
ftp://hpiers.obspm.fr/iers/models/interp.f
"""
function lagint(x, y, xint)
    n = length(x)
    @assert n == length(y)
    yout = 0.0
    k = searchsortedlast(x, xint)
    if k < 2
        k = 2
    end
    if k > n - 2
        k = n - 2
    end

    for m in k-1:k+2
        term = y[m]
        for j in k-1:k+2
            if m != j
                term = term * (xint - x[j])/(x[m] - x[j])
            end
        end
        yout += term
    end

    yout
end

@testset "EarthOrientation" begin
    include("akima.jl")

    @testset "API" begin
        eop = get(EOP_DATA)
        dt = DateTime(2000, 1, 1)
        @test interpolate(eop, :dx, datetime2julian(dt)) ≈ -0.135
        @test interpolate(eop, :dx, dt) ≈ -0.135
        @test getxp(eop, dt) ≈ 0.043301
        @test getxp(dt) ≈ 0.043301
        @test getxp_err(eop, dt) ≈ 0.000092
        @test getxp_err(dt) ≈ 0.000092
        @test getyp(eop, dt) ≈ 0.377879
        @test getyp(dt) ≈ 0.377879
        @test getyp_err(eop, dt) ≈ 0.000099
        @test getyp_err(dt) ≈ 0.000099
        @test all(polarmotion(eop, dt) .≈ (0.043301, 0.377879))
        @test all(polarmotion(dt) .≈ (0.043301, 0.377879))
        @test getΔUT1(eop, dt) ≈ 0.3554784
        @test getΔUT1(dt) ≈ 0.3554784
        @test getΔUT1_err(eop, dt) ≈ 0.0000099
        @test getΔUT1_err(dt) ≈ 0.0000099
        @test getlod(eop, dt) ≈ 0.9333
        @test getlod(dt) ≈ 0.9333
        @test getlod_err(eop, dt) ≈ 0.0076
        @test getlod_err(dt) ≈ 0.0076
        @test getdψ(eop, dt) ≈ -50.607
        @test getdψ(dt) ≈ -50.607
        @test getdψ_err(eop, dt) ≈ 0.791
        @test getdψ_err(dt) ≈ 0.791
        @test getdϵ(eop, dt) ≈ -2.585
        @test getdϵ(dt) ≈ -2.585
        @test getdϵ_err(eop, dt) ≈ 0.298
        @test getdϵ_err(dt) ≈ 0.298
        @test all(precession_nutation80(eop, dt) .≈ (-50.607, -2.585))
        @test all(precession_nutation80(dt) .≈ (-50.607, -2.585))
        @test getdx(eop, dt) ≈ -0.135
        @test getdx(dt) ≈ -0.135
        @test getdx_err(eop, dt) ≈ 0.315
        @test getdx_err(dt) ≈ 0.315
        @test getdy(eop, dt) ≈ -0.204
        @test getdy(dt) ≈ -0.204
        @test getdy_err(eop, dt) ≈ 0.298
        @test getdy_err(dt) ≈ 0.298
        @test all(precession_nutation00(eop, dt) .≈ (-0.135, -0.204))
        @test all(precession_nutation00(dt) .≈ (-0.135, -0.204))
        # Reference value from Orekit which uses Hermite interpolation
        @test getΔUT1(eop, DateTime(2017, 1, 1, 12)) ≈ 0.5907459506337509 rtol=1e-4
        dt = DateTime(2100, 1, 1)
        @test_nowarn getdx(eop, dt, outside_range=:nothing)
        @test_logs (:warn, "No data available after 2017-10-09. The last valid value will be returned.") getdx(eop, dt, outside_range=:warn)
        @test_throws OutOfRangeError getdx(eop, dt, outside_range=:error)
        @test_throws ArgumentError getdx(eop, dt, outside_range=:norbert)
        @test_throws OutOfRangeError getdx(eop, DateTime(1973, 1, 1), outside_range=:error)
    end
    @testset "Interpolation" begin
        eop = get(EOP_DATA)
        interp = eop.UT1_TAI
        x = interp.x
        y = interp.y
        max_error = -Inf
        min_error = Inf
        @testset for d in DateTime(1973, 2, 1):Hour(1):DateTime(2000, 1, 1)
            mjd = datetime2julian(d) - EarthOrientation.MJD_EPOCH
            exp = lagint(x, y, mjd)
            act = interpolate(interp, mjd)
            @test exp ≈ act rtol=1e-6
        end
    end
    @testset "Leap Seconds" begin
        before = DateTime(2016, 12, 31, 23, 59, 59)
        during = before + Second(1)
        after = before + Second(2)

        # Reference values from AstroPy
        # We do not care about precision here and just want to verify whether
        # the leap second is applied correctly
        @test getΔUT1(before) ≈ -0.40873227809284624 rtol=1e-4
        @test getΔUT1(during) ≈ -0.40873228904642317 rtol=1e-4
        @test getΔUT1(after) ≈ 0.5912677 rtol=1e-4
    end
end
