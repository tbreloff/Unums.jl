
# this section is pretty important... I create a type with key constants specific to a certain 
# parameter set which defines a Unum.  

numbits{T}(::Type{T}) = sizeof(T) * 8

# helper function to create a bit mask for Unsigned int UINT, where:
#   there are "numones" 1's in the bits starting at "left", and 0's otherwise
function createmask{UINT<:Unsigned}(::Type{UINT}, left::Int, numones::Int)
  @assert numones >= 0
  @assert left >= numones
  @assert left <= numbits(UINT)
  
  o = one(UINT)
  x = (left == numbits(UINT) ? typemax(UINT) : (o << left) - o)
  x -= ((o << (left-numones)) - o)
  x
end

# ---------------------------------------------------------------------------------------

# keep a cache for given parameter sets so we don't keep rebuilding the constants
# const unumConstCache = Dict{Tuple{Int,Int,DataType}, Dict{Symbol, Any}}()

type UnumInfo{UINT<:Unsigned}
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

  emask::UINT
  fmask::UINT
  ubitmask::UINT
  signbitmask::UINT
  # negbitmask::UINT
  # uboundbitmask::UINT
  # zerobitmask::UINT
  # infbitmask::UINT
  # nanbitmask::UINT

  zero::UINT      # exact zero
  poszero::UINT   # inexact positive zero
  negzero::UINT   # inexact negative zero
  posinf::UINT    # exact positive inf
  neginf::UINT    # exact negative inf
  mostpos::UINT   # exact maximum positive real
  leastpos::UINT  # exact minimum positive real
  mostneg::UINT   # exact minimum negative real
  leastneg::UINT  # exact maximum negative real
  nan::UINT       # this is "quiet NaN" from the book
  null::UINT      # this is "signaling NaN" from the book... can maybe repurpose to replace Nullable
end


const NUM_UNUMINFO_INTS = 9
const NUM_UNUMINFO_MASKS = 15

function Base.show{T}(io::IO, info::UnumInfo{T})
  println("UnumInfo{$T}:")
  for fn in fieldnames(info)[1:numints]
    println(@sprintf("  %15s %6d", fn, getfield(info, fn)))
  end
  for fn in fieldnames(info)[numints:end]
    println(@sprintf("  %15s %s", fn, bits(getfield(info, fn))))
  end
end

UnumInfo{T}(::Type{T}) = UnumInfo{T}(zeros(Int, NUM_UNUMINFO_INTS)..., zeros(T, NUM_UNUMINFO_MASKS)...)


# keep a cache for given parameter sets so we don't keep rebuilding the constants
const unumConstCache = Dict{Tuple{Int,Int,DataType}, UnumInfo}()

# expect this to be called from a generated function, so we're being passed type params
function unumConstants(B::Int, E::Int, UINT::DataType)
  get!(unumConstCache, (B, E, UINT)) do
    info = UnumInfo(UINT)
    info.base = B
    info.nbits = numbits(UINT)
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

    info.emask = createmask(UINT, info.epos, info.esize)
    info.fmask = createmask(UINT, info.fpos, info.fsize)
    info.ubitmask = createmask(UINT, info.ubitpos, 1)
    info.signbitmask = createmask(UINT, info.signbitpos, 1)
    # info.negbitmask = createmask(UINT, info.negbitpos, 1)
    # info.uboundbitmask = createmask(UINT, info.uboundbitpos, 1)
    # info.zerobitmask = createmask(UINT, info.zerobitpos, 1)
    # info.infbitmask = createmask(UINT, info.infbitpos, 1)
    # info.nanbitmask = createmask(UINT, info.nanbitpos, 1)

    # create constants zero, etc
    info.zero = zero(UINT)
    info.poszero = info.zero | info.ubitmask
    info.posinf = info.emask | info.fmask
    info.mostpos = info.posinf - (info.ubitmask << info.utagsize)
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

# this stores some key sizes and masks for doing float conversions
type FloatInfo{F<:FloatingPoint, UINT<:Unsigned}
  nbits::Int
  epos::Int
  fpos::Int
  esize::Int
  fsize::Int
  signbitmask::UINT
  emask::UINT
  fmask::UINT
  floatType::DataType
  uintType::DataType
end

function Base.show{F,U}(io::IO, info::FloatInfo{F,U})
  println("FloatInfo{$F,$U}:")
  for fn in fieldnames(info)[1:5]
    println(@sprintf("  %15s %6d", fn, getfield(info, fn)))
  end
  for fn in fieldnames(info)[6:8]
    println(@sprintf("  %15s %s", fn, bits(getfield(info, fn))))
  end
end

FloatInfo(::Type{Float16}) = FloatInfo(Float16, UInt16, 16, 5)
FloatInfo(::Type{Float32}) = FloatInfo(Float32, UInt32, 32, 8)
FloatInfo(::Type{Float64}) = FloatInfo(Float64, UInt64, 64, 11)
# FloatInfo(::Type{Float128}) = FloatInfo(Float128, UInt128, 128, 15, 113)

function FloatInfo{F,UINT}(::Type{F}, ::Type{UINT}, nbits::Int, esize::Int)
  fsize = nbits - esize - 1
  FloatInfo{F,UINT}(nbits,
                    nbits-1,
                    fsize,
                    esize,
                    fsize,
                    createmask(UINT, nbits, 1),
                    createmask(UINT, nbits-1, esize),
                    createmask(UINT, fsize, fsize),
                    F,
                    UINT)
end

# ---------------------------------------------------------------------------------------


# this is the intended method of creating functions... get the constants from the parameters, 
# then build a specialized (generated) function for this combination
@generated function Base.show{B,E,UINT}(io::IO, u::FixedUnum{B,E,UINT})
  c = unumConstants(B, E, UINT)

  efsz = E + c.fsize
  layout = [("exp", 1 : E),
            ("frac", (1 : c.fsize) + E),
            # ("NaN?", efsz + 1),
            # ("Inf?", efsz + 2),
            # ("zero?", efsz + 3),
            # ("ubound?", efsz + 4),
            # ("neg?", efsz + 5),
            ("signbit", efsz + 1),
            ("ubit", efsz + 2)]
  info = [begin
            l1, l2 = map(length, x)
            maxlen = max(l1, l2)
            (maxlen-l1, maxlen-l2)
          end for (i,x) in enumerate(layout)]

  quote
    bs = bits(u.data)
    layout = $layout
    info = $info

    j = 2
    print(io, "| ")
    for i in 1:length(layout)
      lpad, extra = divrem(info[i][j], 2)
      print(io, " "^lpad, bs[layout[i][j]], " "^(lpad+extra), " | ")
    end

    j = 1
    print(io, "\n| ")
    for i in 1:length(layout)
      lpad, extra = divrem(info[i][j], 2)
      print(io, " "^lpad, layout[i][j], " "^(lpad+extra), " | ")
    end
  end
end
