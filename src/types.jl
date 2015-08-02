
# define the interface that unums should follow:

abstract AbstractUnum{B,E} <: Real

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

# B is the base of the exponent, E is the number of bits in the exponent
bitstype 64 FixedUnum64{B,E} <: AbstractUnum{B,E}
typealias BinaryUnum64{E}   FixedUnum64{2, E}
typealias DecimalUnum64{E}  FixedUnum64{10, E}
typealias IntUnum64         FixedUnum64{2,1}
typealias Unum64            BinaryUnum64{15}

# # WIP!! trying to replace the UINT with a distinct bitstype...
# immutable FixedUnum{B, E, U <: UData} <: AbstractUnum
#   data::U
# end

# FixedUnum{B,E,U}(B::Int, E::Int, data::U) = FixedUnum{B,E,U}(d)

# @generated function _u2i{B,E,U}(u::FixedUnum{B,E,U})
#   c = unumConstants(B,E,U)
#   :(reinterpret($(c.uintType), u.data))
# end

# _i2u{UINT<:Unsigned}(B::Int, E::Int, i::UINT) = FixedUnum(UData{B,E,UINT}(i))

# note: see convert.jl for constructors


# ---------------------------------------------------------------------------------------

# some helpful aliases


# typealias Unum{E, U} FixedUnum{2, E, U}
# typealias DecimalUnum{E, U} FixedUnum{10, E, U}

# typealias Unum16 Unum{3, UData16}
# typealias Unum32 Unum{7, UData32}
# typealias Unum64 Unum{16, UData64}
# typealias Unum128 Unum{20, UData128}

# typealias DecimalUnum16 DecimalUnum{3, UData16}
# typealias DecimalUnum32 DecimalUnum{7, UData32}
# typealias DecimalUnum64 DecimalUnum{16, UData64}
# typealias DecimalUnum128 DecimalUnum{20, UData128}

# TODO: a very cool property when E==1: the unums track the exact set of integers,
#       plus the open ranges, infs, and nans.  They are a nice superset of signed
#       integers, and could allow for straightforward conversion between IntUnum/Integer
# typealias IntUnum16 Unum16{1}
