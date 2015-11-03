

# @generated function Base.zero{U<:AbstractUnum}(::Type{U})
#   c = unumConstants(U)
#   :($(c.zero))
# end

# # convert any floating point number to a unum
# # lets worry about the base-2 case for now, then generalize later:
# @generated function call{E,UINT, FLOAT<:AbstractFloat}(::Type{Unum{E,UINT}}, x::FLOAT)
#   B = 2
#   c = unumConstants(B, E, UINT)
#   f = FloatInfo(FLOAT)

#   # this is the actual conversion function:
#   quote
#     println($(f.uintType))

#     ival = reinterpret($(f.uintType), x)
#     exponent = (ival & $(f.emask)) >> $(f.fpos)
#     fraction = (ival & $(f.fmask))
#     sign = ival >> $(f.nbits-1)

#     if exponent == 0
#       if fraction == 0
#         # zero (exact)
#         return _i2u($B,$E,$(c.zero))
#       end
#     end

#     # for x in (ival, exponent, fraction, sign)
#     #   println(bits(x))
#     # end

#   end
# end

# ----------------------------------------------------------------

type FloatInfo{F<:AbstractFloat, I<:Integer}
  nbits::Int
  esize::Int
  fsize::Int
  emask::I
  fmask::I
  FloatInfo() = new()
end

ispositive(x::AbstractFloat) = x >= 0.
isnegative(x::AbstractFloat) = x < 0.

# keep a cache for given parameter sets so we don't keep rebuilding the constants
const floatConstCache = Dict{DataType, FloatInfo}()

const _f2uintMap = Dict(
    Float16   => UInt16,
    Float32   => UInt32,
    Float64   => UInt64,
    Float128  => UInt128,
  )

const 

# expect this to be called from a generated function, so we're being passed type params
function floatConstants(F::DataType)
  get!(floatConstCache, F) do
    info = FloatInfo{F}()
    info.nbits = numbits(F)
    I = _f2uintMap[F]



    info.base = B
    info.nbits = N
    info.UINT = getUINT(U)
    info.INT = getINT(U)

    info
  end
end

# ----------------------------------------------------------------

# NOTE: these are not ideal conversions... just want to get a ballpark answer
function Base.float(base, esize, fsize, e, f)
  if e == 0
    return base ^ (e - 2^(esize-1)) * f / (2^fsize)
  else
    return base ^ (e - 2^(esize-1) - 1) * (1 + (base-1) * f / (2^fsize))
  end
end
Base.float{B,ESS,FSS}(u::AbstractUnum{B,ESS,FSS}) = (isnegative(u) ? -1 : 1) * float(Float64(B), esize(u), fsize(u), exponent(u), significand(u))


# ----------------------------------------------------------------

# to extract a value:


# # this stores some key sizes and masks for doing float conversions
# type FloatInfo{F<:AbstractFloat, U<:AbstractUnum}
#   nbits::Int
#   epos::Int
#   fpos::Int
#   esize::Int
#   fsize::Int
#   signbitmask::U
#   emask::U
#   fmask::U
#   fType::DataType
#   uType::DataType
# end

# function Base.show{F,U}(io::IO, info::FloatInfo{F,U})
#   println("FloatInfo{$F,$U}:")
#   for fn in fieldnames(info)[1:5]
#     println(@sprintf("  %15s %6d", fn, getfield(info, fn)))
#   end
#   for fn in fieldnames(info)[6:8]
#     println(@sprintf("  %15s %s", fn, bits(getfield(info, fn))))
#   end
# end

# FloatInfo(::Type{Float16}) = FloatInfo(Float16, UInt16, 16, 5)
# FloatInfo(::Type{Float32}) = FloatInfo(Float32, UInt32, 32, 8)
# FloatInfo(::Type{Float64}) = FloatInfo(Float64, UInt64, 64, 11)
# # FloatInfo(::Type{Float128}) = FloatInfo(Float128, UInt128, 128, 15, 113)

# function FloatInfo{F,U}(::Type{F}, ::Type{U}, nbits::Int, esize::Int)
#   fsize = nbits - esize - 1
#   FloatInfo{F,U}(nbits,
#                     nbits-1,
#                     fsize,
#                     esize,
#                     fsize,
#                     createmask(U, nbits, 1),
#                     createmask(U, nbits-1, esize),
#                     createmask(U, fsize, fsize),
#                     F,
#                     U)
# end
