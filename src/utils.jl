
# this section is pretty important... I create a type with key constants specific to a certain 
# parameter set which defines a Unum.  

numbits{U}(::Type{U}) = sizeof(U) * 8
Base.bits{U<:AbstractUnum}(u::U) = bin(reinterpret(getUINT(U), u), numbits(U))

# helper function to create a bit mask for Unsigned int UINT, where:
#   there are "numones" 1's in the bits starting at "left", and 0's otherwise
function createmask{U<:AbstractUnum}(::Type{U}, left::Int, numones::Int = 1)
  # @assert numones >= 0
  # @assert left >= numones
  # @assert left <= numbits(U)
  
  UINT = getUINT(U)
  # o = one(UINT)
  # x = (left == numbits(UINT) ? typemax(UINT) : (o << left) - o)
  # x -= ((o << (left-numones)) - o)
  x = createmask(UINT, left, numones)
  reinterpret(U, x)
end


function createmask{I<:Integer}(::Type{I}, left::Int, numones::Int = 1)
  @assert numones >= 0
  @assert left >= numones
  @assert left <= numbits(I)
  
  o = one(I)
  x = (left == numbits(I) ? typemax(I) : (o << left) - o)
  x -= ((o << (left-numones)) - o)
  x
end

# ---------------------------------------------------------------------------------------

# TODO: generate these
getUINT{U<:FixedUnum64}(::Type{U})  = UInt64
getINT{U<:FixedUnum64}(::Type{U})   = Int64
(~){U<:FixedUnum64}(u::U)           = box(U, Base.not_int(unbox(U,u)))
(&){U<:FixedUnum64}(u1::U, u2::U)   = box(U, Base.and_int(unbox(U,u1), unbox(U,u2)))
(|){U<:FixedUnum64}(u1::U, u2::U)   = box(U, Base.or_int(unbox(U,u1), unbox(U,u2)))
(<<){U<:FixedUnum64}(u::U, i::Int)  = box(U, Base.shl_int(unbox(U,u), unbox(Int,i)))
# (==){U<:FixedUnum64}(u1::U, u2::U) = box(U, Base.and_int(unbox(U,u1), unbox(U,u2)))

mask64(left, numones=1) = createmask(Unum64, left, numones)

# ---------------------------------------------------------------------------------------

# TODO: generate these
getUINT{U<:FixedUnum16}(::Type{U})  = UInt16
getINT{U<:FixedUnum16}(::Type{U})   = Int16
(~){U<:FixedUnum16}(u::U)           = box(U, Base.not_int(unbox(U,u)))
(&){U<:FixedUnum16}(u1::U, u2::U)   = box(U, Base.and_int(unbox(U,u1), unbox(U,u2)))
(|){U<:FixedUnum16}(u1::U, u2::U)   = box(U, Base.or_int(unbox(U,u1), unbox(U,u2)))
(<<){U<:FixedUnum16}(u::U, i::Int)  = box(U, Base.shl_int(unbox(U,u), unbox(Int,i)))
# (==){U<:FixedUnum16}(u1::U, u2::U) = box(U, Base.and_int(unbox(U,u1), unbox(U,u2)))

mask16(left, numones=1) = createmask(Unum16, left, numones)

# ---------------------------------------------------------------------------------------

@generated function Base.leading_zeros{U<:AbstractUnum}(u::U)
  c = unumConstants(U)
  :(Int(reinterpret($(c.UINT), box(U, Base.ctlz_int(unbox(U,u))))))
end

@generated function Base.trailing_zeros{U<:AbstractUnum}(u::U)
  c = unumConstants(U)
  :(Int(reinterpret($(c.UINT), box(U, Base.cttz_int(unbox(U,u))))))
end

# Base.leading_zeros{U<:FixedUnum16}(u::U) = Int(reinterpret())
        # count_ones(x::$T)     = Int(box($T,ctpop_int(unbox($T,x))))
        # leading_zeros(x::$T)  = Int(box($T,ctlz_int(unbox($T,x))))
        # trailing_zeros(x::$T) = Int(box($T,cttz_int(unbox($T,x))))

# ---------------------------------------------------------------------------------------

# keep a cache for given parameter sets so we don't keep rebuilding the constants
# const unumConstCache = Dict{Tuple{Int,Int,DataType}, Dict{Symbol, Any}}()

type UnumInfo{U<:AbstractUnum}
  base::Int
  nbits::Int
  maxesize::Int
  maxfsize::Int
  esizesize::Int
  fsizesize::Int
  utagsize::Int
  
  signbitpos::Int
  epos::Int
  fpos::Int
  ubitpos::Int
  esizepos::Int
  fsizepos::Int

  signbitmask::U
  emask::U
  fmask::U
  efmask::U
  ubitmask::U
  esizemask::U
  fsizemask::U
  efsizemask::U
  utagmask::U

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

  UINT::DataType
  INT::DataType

  UnumInfo() = new()
