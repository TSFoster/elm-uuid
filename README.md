# Elm UUID

A universally unique identifier, or [UUID], is a 128-bit number,
usually represented as 32 hexidecimal digits, in the format
`123e4567-e89b-42d3-a456-426655440000`. This package provides a UUID type, and
functions for reading, creating, randomly generating, inspecting and formatting
UUIDs.

There are several versions and variants of UUID. As of elm-uuid version 3.0.0,
only versions 3, 4 and 5 are supported, and only variant 1.


## Examples

```elm
import UUID exposing (UUID)
import Random


Random.initialSeed 12345
    |> Random.step (Random.list 3 UUID.generator)
    |> Tuple.first
    |> List.map UUID.toString
--> [ "88c973e3-f83f-4360-a320-d8844c365130"
--> , "78bc3402-e662-4d59-bac5-914be6425299"
--> , "5b58931d-bb69-406d-81a9-7746c300838c"
--> ]


appID : UUID
appID = UUID.forName "myapplication.com" UUID.dnsNamespace

UUID.toString appID
--> "2ed74b2b-10eb-5b44-93be-69aa8952caac"
```


## What about versions 1 and 2?/I need variant 2 UUIDs./Don't you know people still use version 0!?

Support for these types of UUID were dropped in elm-uuid version 3, as I
understand them to be very rarely used. However, if there is a need for them,
I would consider supporting them again. Please [open an issue][new-issue]
requesting support.


[UUID]: https://en.wikipedia.org/wiki/Universally_unique_identifier
[new-issue]: https://github.com/TSFoster/elm-uuid/issues/new
