
@generated function Base.zero{U<:AbstractUnum}(::Type{U})
  c = unumConstants(U)
  :($(c.zero))
end

Base.one{U<:AbstractUnum}(::Type{U}) = convert(U, 1)


"exponent of the unum"
@generated function Base.exponent{U<:AbstractUnum}(u::U)
  c = unumConstants(U)
  :(reinterpret($(c.INT), u & $(c.emask)) >> $(c.fpos))
end

"significand (fraction) of an unum"
@generated function Base.significand{U<:AbstractUnum}(u::U)
  c = unumConstants(U)
  :(reinterpret($(c.INT), u & $(c.fmask)) >> $(c.ubitpos))
end

"Number of bits in the unum's exponent"
@generated function esize{U<:AbstractUnum}(u::U)
  c = unumConstants(U)
  :(1 + reinterpret($(c.INT), u & $(c.esizemask)) >> $(c.fsizepos))
end

"Number of bits in the unum's significand (fraction)"
@generated function fsize{U<:AbstractUnum}(u::U)
  c = unumConstants(U)
  :(1 + reinterpret($(c.INT), u & $(c.fsizemask)))
end

@generated function isnegative{U<:AbstractUnum}(u::U)
  c = unumConstants(U)
  :(reinterpret($(c.UINT), u & $(c.signbitmask)) != zero($(c.UINT)))
end

ispositive(u::AbstractUnum) = !isnegative(u)

@generated function isinexact{U<:AbstractUnum}(u::U)
  c = unumConstants(U)
  :(reinterpret($(c.UINT), u & $(c.ubitmask)) != zero($(c.UINT)))
end

isexact(u::AbstractUnum) = !isinexact(u)

@generated function typemin{U<:AbstractUnum}(::Type{U})
  c = unumConstants(U)
  :(c.neginf)
end

@generated function typemax{U<:AbstractUnum}(::Type{U})
  c = unumConstants(U)
  :(c.posinf)
end

@generated function maxubits{U<:AbstractUnum}(::Type{U})
  c = unumConstants(U)
  :(2 + $(c.esizesize) + $(c.fsizesize) + 2^$(c.esizesize) + 2^$(c.fsizesize))
end


# for func in [:isnan, :isnull, :isinf, :isfinite, :isposinf, :isneginf,
#               :isnegative, :iszero, :ispositive, :-, :isinteger, :issubnormal]

# -----------------------------------------------------------------------------

# @generated function +{U<:AbstractUnum}(u1::U, u2::U)

# end

# for op in [:+, :-, :*, :/, :(==), :<, :>, :<=, :>=, :isless, :isequal]