end


const NUM_UNUMINFO_INTS = 13
const NUM_UNUMINFO_MASKS = 20

function Base.show{T}(io::IO, info::UnumInfo{T})
  println("UnumInfo{$T}:")
  for fn in fieldnames(info)[1:NUM_UNUMINFO_INTS]
    println(@sprintf("  %15s %6d", fn, getfield(info, fn)))
  end
  for fn in fieldnames(info)[NUM_UNUMINFO_INTS+1:NUM_UNUMINFO_INTS+NUM_UNUMINFO_MASKS]
    println(@sprintf("  %15s %s", fn, bits(getfield(info, fn))))
  end
end



# keep a cache for given parameter sets so we don't keep rebuilding the constants
const unumConstCache = Dict{DataType, UnumInfo}()

# expect this to be called from a generated function, so we're being passed type params
function unumConstants(U::DataType)
  get!(unumConstCache, U) do
    info = UnumInfo{U}()
    B, ESS, FSS = U.parameters
    @assert ESS >= 0
    @assert FSS >= 0
    N = numbits(U)

    info.base = B
    info.nbits = N
    info.UINT = getUINT(U)
    info.INT = getINT(U)

    info.maxesize = 2 ^ ESS
    info.maxfsize = 2 ^ FSS
    info.esizesize = ESS
    info.fsizesize = FSS
    info.utagsize = 1 + ESS + FSS

    info.signbitpos = info.nbits
    info.fpos = info.utagsize + info.maxfsize
    info.epos = info.fpos + info.maxesize
    info.ubitpos = info.utagsize
    info.esizepos = ESS + FSS
    info.fsizepos = FSS

    info.signbitmask = createmask(U, info.signbitpos, 1)
    info.emask = createmask(U, info.epos, info.maxesize)
    info.fmask = createmask(U, info.fpos, info.maxfsize)
    info.efmask = createmask(U, info.epos, info.maxesize + info.maxfsize)
    info.ubitmask = createmask(U, info.ubitpos, 1)
    info.esizemask = createmask(U, info.esizepos, ESS)
    info.fsizemask = createmask(U, info.fsizepos, FSS)
    info.efsizemask = info.esizemask | info.fsizemask
    info.utagmask = info.ubitmask | info.efsizemask

    # create constants zero, etc
    info.zero = reinterpret(U, zero(info.UINT))
    info.poszero = info.zero | info.ubitmask
    info.posinf = info.emask | info.fmask | info.efsizemask
    info.leastpos = (info.ubitmask << 1)
    info.mostpos = info.posinf & ~info.leastpos
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

const USPEC_FIELDS = ["signbit", "exp", "frac", "ubit", "esize-1", "fsize-1"]
const USPEC_LENGTHS = map(length, USPEC_FIELDS)

function Base.show{B,ESS,FSS}(io::IO, u::AbstractUnum{B,ESS,FSS})
  b = bits(u)
  # prinln(io, "value: ", u2float())
  println(io, "bits : ", b)
  println(io, "float: ", float(u), isexact(u) ? "" : "...")

  nbits = numbits(typeof(u))
  maxesize = 2^ESS
  maxfsize = 2^FSS
  unused = nbits - maxesize - maxfsize - ESS - FSS - 2
  flens = [1, maxesize, maxfsize, 1, ESS, FSS]
  maxlens = map(max, flens, USPEC_LENGTHS)

  print(io, "| ")
  pos = 1
  for (i,l) in enumerate(flens)
    lpad, extra = divrem(maxlens[i]-l, 2)
    print(io, " "^lpad, b[pos:pos+l-1], " "^(lpad+extra), " | ")
    pos += (i == 1 ? 1+unused : l)
  end

  print(io, "\n| ")
  pos = 1
  for (i,l) in enumerate(USPEC_LENGTHS)
    lpad, extra = divrem(maxlens[i]-l, 2)
    print(io, " "^lpad, USPEC_FIELDS[i], " "^(lpad+extra), " | ")
    pos += l
  end

  # return

  # print(io, "\n| ")
  # pos = 1
  # vals = [isnegative(u) ? 1 : 0, exponent(u), significand(u), isapprox(u) ? 1 : 0, esize(u), fsize(u)]
  # for (i,l) in enumerate(USPEC_LENGTHS)
  #   lpad, extra = divrem(maxlens[i]-l, 2)
  #   print(io, " "^lpad, vals[i], " "^(lpad+extra), " | ")
  #   pos += l
  # end
  
end


# ---------------------------------------------------------------------------------------
