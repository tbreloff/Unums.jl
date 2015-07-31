module Unums

import Base: isapprox, isequal, isfinite, isinf, isinteger,
             isless, isnan, isnull, isnumber, isreal, issubnormal,
             typemin, typemax

# ---------------------------------------------------------------------------------------

# define the interface that unums should follow:

abstract AbstractUnum <: Real

isnumber(u::AbstractUnum) = true
isreal(u::AbstractUnum) = true


# NOTE: the definitions below aren't strictly necessary, but I'll keep them here for now so that there's a clear reference
#       of the functions I should implement vs other functions that should just fail.
#       A better solution is likely to use traits... I may switch to that eventually...

for func in [:typemin, :typemax]
  @eval $func{T<:AbstractUnum}(::Type{T}) = error("Not implemented for type $T")
end

for func in [:isapprox, :isnan, :isnull, :isinf, :isfinite, :isposinf, :isneginf,
              :isnegative, :iszero, :ispositive, :-, :isinteger, :issubnormal]
  @eval $func(u::AbstractUnum) = error("Not implemented for $u\!")
end


for op in [:+, :-, :*, :/, :(==), :<, :>, :<=, :>=, :isless, :isequal]
  @eval $op(u1::AbstractUnum, u2::AbstractUnum) = error("Operation not implemented for $u1 and $u2\!")
  for t in [:Bool, :Integer, :FloatingPoint]
    @eval $op(u::AbstractUnum, r::$t) = error("Operation not implemented for Unum $u and ", $t, " $r\!")
    @eval $op(r::$t, u::AbstractUnum) = error("Operation not implemented for ", $t, " $r and Unum $u\!")
  end
end




# ---------------------------------------------------------------------------------------

abstract AbstractFixedUnum <: AbstractUnum

doc"""
This is the basic representation of an unum (universal number) as described in detail in
John L Gustafson's book 'The End of Error: Unum Computing':

| signbit | exponent | fraction | ubit | exponent size - 1 | fraction size - 1 |

The first 3 fields are similar to floating point representation, but with flexible sizes.

The ubit (uncertainty bit) signifies whether the number is an exact or uncertain:

  0 --> Exact
  1 --> Number u falls in the OPEN interval (u, u + ULP), where ULP is the distance to the next
        representable number.

Our implementation is a fixed-width unum.  Parameters:
  EBASE = base of exponent
      NOTE: may ditch this param:
            - defaults to 2?
            - want to easily implement decimals... but this may be tough to implement well
  ESZ = number of bits in the exponent field (fraction field fills all available space)
  UINT = the underlying storage type

The format is as follows:

| exponent | fraction | NaN? | Inf? | zero? | ubound? | negative? | signbit | ubit |

Note that all the fields with a question mark are summary fields only (i.e. you can calculate those
  fields with just exponent, fraction, signbit, and ubit)

Defs:
  exponent        = same as in floats
  fraction        = same as in floats
  NaN?            = boolean value, 1 when NaN
  Inf?            = boolean value, 1 when +/-Inf
  zero?           = boolean value, 1 when +/-0 AND it's exact
  ubound?         = boolean value, 1 when this is the first unum in a ubound pair
  negative?       = boolean value, 1 when value is: !isnan && signbit && (ubit || !iszero))
  signbit         = boolean value, 0 for positive, 1 for negative
  ubit            = boolean value, 0 for exact, 1 for inexact
"""
immutable FixedUnum{EBASE, ESZ, UINT <: Unsigned} <: AbstractFixedUnum
  data::UINT
end



# ---------------------------------------------------------------------------------------

const UTAG_MASK_SYMS = [:ubitmask, :signbitmask, :negbitmask, :uboundbitmask, :zerobitmask, :infbitmask, :nanbitmask]
const UTAG_POS_SYMS = [:ubitpos, :signbitpos, :negbitpos, :uboundbitpos, :zerobitpos, :infbitpos, :nanbitpos]

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

# keep a cache for given parameter sets so we don't keep rebuilding the constants
const constsCache = Dict{Tuple{Int,Int,DataType}, Dict{Symbol, Any}}()
function getConstants(args...)
  get!(constsCache, args) do
    buildConstants(args...)
  end
end

# expect this to be called from a generated function, so we're being passed type params
function buildConstants(EBASE::Int, ESZ::Int, UINT::DataType)
  d = Dict{Symbol, Any}()

  # first some basic calcs
  d[:nbits] = numbits(UINT)
  d[:utagsize] = 7
  d[:esize] = ESZ
  d[:fsize] = d[:nbits] - d[:utagsize] - ESZ
  @assert d[:fsize] > 0

  # leftmost positions
  d[:epos] = d[:nbits]
  d[:fpos] = d[:nbits] - d[:esize]
  for (i,s) in enumerate(UTAG_POS_SYMS)
    d[s] = i
  end

  # masks
  d[:emask] = createmask(UINT, d[:epos], d[:esize])
  d[:fmask] = createmask(UINT, d[:fpos], d[:fsize])
  for (i, s) in enumerate(UTAG_MASK_SYMS)
    d[s] = createmask(UINT, d[UTAG_POS_SYMS[i]], 1)
  end

  d
end

# ---------------------------------------------------------------------------------------


@generated function Base.show{EBASE,ESZ,UINT}(io::IO, u::FixedUnum{EBASE,ESZ,UINT})
  d = getConstants(EBASE, ESZ, UINT)

  efsz = ESZ + d[:fsize]
  layout = [("exp", 1 : ESZ),
            ("frac", (1 : d[:fsize]) + ESZ),
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

# TODO: impl


# ---------------------------------------------------------------------------------------

# some helpful aliases
typealias Unum{ESZ, UINT} FixedUnum{2, ESZ, UINT}
typealias DecimalUnum{ESZ, UINT} FixedUnum{10, ESZ, UINT}

typealias Unum16 Unum{3, UInt16}
typealias Unum32 Unum{7, UInt32}
typealias Unum64 Unum{16, UInt64}
typealias Unum128 Unum{20, UInt128}

typealias DecimalUnum16 DecimalUnum{3, UInt16}
typealias DecimalUnum32 DecimalUnum{7, UInt32}
typealias DecimalUnum64 DecimalUnum{16, UInt64}
typealias DecimalUnum128 DecimalUnum{20, UInt128}

# ---------------------------------------------------------------------------------------

end # module
