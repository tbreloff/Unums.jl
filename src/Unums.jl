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

doc"""
This is the basic representation of an unum (universal number) as described in detail in
John L Gustafson's book 'The End of Error: Unum Computing':

| signbit | exponent | fraction | ubit | exponent size - 1 | fraction size - 1 |

The first 3 fields are similar to floating point representation, but with flexible sizes.

The ubit (uncertainty bit) signifies whether the number is an exact or uncertain:

  0 --> Exact
  1 --> Number u falls in the OPEN interval (u, u + ULP), where ULP is the distance to the next
        representable number.

Unums can be expanded to fit into fixed widths, and can be supplemented with summary info, such as
bit flags indicating NaN, Inf, negativity, etc which can help speed many operations.  I'll probably 
attempt a FixedUnum type that fills 32/64/128 bits.
"""
immutable Unum{E, F, UINT <: Unsigned} <: AbstractUnum
  bits::UINT
end


type UnumConstants{E, F, UINT <: Unsigned}
  esizesize::UInt8  # E = size of "exponent size" field (NOT exponent size)
  fsizesize::UInt8  # F = size of "fraction size" field (NOT fraction size)
  esizemax::UInt16  # 2^esizesize
  fsizemax::UInt16  # 2^fsizesize
  tagsize::UInt16  # 1 + E + F
  maxbits::UInt16   # 1 + esizemax + fsizemax + utagsize

  ubitmask::UINT    # 1 << (utagsize - 1)
  fsizemask::UINT   # (1 << F) - 1
  efsizemask::UINT  # ubitmask - 1
  esizemask::UINT   # efsizemask - fsizemask
  tagmask::UINT     # ubitmask | efsizemask

  # TODO: more constants
end




# TODO: impl


# ---------------------------------------------------------------------------------------

abstract AbstractFixedUnum <: AbstractUnum

doc"""
A fixed-width unum.  Parameters:
  EBASE = base of exponent
      NOTE: may ditch this param:
            - defaults to 2?
            - want to easily implement decimals... but this may be tough to implement well
  ESZ = number of bits in the exponent field
  BITS = total number of bits in the format
  UINT = the underlying storage type
"""
immutable FixedUnum{EBASE, ESZ, BITS, UINT} <: AbstractFixedUnum
  bits::UINT
end



# TODO: impl


# ---------------------------------------------------------------------------------------

# some helpful aliases

typealias FixedUnum16 FixedUnum{2, 3, 16, UInt16}
typealias FixedUnum32 FixedUnum{2, 7, 32, UInt32}
typealias FixedUnum64 FixedUnum{2, 16, 64, UInt64}
typealias FixedUnum128 FixedUnum{2, 20, 128, UInt128}

typealias DecimalUnum16 FixedUnum{10, 3, 16, UInt16}
typealias DecimalUnum32 FixedUnum{10, 7, 32, UInt32}
typealias DecimalUnum64 FixedUnum{10, 16, 64, UInt64}
typealias DecimalUnum128 FixedUnum{10, 20, 128, UInt128}

# ---------------------------------------------------------------------------------------

end # module
