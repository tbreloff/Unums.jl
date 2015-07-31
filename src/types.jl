
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
immutable FixedUnum{EBASE, ESZ, UINT <: Unsigned} <: AbstractUnum
  data::UINT
end


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
