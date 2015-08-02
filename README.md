# Unums

[![Build Status](https://travis-ci.org/tbreloff/Unums.jl.svg?branch=master)](https://travis-ci.org/tbreloff/Unums.jl)

### Experimental! Use at your own risk!

This is the basic representation of an unum (universal number) as described in detail in
John L Gustafson's book 'The End of Error: Unum Computing':

`| signbit | exponent | fraction | ubit | exponent size - 1 | fraction size - 1 |`

The first 3 fields are similar to floating point representation, but allowing the exponent and fraction to have flexible sizes.

The `ubit` (uncertainty bit) signifies whether the number is an exact or uncertain:

  0 --> Exact  
  1 --> Number u falls in the OPEN interval (u, u +/- ULP), where ULP is the distance to the next
        representable number, and the sign depends on the signbit.

Unums can be expanded to fit into fixed widths, and can be supplemented with summary info, such as
bit flags indicating NaN, Inf, negativity, etc which can help speed many operations.  I'll probably 
attempt a FixedUnum type that fills 32/64/128 bits.


## Current implementation

### NOTE: this implementation is changing daily... the code is a better reference...

Core types:

```
abstract AbstractUnum{B,ESS,FSS} <: Real

bitstype 64 FixedUnum64{B,ESS,FSS} <: AbstractUnum{B,ESS,FSS}
typealias BinaryUnum64{ESS,FSS}   FixedUnum64{2,ESS,FSS}
typealias DecimalUnum64{ESS,FSS}  FixedUnum64{10,ESS,FSS}
typealias Unum64                  BinaryUnum64{4,5}
```

Eventually I plan on generating similar type groups for standard sizes 16/32/64/128 bits

A `FixedUnum64` is always 64 bits, but the internal meaning of the bits may change depending on the esize/fsize fields.

#### Parameters:
- B: the base of the exponent (base-2 is similar to floats, base-10 is similar to decimal floats)
- ESS: the size of the "exponent size" field 
- FSS: the size of the "fraction size" field

The format is as follows:

`| signbit | unused space | exponent | fraction | ubit | esize - 1 | fsize - 1 |`

There are 3 goals with this design:
- Use current hardware optimizations where possible.  Fill out standard bit sizes (16/32/64/128) and make use of optimized UInt operations as much as possible.
- Allow for extreme flexibility.  Some problems need a big exponent, others a big fraction, some both.
- Underlying methods should be minimal and fast.  If there's something we can hardcode, we should.  Staged functions are perfect for this.

Defs:
```
  signbit         = boolean value, 0 for positive, 1 for negative
  exponent        = same as in floats
  fraction        = same as in floats
  ubit            = boolean value, 0 for exact, 1 for inexact
  esize           = size of the exponent field
  fsize           = size of the fraction field
  esizesize       = total size of the "exponent size" field... allows up to (2^ESS + 1) bits in the exponent
  fsizesize       = total size of the "fraction size" field... allows up to (2^FSS + 1) bits in the fraction
```


Calling `show` will give you a structured bits layout:
```
julia> c.posinf
bits: 0000001111111111111111111111111111111111111111111111110111111111
|    0    | 1111111111111111 | 11111111111111111111111111111111 |  0   |  1111   |  11111  | 
| signbit |       exp        |               frac               | ubit | esize-1 | fsize-1 | 

julia> c.mostneg
bits: 1000001111111111111111111111111111111111111111111111100111111111
|    1    | 1111111111111111 | 11111111111111111111111111111110 |  0   |  1111   |  11111  | 
| signbit |       exp        |               frac               | ubit | esize-1 | fsize-1 | 

```

Many functions will be staged using the `@generated` macro and cached constants specific to a given set of Unum parameters:
```
julia> c = Unums.unumConstants(Unums.Unum64)
UnumInfo{Unums.FixedUnum64{2,4,5}}:
             base      2
            nbits     64
            esize     16
            fsize     32
        esizesize      4
        fsizesize      5
         utagsize     10
       signbitpos     64
             epos     58
             fpos     42
          ubitpos     10
         esizepos      9
         fsizepos      5
      signbitmask 1000000000000000000000000000000000000000000000000000000000000000
            emask 0000001111111111111111000000000000000000000000000000000000000000
            fmask 0000000000000000000000111111111111111111111111111111110000000000
         ubitmask 0000000000000000000000000000000000000000000000000000001000000000
        esizemask 0000000000000000000000000000000000000000000000000000000111100000
        fsizemask 0000000000000000000000000000000000000000000000000000000000011111
       efsizemask 0000000000000000000000000000000000000000000000000000000111111111
         utagmask 0000000000000000000000000000000000000000000000000000001111111111
             zero 0000000000000000000000000000000000000000000000000000000000000000
          poszero 0000000000000000000000000000000000000000000000000000001000000000
          negzero 1000000000000000000000000000000000000000000000000000001000000000
           posinf 0000001111111111111111111111111111111111111111111111110111111111
           neginf 1000001111111111111111111111111111111111111111111111110111111111
          mostpos 0000001111111111111111111111111111111111111111111111100111111111
         leastpos 0000000000000000000000000000000000000000000000000000010000000000
          mostneg 1000001111111111111111111111111111111111111111111111100111111111
         leastneg 1000000000000000000000000000000000000000000000000000010000000000
              nan 0000001111111111111111111111111111111111111111111111111111111111
             null 1000001111111111111111111111111111111111111111111111111111111111
```

My thinking is that, by putting the specification into these cache objects and using staged functions, we can allow for
total flexibility in the specifics of how a unum is represented, while at the same time providing extremely optimized
methods for creating and operating on them.
