# Elm UUID

A [UUID](https://en.wikipedia.org/wiki/Universally_unique_identifier) is a universlaly unique identifier, usually represented as 32 hexidecimal digits, in the format `123e4567-e89b-12d3-a456-426655440000`. This package provides a UUID type, and functions for generating, encoding, decoding and formatting UUIDs. There are several versions and variants of UUID. Currently, the nil UUID, version 3 and 4 UUIDs, and both variants are supported.

## Warning about Version 4 UUIDs

Version 4 UUIDs have either 121 or 122 bits randomly allocated (depending on variant). I am not an expert in entropy or [elm/random](https://package.elm-lang.org/packages/elm/random/latest/), but I suspect the `Random.Generator` does not provide the necessary entropy to fully utilise all those bits of randomness. Still, I suspect it is sufficient for most use cases.
