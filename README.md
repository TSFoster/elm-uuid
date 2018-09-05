# Elm UUID

This package provides a UUID type, and functions for generating, encoding, decoding and formatting UUIDs. Currently these versions are supported:

* [Version 4, Variant 1](./UUID-Version4-Variant1)
* [Version 4, Variant 2](./UUID-Version4-Variant2)
* [Nil](./UUID#nil)

#### Warning about Version 4 UUIDs

Version 4 UUIDs have either 121 or 122 bits randomly allocated (depending on variant). I am not an expert in entropy or [elm/random](https://package.elm-lang.org/packages/elm/random/latest/), but I suspect the `Random.Generator` does not provide the necessary entropy to fully utilise all those bits of randomness. Still, I suspect it is sufficient for most use cases.
