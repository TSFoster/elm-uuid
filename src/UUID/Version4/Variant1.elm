module UUID.Version4.Variant1 exposing (decoder, encode, generator)

import Internal.UUID exposing (Variant(..), forceVariant1, variant)
import Internal.Version4 as V4
import Json.Decode
import Json.Encode
import Random exposing (Generator)
import UUID exposing (UUID, Variant1, Version4)
import UUID.Version4 as V4


{-| Variant 1 version 4 UUIDs provide 122 bits of randomness.


## Generating

@docs generator


## JSON

@docs encode, decoder

-}


{-| Generator for version 4 variant 1 UUIDs. See [elm-random](https://package.elm-lang.org/packages/elm/random/latest/) for more information on using Generators.
-}
generator : Generator (UUID Version4 Variant1)
generator =
    V4.generator V1


{-| Encode a variant 1 version 4 UUID as a JSON string.
-}
encode : UUID Version4 Variant1 -> Json.Encode.Value
encode =
    V4.encode


{-| Decodes a UUID from a JSON string. Fails if UUID is not version 4 or variant 1.
-}
decoder : Json.Decode.Decoder (UUID Version4 Variant1)
decoder =
    V4.decoder
        |> Json.Decode.andThen checkVariant1


checkVariant1 : UUID version variant -> Json.Decode.Decoder (UUID version Variant1)
checkVariant1 uuid =
    if variant uuid == Just 1 then
        Json.Decode.succeed (forceVariant1 uuid)

    else
        Json.Decode.fail "UUID not Variant 1"
