# Elm UUID

A universally unique identifier, or [UUID], is a 128-bit number,
usually represented as 32 hexidecimal digits, in the format
`123e4567-e89b-42d3-a456-426655440000`. This package provides a UUID type, and
functions for reading, creating, randomly generating, inspecting and formatting
UUIDs.

There are several versions and variants of UUID. Currently, creating the nil
UUID, version 3 and 4 UUIDs, and both variants are supported. However, all types
can be understood and formatted.

## [Documentation]

## Warning about Version 4 UUIDs

Version 4 UUIDs have either 121 or 122 bits randomly allocated (depending on
variant). I am neither an expert in entropy nor [elm/random], but I suspect the
`Random.Generator` does not provide the necessary entropy to fully utilise all
those bits of randomness. Still, it is probably more than sufficient for most
use cases.

[uuid]: https://en.wikipedia.org/wiki/Universally_unique_identifier
[Documentation]: https://package.elm-lang.org/packages/TSFoster/elm-uuid/latest/UUID
[elm/random]: https://package.elm-lang.org/packages/elm/random/latest/
