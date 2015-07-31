
@generated function Base.zero{B,E,U}(::Type{FixedUnum{B,E,U}})
  c = unumConstants(B,E,U)
  :($(c.zero))
end

@generated function Base.convert{ESZ,UINT, FLOAT<:FloatingPoint}(::Type{Unum{ESZ,UINT}}, x::FLOAT)
  c = unumConstants(2, ESZ, UINT)
  f = FloatInfo(FLOAT)

  # this is the actual conversion function:
  quote
    println($(f.uintType))

    ival = reinterpret($(f.uintType), x)
    exponent = (ival & $(f.emask)) >> $(f.fpos)
    fraction = (ival & $(f.fmask))
    sign = ival >> $(f.nbits-1)

    if exponent == 0
      if fraction == 0
        # zero (exact)

      end
    end

    for x in (ival, exponent, fraction, sign)
      println(bits(x))
    end
  end
end
