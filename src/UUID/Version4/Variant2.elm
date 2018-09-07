module UUID.Version4.Variant2 exposing
    ( generator
    , encode, decoder
    )

{-| Variant 2 version 4 UUIDs provide 121 bits of randomness.


## Generating

@docs generator


## JSON

@docs encode, decoder

-}

import Internal.UUID as I
import Json.Decode
import Json.Encode
import Random exposing (Generator)
import UUID exposing (UUID, Variant2, Version4)
import UUID.Version4 as V4


{-| Generator for version 4 variant 2 UUIDs. See [elm-random](https://package.elm-lang.org/packages/elm/random/latest/) for more information on using Generators.

    ( uuid, newSeed ) =
        Random.step generator model.seed

-}
generator : Generator (UUID Version4 Variant2)
generator =
    I.generator
        |> Random.map I.setVersion4
        |> Random.map I.setVariant2


{-| Encode a variant 2 version 4 UUID as a JSON string.

    Json.Encode.encode 0 (encode someUUID) -- e.g. "\"e87947aa-42a0-4b96-c5dc-181285004d36\""

-}
encode : UUID Version4 Variant2 -> Json.Encode.Value
encode =
    I.encode


{-| Decodes a UUID from a JSON string. Fails if UUID is not version 4 or variant 2.

    Json.Decode.decodeValue decoder someValue
        |> UUID.canonical -- e.g. "e87947aa-42a0-4b96-c5dc-181285004d36"

-}
decoder : Json.Decode.Decoder (UUID Version4 Variant2)
decoder =
    V4.decoder
        |> Json.Decode.andThen I.checkVariant2
