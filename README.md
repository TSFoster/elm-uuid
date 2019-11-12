# Elm UUID

A universally unique identifier, or [UUID], is a 128-bit number,
usually represented as 32 hexidecimal digits, in the format
`123e4567-e89b-42d3-a456-426655440000`. This package provides a UUID type, and
functions for reading, creating, randomly generating, inspecting and formatting
UUIDs.

There are several versions and variants of UUID. This package supports
the reading of all variant 1 UUIDs (versions 1-5, those outlined in [RFC
4122][rfc]), and the creation of versions 3, 4 and 5. This covers the vast
majority of UUIDs in use today.


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


## Questions

###### Which version UUID am I using?

You can check what variant/version you are using by looking at one of the
UUIDs, which should be in the format `00000000-0000-A000-B000-000000000000`.
If the character at position `B` is `8`, `9`, `a` or `b`, you have a variant 1
UUID, and this package is for you! The character in position `A` is the version
number. (If it isn't `1`, `2`, `3`, `4` or `5`, then it isn't a UUID as defined
by the [RFC][rfc].)

###### Which version UUID should I use?

Probably either version 4 or 5, depending on your use case. Version 4 UUIDs
are randomly generated, while version 5 UUIDs are created from a "name" and
a "namespace", such that the same "name" and "namespace" produces the same
UUID.

If you want to use the UUID as a key for a value that may change over
time, you may want to use [`generator`][generator] to create version 4 UUIDs.

If the UUID will refer to something that will not change over time, or will
need to be calculated in some other way from some input data, consider using
[`forName`][forName] and [`forBytes`][forBytes] to create version 5 UUIDs
(version 3 UUIDs are very similar, but version 5 is recommended unless required
for backwards-compatbility).

###### I have a suggestion/I've found a bug

Please [open an issue on Github][new-issue] and I'll get back to you as soon as
I can.

###### I need to create version 1/2 UUIDs

This can't *reaallly* be done in the browser (as far as I know), but feel free
to [open an issue on Github][new-issue] anyway.

###### I need variant 0 UUIDs!

Really!? Umm, well I guess you'd better [open an issue on Github][new-issue].

###### I need variant 1 UUIDs!

This might be better suited in a separate package, but why not [open an issue on
Github][new-issue]?


[UUID]: https://en.wikipedia.org/wiki/Universally_unique_identifier
[new-issue]: https://github.com/TSFoster/elm-uuid/issues/new
[rfc]: https://tools.ietf.org/html/rfc4122
[generator]: https://package.elm-lang.org/packages/TSFoster/elm-uuid/latest/UUID#generator
[forName]: https://package.elm-lang.org/packages/TSFoster/elm-uuid/latest/UUID#forName
[forBytes]: https://package.elm-lang.org/packages/TSFoster/elm-uuid/latest/UUID#forBytes
