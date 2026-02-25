# Elm UUID

A universally unique identifier, or [UUID], is a 128-bit number,
usually represented as 32 hexidecimal digits, in the format
`123e4567-e89b-42d3-a456-426655440000`. This package provides a UUID type, and
functions for reading, creating, randomly generating, inspecting and formatting
UUIDs.

There are several versions and variants of UUID. This package supports
the reading of all variant 1 UUIDs (versions 1-8, those outlined in [RFC
4122][rfc4122] and [RFC 9562][rfc9562]), and the creation of versions 3, 4, 5
and 7. This covers the vast majority of UUIDs in use today.


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


-- Version 7: time-sortable UUIDs (RFC 9562)
import Time

Random.initialSeed 42
    |> Random.step (UUID.generatorV7 (Time.millisToPosix 1700000000000))
    |> Tuple.first
    |> UUID.toString
--> a v7 UUID with timestamp 1700000000000 embedded


-- Monotonic v7 UUIDs within the same millisecond
let
    time = Time.millisToPosix 1700000000000
    ( state, _ ) = Random.step UUID.initialV7State (Random.initialSeed 42)
    ( uuid1, state1 ) = UUID.stepV7 time state
    ( uuid2, _ ) = UUID.stepV7 time state1
in
UUID.compare uuid1 uuid2
--> LT (uuid1 < uuid2, guaranteed)
```

## Roadmap

* More tests:
  * test fromBytes explicitly
  * fewer/simpler doc tests?
  * test against set of known v3/v5 UUIDs
  * split into smaller files?


## Q&A

### Are the generated UUIDs random enough?

Short answer: for most cases where you want to quickly generate a UUID on the
client, probably.

`Random.Seed` has either 32 or 54 bits of randomness, depending on your system
Version 4 UUIDs should have 122 bits of randomness. You should consider [how
best to generate your Seed][elmrandom2]. Although the API is a little messier
than using `UUID.Generator`, it is recommended to try using `UUID.step`, so
`UUID`s can be generated using four independent seeds. One way of generating the
seeds would be to use [`Crypto.getRandomValues()`][getRandomValues] to create
four 32-bit integers, and passing them in as flags or via ports.

### Which version UUID am I using?

You can check what variant/version you are using by looking at one of the
UUIDs, which should be in the format `00000000-0000-A000-B000-000000000000`.
If the character at position `B` is `8`, `9`, `a` or `b`, you have a variant 1
UUID, and this package is for you! The character in position `A` is the version
number. (If it isn't `1`-`8`, then it isn't a UUID as defined
by [RFC 4122][rfc4122] or [RFC 9562][rfc9562].)

### Which version UUID should I use?

Probably version 4, 5 or 7, depending on your use case:

- **Version 4**: Randomly generated. Use [`generator`][generator] when you need
  a unique key for a value that may change over time.
- **Version 5**: Deterministic, created from a "name" and a "namespace". Use
  [`forName`][forName] or [`forBytes`][forBytes] when the same input should
  always produce the same UUID (version 3 is similar but version 5 is
  recommended unless required for backwards-compatibility).
- **Version 7**: Time-sortable, containing a Unix timestamp in milliseconds
  plus random data. Use [`generatorV7`][generatorV7] when UUIDs are used as
  database primary keys or when sort order by creation time matters. Use
  [`stepV7`][stepV7] with [`initialV7State`][initialV7State] when you need
  monotonic ordering within the same millisecond.

### I have a suggestion/I've found a bug

Please [open an issue on Github][new-issue] and I'll get back to you as soon as
I can.

### I need to create version 1/2 UUIDs

This can't *reaallly* be done in the browser (as far as I know), but feel free
to [open an issue on Github][new-issue] anyway.

### I need variant 0 UUIDs!

Really!? Umm, well I guess you'd better [open an issue on Github][new-issue].

### I need variant 1 UUIDs!

This might be better suited in a separate package, but why not [open an issue on
Github][new-issue]?


[UUID]: https://en.wikipedia.org/wiki/Universally_unique_identifier
[new-issue]: https://github.com/TSFoster/elm-uuid/issues/new
[elmrandom2]: https://github.com/elm/random/issues/2
[getRandomValues]: https://developer.mozilla.org/en-US/docs/Web/API/Crypto/getRandomValues
[rfc4122]: https://tools.ietf.org/html/rfc4122
[rfc9562]: https://www.rfc-editor.org/rfc/rfc9562.html
[generator]: https://package.elm-lang.org/packages/TSFoster/elm-uuid/latest/UUID#generator
[generatorV7]: https://package.elm-lang.org/packages/TSFoster/elm-uuid/latest/UUID#generatorV7
[initialV7State]: https://package.elm-lang.org/packages/TSFoster/elm-uuid/latest/UUID#initialV7State
[stepV7]: https://package.elm-lang.org/packages/TSFoster/elm-uuid/latest/UUID#stepV7
[forName]: https://package.elm-lang.org/packages/TSFoster/elm-uuid/latest/UUID#forName
[forBytes]: https://package.elm-lang.org/packages/TSFoster/elm-uuid/latest/UUID#forBytes
