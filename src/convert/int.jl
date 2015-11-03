

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

# convert an unsigned integer to a unum
@generated function Base.convert{U<:AbstractUnum, I<:Unsigned}(::Type{U}, i::I)
  c = unumConstants(U)
  n = sizeof(i) * 8
  println(c)

  quote
    i == 0 && return $(c.zero)

    usedbits = $(n) - leading_zeros(i)

    # a
    $(c.esizesize == 0 ? :(if i == 1; return ??; end) : :())


    # if usedbits <= $(c.fsize)
    #   # y = ((i % ))
    # end
  end
end


