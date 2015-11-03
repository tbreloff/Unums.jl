

# @generated function Base.zero{U<:AbstractUnum}(::Type{U})
#   c = unumConstants(U)
#   :($(c.zero))
# end

# # convert any floating point number to a unum
# # lets worry about the base-2 case for now, then generalize later:
# @generated function call{E,UINT, FLOAT<:AbstractFloat}(::Type{Unum{E,UINT}}, x::FLOAT)
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

# ----------------------------------------------------------------

type FloatInfo{F<:AbstractFloat, I<:Integer}
  nbits::Int
  esize::Int
  fsize::Int
  emask::I
  fmask::I
  smask::I
  FloatInfo() = new()
end

ispositive(x::AbstractFloat) = x >= 0.
isnegative(x::AbstractFloat) = x < 0.

const _floatinfo = Dict(
    Float16 => (Int16, 5,  10),
    Float32 => (Int32, 8,  23),
    Float64 => (Int64, 11, 52),
  )

# keep a cache for given parameter sets so we don't keep rebuilding the constants
const floatConstCache = Dict{DataType, FloatInfo}()

# expect this to be called from a generated function, so we're being passed type params
function floatConstants(F::DataType)
  get!(floatConstCache, F) do
    I, ES, FS = _floatinfo[F]
    info = FloatInfo{F,I}()
    info.nbits = numbits(F)
    info.esize = ES
    info.fsize = FS
    info.fmask = createmask(I, FS,    FS)
    info.emask = createmask(I, FS+ES, ES)
    info.smask = createmask(I, info.nbits)
    info
  end
end

function Base.show{F,I}(io::IO, info::FloatInfo{F,I})
  println("FloatInfo{$F,$I}:")
  for fn in fieldnames(info)[1:3]
    println(@sprintf("  %8s %6d", fn, getfield(info, fn)))
  end
  for fn in fieldnames(info)[4:end]
    println(@sprintf("  %8s %s", fn, bits(getfield(info, fn))))
  end
end

# ----------------------------------------------------------------

# NOTE: these are not ideal conversions... just want to get a ballpark answer
function Base.float(base, esize, fsize, e, f)
  if e == 0
    return base ^ (e - 2^(esize-1)) * f / (2^fsize)
  else
    return base ^ (e - 2^(esize-1) - 1) * (1 + (base-1) * f / (2^fsize))
  end
end
Base.float{B,ESS,FSS}(u::AbstractUnum{B,ESS,FSS}) = (isnegative(u) ? -1 : 1) * float(Float64(B), esize(u), fsize(u), exponent(u), significand(u))


# ----------------------------------------------------------------

# this is missing?
# Base.issubnormal(x::Float16) = (x != zero(Float16) && reinterpret(UInt16,x) & 0x7c00) == zero(UInt16))
# Base.issubnormal(x::Float16) = (abs(x) < $(box(Float32,unbox(UInt32,0x00800000)))) & (x!=0)
@eval Base.issubnormal(x::Float16) = (abs(x) < $(box(Float16, unbox(UInt16, 0x0400)))) & (x != zero(Float16))

