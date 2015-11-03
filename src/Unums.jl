module Unums

export
  AbstractUnum,

  FixedUnum64,
  BinaryUnum64,
  Unum64,
  mask64,

  FixedUnum16,
  BinaryUnum16,
  Unum16,
  mask16,

  isexact,
  isinexact,
  
  createmask


import Base: isequal, isfinite, isinf, isinteger,
             isless, isnan, isnull, isnumber, isreal, issubnormal,
             typemin, typemax, box, unbox

import Base: +, -, *, /, ==, <, >, <=, >=, !, &, |, <<, ~

# ---------------------------------------------------------------------------------------

include("types.jl")
include("utils.jl")
include("ops.jl")
include("convert/float.jl")
# include("convert/int.jl")

# ---------------------------------------------------------------------------------------



end # module
