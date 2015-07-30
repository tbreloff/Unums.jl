module UnumTests

using Unums
using FactCheck

# # write your own tests here
# @fact 1 --> 1

facts("Basics") do
  u = Unums.FixedUnum64(0)
  @fact_throws -u
  @fact_throws u+u
end


FactCheck.exitstatus()
end # module
