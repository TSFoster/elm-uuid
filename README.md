# Elm UUID

A [UUID](https://en.wikipedia.org/wiki/Universally_unique_identifier) is a universlaly unique identifier, usually represented as 32 hexidecimal digits, in the format `123e4567-e89b-12d3-a456-426655440000`.  This package provides a UUID type, and functions for generating, encoding, decoding and formatting UUIDs. There are several versions and variants of UUID. Currently these versions are supported:

* [Version 3, Variant 1](./UUID-Version3-Variant1) (namespaced hashes using MD5)
* [Version 3, Variant 2](./UUID-Version3-Variant2) (namespaced hashes using MD5)
* [Version 4, Variant 1](./UUID-Version4-Variant1) (randomly-generated hashes)
* [Version 4, Variant 2](./UUID-Version4-Variant2) (randomly-generated hashes)
* [Nil](./UUID#nil) (`00000000-0000-0000-0000-000000000000`)

## Warning about Version 4 UUIDs

Version 4 UUIDs have either 121 or 122 bits randomly allocated (depending on variant). I am not an expert in entropy or [elm/random](https://package.elm-lang.org/packages/elm/random/latest/), but I suspect the `Random.Generator` does not provide the necessary entropy to fully utilise all those bits of randomness. Still, I suspect it is sufficient for most use cases.
