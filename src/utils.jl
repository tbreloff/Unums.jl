
# this section is pretty important... I create a type with key constants specific to a certain 
# parameter set which defines a Unum.  

numbits{U}(::Type{U}) = sizeof(U) * 8
Base.bits{U<:AbstractUnum}(u::U) = bin(reinterpret(getUINT(U), u), numbits(U))

# TODO: generate these
getUINT{U<:FixedUnum64}(::Type{U}) = UInt64
(~){U<:FixedUnum64}(u::U) = Base.box(U, Base.not_int(Base.unbox(U,u)))
(&){U<:FixedUnum64}(u1::U, u2::U) = Base.box(U, Base.and_int(Base.unbox(U,u1), Base.unbox(U,u2)))
(|){U<:FixedUnum64}(u1::U, u2::U) = Base.box(U, Base.or_int(Base.unbox(U,u1), Base.unbox(U,u2)))
(<<){U<:FixedUnum64}(u::U, i::Int) = Base.box(U, Base.shl_int(Base.unbox(U,u), Base.unbox(Int,i)))

# helper function to create a bit mask for Unsigned int UINT, where:
#   there are "numones" 1's in the bits starting at "left", and 0's otherwise
function createmask{U<:AbstractUnum}(::Type{U}, left::Int, numones::Int)
  @assert numones >= 0
  @assert left >= numones
  @assert left <= numbits(U)
  
  UINT = getUINT(U)
  o = one(UINT)
  # println("$U $left $numones $UINT $o")
  x = (left == numbits(UINT) ? typemax(UINT) : (o << left) - o)
  # println(bits(x))
  x -= ((o << (left-numones)) - o)
  # println(bits(x))
  reinterpret(U, x)
end



# ---------------------------------------------------------------------------------------

# keep a cache for given parameter sets so we don't keep rebuilding the constants
# const unumConstCache = Dict{Tuple{Int,Int,DataType}, Dict{Symbol, Any}}()

type UnumInfo{U<:AbstractUnum}
  base::Int
  nbits::Int
  esize::Int
  fsize::Int
  utagsize::Int
  
  epos::Int
  fpos::Int
  ubitpos::Int
  signbitpos::Int
  # negbitpos::Int
  # uboundbitpos::Int
  # zerobitpos::Int
  # infbitpos::Int
  # nanbitpos::Int

  emask::U
  fmask::U
  ubitmask::U
  signbitmask::U
  # negbitmask::U
  # uboundbitmask::U
  # zerobitmask::U
  # infbitmask::U
  # nanbitmask::U

  zero::U      # exact zero
  poszero::U   # inexact positive zero
  negzero::U   # inexact negative zero
  posinf::U    # exact positive inf
  neginf::U    # exact negative inf
  mostpos::U   # exact maximum positive real
  leastpos::U  # exact minimum positive real
  mostneg::U   # exact minimum negative real
  leastneg::U  # exact maximum negative real
  nan::U       # this is "quiet NaN" from the book
  null::U      # this is "signaling NaN" from the book... can maybe repurpose to replace Nullable

  UnumInfo() = new()
end


const NUM_UNUMINFO_INTS = 9
const NUM_UNUMINFO_MASKS = 15

function Base.show{T}(io::IO, info::UnumInfo{T})
  println("UnumInfo{$T}:")
  for fn in fieldnames(info)[1:NUM_UNUMINFO_INTS]
    println(@sprintf("  %15s %6d", fn, getfield(info, fn)))
  end
  for fn in fieldnames(info)[NUM_UNUMINFO_INTS+1:end]
    println(@sprintf("  %15s %s", fn, bits(getfield(info, fn))))
  end
end

# UnumInfo{T}(::Type{T}) = UnumInfo{T}(zeros(Int, NUM_UNUMINFO_INTS)..., zeros(T, NUM_UNUMINFO_MASKS)...)


# keep a cache for given parameter sets so we don't keep rebuilding the constants
const unumConstCache = Dict{DataType, UnumInfo}()

# expect this to be called from a generated function, so we're being passed type params
function unumConstants(U::DataType)
  get!(unumConstCache, U) do
    # info = UnumInfo(U)
    info = UnumInfo{U}()

    B, E = U.parameters
    info.base = B
    info.nbits = numbits(U)
    info.esize = E
    info.utagsize = 2
    info.fsize = info.nbits - info.utagsize - info.esize
    @assert info.fsize > 0

    info.epos = info.nbits
    info.fpos = info.nbits - info.esize
    info.ubitpos = 1
    info.signbitpos = 2
    # info.negbitpos = 3
    # info.uboundbitpos = 4
    # info.zerobitpos = 5
    # info.infbitpos = 6
    # info.nanbitpos = 7
    # println("1: ", info)

    info.emask = createmask(U, info.epos, info.esize)
    info.fmask = createmask(U, info.fpos, info.fsize)
    info.ubitmask = createmask(U, info.ubitpos, 1)
    info.signbitmask = createmask(U, info.signbitpos, 1)
    # info.negbitmask = createmask(U, info.negbitpos, 1)
    # info.uboundbitmask = createmask(U, info.uboundbitpos, 1)
    # info.zerobitmask = createmask(U, info.zerobitpos, 1)
    # info.infbitmask = createmask(U, info.infbitpos, 1)
    # info.nanbitmask = createmask(U, info.nanbitpos, 1)
    # println("2: ", info)

    # create constants zero, etc
    UINT = getUINT(U)
    info.zero = reinterpret(U, zero(UINT))
    info.poszero = info.zero | info.ubitmask
    info.posinf = info.emask | info.fmask
    info.mostpos = info.posinf & ~(info.ubitmask << info.utagsize)
    info.leastpos = (info.ubitmask << info.utagsize)
    info.nan = info.posinf | info.ubitmask

    sgn = info.signbitmask
    info.negzero = info.poszero | sgn
    info.neginf = info.posinf | sgn
    info.mostneg = info.mostpos | sgn
    info.leastneg = info.leastpos | sgn
    info.null = info.nan | sgn

    info
  end
end

# ---------------------------------------------------------------------------------------

# # this stores some key sizes and masks for doing float conversions
# type FloatInfo{F<:FloatingPoint, U<:AbstractUnum}
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

# ---------------------------------------------------------------------------------------

const USPEC_FIELDS = ["exp", "frac", "signbit", "ubit"]
const USPEC_LENGTHS = map(length, USPEC_FIELDS)

function Base.show{B,E}(io::IO, u::AbstractUnum{B,E})
  b = bits(u)
  println(io, "bits: ", b)

  nbits = numbits(typeof(u))
  fsize = nbits - E - 2
  flens = [E, fsize, 1, 1]
  maxlens = map(max, flens, USPEC_LENGTHS)

  print(io, "| ")
  pos = 1
  for (i,l) in enumerate(flens)
    lpad, extra = divrem(maxlens[i]-l, 2)
    print(io, " "^lpad, b[pos:pos+l-1], " "^(lpad+extra), " | ")
    pos += l
  end

  print(io, "\n| ")
  pos = 1
  for (i,l) in enumerate(USPEC_LENGTHS)
    lpad, extra = divrem(maxlens[i]-l, 2)
    print(io, " "^lpad, USPEC_FIELDS[i], " "^(lpad+extra), " | ")
    pos += l
  end
end

