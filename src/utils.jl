
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


# this is the intended method of creating functions... get the constants from the parameters, 
# then build a specialized (generated) function for this combination
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
