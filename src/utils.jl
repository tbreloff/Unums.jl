
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
  negbitpos::Int
  uboundbitpos::Int
  zerobitpos::Int
  infbitpos::Int
  nanbitpos::Int

  emask::UINT
  fmask::UINT
  ubitmask::UINT
  signbitmask::UINT
  negbitmask::UINT
  uboundbitmask::UINT
  zerobitmask::UINT
  infbitmask::UINT
  nanbitmask::UINT

  # UnumInfo{T}(::Type{T}) = new()
end

function Base.show{T}(io::IO, info::UnumInfo{T})
  println("UnumInfo{$T}:")
  for fn in fieldnames(info)[1:14]
    println(@sprintf("  %15s %6d", fn, getfield(info, fn)))
  end
  for fn in fieldnames(info)[15:end]
    println(@sprintf("  %15s %s", fn, bits(getfield(info, fn))))
  end
end

UnumInfo{T}(::Type{T}) = UnumInfo{T}(zeros(Int, 14)..., zeros(T, 9)...)


# keep a cache for given parameter sets so we don't keep rebuilding the constants
const unumConstCache = Dict{Tuple{Int,Int,DataType}, UnumInfo}()

# expect this to be called from a generated function, so we're being passed type params
function unumConstants(EBASE::Int, ESZ::Int, UINT::DataType)
  get!(unumConstCache, (EBASE, ESZ, UINT)) do
    info = UnumInfo(UINT)
    info.base = EBASE
    info.nbits = numbits(UINT)
    info.esize = ESZ
    info.utagsize = 7
    info.fsize = info.nbits - info.utagsize - info.esize
    @assert info.fsize > 0

    info.epos = info.nbits
    info.fpos = info.nbits - info.esize
    info.ubitpos = 1
    info.signbitpos = 2
    info.negbitpos = 3
    info.uboundbitpos = 4
    info.zerobitpos = 5
    info.infbitpos = 6
    info.nanbitpos = 7

    info.emask = createmask(UINT, info.epos, info.esize)
    info.fmask = createmask(UINT, info.fpos, info.fsize)
    info.ubitmask = createmask(UINT, info.ubitpos, 1)
    info.signbitmask = createmask(UINT, info.signbitpos, 1)
    info.negbitmask = createmask(UINT, info.negbitpos, 1)
    info.uboundbitmask = createmask(UINT, info.uboundbitpos, 1)
    info.zerobitmask = createmask(UINT, info.zerobitpos, 1)
    info.infbitmask = createmask(UINT, info.infbitpos, 1)
    info.nanbitmask = createmask(UINT, info.nanbitpos, 1)

    info
  end
end

# ---------------------------------------------------------------------------------------

# this stores some key sizes and masks for doing float conversions
type FloatInfo{F<:FloatingPoint, UINT<:Unsigned}
  nbits::Int
  esize::Int
  fsize::Int
  emask::UINT
  fmask::UINT
end

FloatInfo(::Type{Float16}) = FloatInfo{Float16, UInt16}(Float16, UInt16, 16, 5, 11)
FloatInfo(::Type{Float32}) = FloatInfo{Float32, UInt32}(Float32, UInt32, 32, 8, 24)
FloatInfo(::Type{Float64}) = FloatInfo{Float64, UInt64}(Float64, UInt64, 64, 11, 53)
# FloatInfo(::Type{Float128}) = FloatInfo{Float128, UInt128}(Float128, UInt128, 128, 15, 113)

function FloatInfo{F,UINT}(::Type{F}, ::Type{UINT}, nbits::Int, esize::Int, fsize::Int)
  FloatInfo{F,UINT}(nbits, esize, fsize,
                    createmask(UINT, nbits-1, esize),
                    createmask(UINT, fsize, fsize))
end

# ---------------------------------------------------------------------------------------


# this is the intended method of creating functions... get the constants from the parameters, 
# then build a specialized (generated) function for this combination
@generated function Base.show{EBASE,ESZ,UINT}(io::IO, u::FixedUnum{EBASE,ESZ,UINT})
  c = unumConstants(EBASE, ESZ, UINT)

  efsz = ESZ + c.fsize
  layout = [("exp", 1 : ESZ),
            ("frac", (1 : c.fsize) + ESZ),
            ("NaN?", ESZ + 1),
            ("Inf?", ESZ + 2),
            ("zero?", ESZ + 3),
            ("ubound?", ESZ + 4),
            ("neg?", ESZ + 5),
            ("signbit", ESZ + 6),
            ("ubit", ESZ + 7)]
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
