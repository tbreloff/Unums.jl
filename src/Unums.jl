module Unums

export
  AbstractUnum,
  Unum,
  DecimalUnum,
  Unum16,
  Unum32,
  Unum64,
  Unum128,
  DecimalUnum16,
  DecimalUnum32,
  DecimalUnum64,
  DecimalUnum128


import Base: isapprox, isequal, isfinite, isinf, isinteger,
             isless, isnan, isnull, isnumber, isreal, issubnormal,
             typemin, typemax

# ---------------------------------------------------------------------------------------

include("types.jl")
include("utils.jl")

# ---------------------------------------------------------------------------------------



end # module
