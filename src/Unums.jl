module Unums

export
  AbstractUnum,
  FixedUnum64,
  BinaryUnum64,
  Unum64,
  mask64


import Base: isapprox, isequal, isfinite, isinf, isinteger,
             isless, isnan, isnull, isnumber, isreal, issubnormal,
             typemin, typemax

# ---------------------------------------------------------------------------------------

include("types.jl")
include("utils.jl")
include("convert.jl")

# ---------------------------------------------------------------------------------------



end # module
