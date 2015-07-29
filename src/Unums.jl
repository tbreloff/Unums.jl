module Unums


abstract AbstractUnum <: Real

doc"""
This is the basic representation of an unum (universal number) as described in detail in
John L Gustafson's book 'The End of Error: Unum Computing':
| signbit | exponent | fraction | ubit | exponent size - 1 | fraction size - 1 |

The first 3 fields are similar to floating point representation, but with flexible sizes.

The ubit (uncertainty bit) signifies whether the number is an exact or uncertain:
  0 --> Exact
  1 --> Number u falls in the OPEN interval (u, u + ULP), where ULP is the distance to the next
        representable number.

Unums can be expanded to fit into fixed widths, and can be supplemented with summary info, such as
bit flags indicating NaN, Inf, negativity, etc which can help speed many operations.  I'll probably 
attempt a FixedUnum type that fills 32/64/128 bits.
"""
type Unum{E,F,UINT} <: AbstractUnum
  bits::UINT
end


end # module
