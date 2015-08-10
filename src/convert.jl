

# @generated function Base.zero{U<:AbstractUnum}(::Type{U})
#   c = unumConstants(U)
#   :($(c.zero))
# end

# # convert any floating point number to a unum
# # lets worry about the base-2 case for now, then generalize later:
# @generated function call{E,UINT, FLOAT<:FloatingPoint}(::Type{Unum{E,UINT}}, x::FLOAT)
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




# function convert(::Type{Float64}, x::UInt128)
#     x == 0 && return 0.0
#     n = 128-leading_zeros(x) # ndigits0z(x,2)
#     if n <= 53
#         y = ((x % UInt64) << (53-n)) & 0x000f_ffff_ffff_ffff
#     else
#         y = ((x >> (n-54)) % UInt64) & 0x001f_ffff_ffff_ffff # keep 1 extra bit
#         y = (y+1)>>1 # round, ties up (extra leading bit in case of next exponent)
#         y &= ~UInt64(trailing_zeros(x) == (n-54)) # fix last bit to round to even
#     end
#     d = ((n+1022) % UInt64) << 52
#     reinterpret(Float64, d + y)
# end

# function convert(::Type{Float64}, x::Int128)
#     x == 0 && return 0.0
#     s = ((x >>> 64) % UInt64) & 0x8000_0000_0000_0000 # sign bit
#     x = abs(x) % UInt128
#     n = 128-leading_zeros(x) # ndigits0z(x,2)
#     if n <= 53
#         y = ((x % UInt64) << (53-n)) & 0x000f_ffff_ffff_ffff
#     else
#         y = ((x >> (n-54)) % UInt64) & 0x001f_ffff_ffff_ffff # keep 1 extra bit
#         y = (y+1)>>1 # round, ties up (extra leading bit in case of next exponent)
#         y &= ~UInt64(trailing_zeros(x) == (n-54)) # fix last bit to round to even
#     end
#     d = ((n+1022) % UInt64) << 52
#     reinterpret(Float64, s | d + y)
# end

@generated function Base.convert{U<:AbstractUnum, I<:Unsigned}(::Type{U}, i::I)
  c = unumConstants(U)
  n = sizeof(i) * 8
  println(c)

  quote
    usedbits = $(n) - leading_zeros(i)
    usedbits == 0 && return $(c.zero)
    if usedbits <= $(c.fsize)
      y = ((i %))
  end
end

# NOTE: these are not ideal conversions... just want to get a ballpark answer
u2float{B,ESS,FSS}(u::AbstractUnum{B,ESS,FSS}) = u2float(Float64(B), ESS, FSS, exponent(u), significand(u))

function u2float(base, esize, fsize, e, f)
  if e == 0
    return base ^ (e - 2^(esize-1)) * f / (2^fsize)
  else
    return base ^ (e - 2^(esize-1) - 1) * (1 + (base-1) * f / (2^fsize))
  end
end