# convert a float to a unum
# credit to @ityonemo... I used his function as reference
@generated function Base.convert{U<:AbstractUnum, F<:AbstractFloat}(::Type{U}, x::F)
  c = unumConstants(U)
  fc = floatConstants(F)

  quote
    # #some checks for special values
    # (isnan(x)) && return nan(Unum{ESS,FSS})
    # (isinf(x)) && return ((x < 0) ? neg_inf(Unum{ESS,FSS}) : pos_inf(Unum{ESS,FSS}))

    # nan, inf or zero
    isnan(x) && return $(c.nan)
    isinf(x) && return x<0.0 ? $(c.neginf) : $(c.posinf)
    x == 0.0 && return $(c.zero)

    # #convert the floating point x to its integer equivalent
    # I = fp.intequiv                 #the integer type of the same width
    # _esize = fp.esize               #how many bits in the exponent
    # _fsize = fp.fsize               #how many bits in the fraction
    # _bits = _esize + _fsize + 1     #how many total bits
    # _ebias = 1 << (_esize - 1) - 1   #exponent bias (= _emax)
    # _emin = -(_ebias) + 1           #minimum exponent

    # exponent bias and minimum
    ebias = 1 << ($(fc.fsize) - 1) - 1
    emin = -ebias + 1

    # ibits = uint64(reinterpret(I, x)[1])

    # get the raw bits
    ibits = reinterpret($(c.INT), x)

    # fraction = ibits & mask(_fsize) << (64 - _fsize)
    # #make some changes to the data for subnormal numbers.
    # (x == 0) && return zero(Unum{ESS,FSS})


    # #grab the sign
    # flags = (ibits & (one(I) << (_esize + _fsize))) != 0 ? UNUM_SIGN_MASK : z16
    u_signmask = x > 0 ? $(c.signbitmask) : $(c.zero)

    # #grab the exponent part
    # biased_exp::Int16 = ibits & mask(_fsize:(_fsize + _esize - 1)) >> _fsize

    # get the float fraction
    x_fraction = ibits & $(fc.fmask)

    # #generate the unbiased exponent and remember to take frac_move into account.
    # unbiased_exp::Int16 = biased_exp - _ebias + ((biased_exp == 0) ? 1 : 0)

    # get the biased and unbiased exponent
    x_exponent_biased = (ibits & $(fc.emask)) >> fc.fsize
    x_exponent_unbiased = x_exponent_biased - ebias + (biased_exp == 0 ? 1 : 0)

    # if issubnormal(x)
    #   #keeping in mind that the fraction bits are now left-aligned, calculate
    #   #how much further we have to push the fraction bits.
    #   frac_move::Int16 = clz(fraction) + 1
    #   fraction = fraction << frac_move
    #   unbiased_exp -= frac_move
    # end

    if issubnormal(x)
      # he shifts the fraction to far left, then counts leading zeros
      # TODO: i think there's a lot of busy work here that's unnecessary... maybe start from scratch...
    end

    # #grab the fraction part

    # #check to see if the exponent is too low.
    # if (unbiased_exp < min_exponent(ESS))
    #   #right shift the fraction by the requisite amount.
    #   shift = min_exponent(ESS) - unbiased_exp
    #   #make sure we don't have any bits in the shifted segment.
    #   #first, are there more bits in the shift than the width?
    #   if (shift > 64)
    #     ((fraction != 0) || ((shift > 65) && (unbiased_exp != 0))) && (flags |= UNUM_UBIT_MASK)
    #   else
    #     ((fraction & mask(shift)) == 0) || (flags |= UNUM_UBIT_MASK)
    #   end
    #   #shift fraction by the amount.
    #   fraction = fraction >> shift
    #   #punch in the one
    #   fraction |= ((biased_exp == 0) ? 0 : t64 >> (shift - 1))
    #   #set to subnormal settings.
    #   esize = uint16((1 << ESS) - 1)
    #   exponent = z64
    # elseif (unbiased_exp > max_exponent(ESS))
    #   return mmr(Unum{ESS,FSS}, flags & UNUM_SIGN_MASK)
    # else
    #   (esize, exponent) = encode_exp(unbiased_exp)
    # end

    # #for really large FSS fractions pad some zeroes in front.
    # (__frac_cells(FSS) > 1) && (fraction = [zeros(Uint64, __frac_cells(FSS) - 1),fraction])

    # r = unum(Unum{ESS,FSS}, min(_fsize, max_fsize(FSS)), esize, flags, fraction, exponent)
    # #check for the "infinity hack" where we "accidentally" create inf.
    # is_inf(r) ? mmr(Unum{ESS,FSS}, flags & UNUM_SIGN_MASK) : r
  end
end

# ----------------------------------------------------------------

# to extract a value:


# # this stores some key sizes and masks for doing float conversions
# type FloatInfo{F<:AbstractFloat, U<:AbstractUnum}
#   nbits::Int
#   epos::Int
#   fpos::Int
#   esize::Int
#   fsize::Int
#   signbitmask::U
#   emask::U
#   fmask::U
#   fType::DataType
#   uType::DataType
# end

# function Base.show{F,U}(io::IO, info::FloatInfo{F,U})
#   println("FloatInfo{$F,$U}:")
#   for fn in fieldnames(info)[1:5]
#     println(@sprintf("  %15s %6d", fn, getfield(info, fn)))
#   end
#   for fn in fieldnames(info)[6:8]
#     println(@sprintf("  %15s %s", fn, bits(getfield(info, fn))))
#   end
# end

# FloatInfo(::Type{Float16}) = FloatInfo(Float16, UInt16, 16, 5)
# FloatInfo(::Type{Float32}) = FloatInfo(Float32, UInt32, 32, 8)
# FloatInfo(::Type{Float64}) = FloatInfo(Float64, UInt64, 64, 11)
# # FloatInfo(::Type{Float128}) = FloatInfo(Float128, UInt128, 128, 15, 113)

# function FloatInfo{F,U}(::Type{F}, ::Type{U}, nbits::Int, esize::Int)
#   fsize = nbits - esize - 1
#   FloatInfo{F,U}(nbits,
#                     nbits-1,
#                     fsize,
#                     esize,
#                     fsize,
#                     createmask(U, nbits, 1),
#                     createmask(U, nbits-1, esize),
#                     createmask(U, fsize, fsize),
#                     F,
#                     U)
# end
