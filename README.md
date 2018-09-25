# Elm UUID

A universally unique identifier, or [UUID], is a 128-bit number,
usually represented as 32 hexidecimal digits, in the format
`123e4567-e89b-42d3-a456-426655440000`. This package provides a UUID type, and
functions for reading, creating, randomly generating, inspecting and formatting
UUIDs.

There are several versions and variants of UUID. Currently, creating the nil
UUID, version 3, 4 and 5 UUIDs, and both variants are supported. However, all
types can be understood and formatted.

## [Documentation]

## Warning about Version 4 UUIDs

Version 4 UUIDs have either 121 or 122 bits randomly allocated (depending on
variant). I am neither an expert in entropy nor [elm/random], but I suspect the
`Random.Generator` does not provide the necessary entropy to fully utilise all
those bits of randomness. Still, it is probably more than sufficient for most
use cases.

## Examples

```elm
import UUID exposing (UUID)
import Random


someSeed : Random.Seed
someSeed = Random.initialSeed 12345


makeIds : Int -> Random.Seed -> (List UUID, Random.Seed)
makeIds amount seed =
    Random.step (Random.list amount UUID.generator) seed


makeIds 3 someSeed
    |> Tuple.first
    |> List.map UUID.toVariant2
    |> List.map UUID.urn
--> [ "urn:uuid:fe86e741-b117-42ec-cade-4c0e16b4f15c"
--> , "urn:uuid:5fb50b3a-fa84-47eb-c55d-56e740013db2"
--> , "urn:uuid:695eec7b-3084-40e3-d94b-59028c466d1d"
--> ]


appID : UUID
appID = UUID.childNamed "myapplication.com" UUID.dns

UUID.canonical appID
--> "2ed74b2b-10eb-5b44-93be-69aa8952caac"
```

[uuid]: https://en.wikipedia.org/wiki/Universally_unique_identifier
[Documentation]: https://package.elm-lang.org/packages/TSFoster/elm-uuid/latest/UUID
[elm/random]: https://package.elm-lang.org/packages/elm/random/latest/
