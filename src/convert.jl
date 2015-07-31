


@generated function convert{ESZ,UINT, FLOAT<:FloatingPoint}(::Type{Unum{ESZ,UINT}}, x::FLOAT)
  c = unumConstants(2, ESZ, UINT)
  f = FloatInfo(FLOAT)

  # this is the actual conversion function:
  quote
    # first convert exponent
    ival = reinterpret(UINT, x)
  end
end
