# Unums

[![Build Status](https://travis-ci.org/tbreloff/Unums.jl.svg?branch=master)](https://travis-ci.org/tbreloff/Unums.jl)


This is the basic representation of an unum (universal number) as described in detail in
John L Gustafson's book 'The End of Error: Unum Computing':

`| signbit | exponent | fraction | ubit | exponent size - 1 | fraction size - 1 |`

The first 3 fields are similar to floating point representation, but with flexible sizes.

The `ubit` (uncertainty bit) signifies whether the number is an exact or uncertain:

  0 --> Exact  
  1 --> Number u falls in the OPEN interval (u, u + ULP), where ULP is the distance to the next
        representable number.

Unums can be expanded to fit into fixed widths, and can be supplemented with summary info, such as
bit flags indicating NaN, Inf, negativity, etc which can help speed many operations.  I'll probably 
attempt a FixedUnum type that fills 32/64/128 bits.


Our implementation is a fixed-width unum.  Parameters:
- EBASE = base of exponent
      NOTE: may ditch this param:
            - defaults to 2?
            - want to easily implement decimals... but this may be tough to implement well
- ESZ = number of bits in the exponent field (fraction field fills all available space)
- UINT = the underlying storage type

The format is as follows:

`| exponent | fraction | NaN? | Inf? | zero? | ubound? | negative? | signbit | ubit |`

Note that all the fields with a question mark are summary fields only (i.e. you can calculate those fields with just exponent, fraction, signbit, and ubit)

Defs:
```
  exponent        = same as in floats
  fraction        = same as in floats
  NaN?            = boolean value, 1 when NaN
  Inf?            = boolean value, 1 when +/-Inf
  zero?           = boolean value, 1 when +/-0 AND it's exact
  ubound?         = boolean value, 1 when this is the first unum in a ubound pair
  negative?       = boolean value, 1 when value is: !isnan && signbit && (ubit || !iszero))
  signbit         = boolean value, 0 for positive, 1 for negative
  ubit            = boolean value, 0 for exact, 1 for inexact
```
