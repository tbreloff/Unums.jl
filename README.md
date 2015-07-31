# Unums

[![Build Status](https://travis-ci.org/tbreloff/Unums.jl.svg?branch=master)](https://travis-ci.org/tbreloff/Unums.jl)

### Experimental! Use at your own risk!

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


## Current implementation

I'm attempting to implement a fixed-width unum (`FixedUnum`).  Parameters:
- EBASE = base of exponent
      NOTE: may ditch this param:
            - defaults to 2?
            - want to easily implement decimals... but this may be tough to implement well
- ESZ = number of bits in the exponent field (fraction field fills all available space)
- UINT = the underlying storage type, which should be an unsigned integer.

The format is as follows:

`| exponent | fraction | NaN? | Inf? | zero? | ubound? | negative? | signbit | ubit |`

Note that all the fields with a question mark are summary fields only (i.e. you can calculate those fields with just exponent, fraction, signbit, and ubit).
 They may not have any value in a software implementation as comparing bit-by-bit doesn't save very much, but it's worth a try.

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

There are also (currently) some aliases, which will likely be used more than a direct call to FixedUnum:

```
# base-2 unums... very similar to floats
typealias Unum{ESZ, UINT} FixedUnum{2, ESZ, UINT}
typealias Unum16 Unum{3, UInt16}
typealias Unum32 Unum{7, UInt32}
typealias Unum64 Unum{16, UInt64}
typealias Unum128 Unum{20, UInt128}

# base-10 unums... very similar to decimal floats
typealias DecimalUnum{ESZ, UINT} FixedUnum{10, ESZ, UINT}
typealias DecimalUnum16 DecimalUnum{3, UInt16}
typealias DecimalUnum32 DecimalUnum{7, UInt32}
typealias DecimalUnum64 DecimalUnum{16, UInt64}
typealias DecimalUnum128 DecimalUnum{20, UInt128}
```

Calling `show` will give you a structured bits layout:
```
julia> u
| 0000000000000000 | 00000000000000000000000000000000000000111 |  0   |  0   |   0   |    0    |  0   |    0    |  0   | 
|       exp        |                   frac                    | NaN? | Inf? | zero? | ubound? | neg? | signbit | ubit | 
```

Many functions will be staged using the `@generated` macro and cached constants specific to a given set of Unum parameters:
```
julia> info = first(Unums.unumConstCache)[2]
UnumInfo{UInt64}:
             base      2
            nbits     64
            esize     16
            fsize     41
         utagsize      7
             epos     64
             fpos     48
          ubitpos      1
       signbitpos      2
        negbitpos      3
     uboundbitpos      4
       zerobitpos      5
        infbitpos      6
        nanbitpos      7
            emask 1111111111111111000000000000000000000000000000000000000000000000
            fmask 0000000000000000111111111111111111111111111111111111111110000000
         ubitmask 0000000000000000000000000000000000000000000000000000000000000001
      signbitmask 0000000000000000000000000000000000000000000000000000000000000010
       negbitmask 0000000000000000000000000000000000000000000000000000000000000100
    uboundbitmask 0000000000000000000000000000000000000000000000000000000000001000
      zerobitmask 0000000000000000000000000000000000000000000000000000000000010000
       infbitmask 0000000000000000000000000000000000000000000000000000000000100000
       nanbitmask 0000000000000000000000000000000000000000000000000000000001000000
```

My thinking is that, by putting the specification into these cache objects and using staged functions, we can allow for
total flexibility in the specifics of how a unum is represented, while at the same time providing extremely optimized
methods for creating and operating on them.
