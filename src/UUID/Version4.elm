module UUID.Version4 exposing (decoder, encode)

import Internal.UUID as I
import Json.Decode
import Json.Encode
import UUID exposing (UUID, Version4)


{-| Version 4 UUIDs are randomly-generated. To generate version 4 UUIDs, see [UUID.Version4.Variant1.generator](../UUID-Version4-Variant1#generator) or [UUID.Version4.Variant2.generator](../UUID-Version4-Variant2#generator).


## JSON

@docs encode, decoder

-}


{-| Encode a version 4 UUID of any variant as a JSON string.
-}
encode : UUID Version4 variant -> Json.Encode.Value
encode =
    I.encode


{-| Decodes a version 4 UUID of any variant from a JSON string.
-}
decoder : Json.Decode.Decoder (UUID Version4 variant)
decoder =
    I.decoder
        |> Json.Decode.andThen checkVersion4


checkVersion4 : UUID version variant -> Json.Decode.Decoder (UUID Version4 variant)
checkVersion4 uuid =
    if I.version uuid == Just 4 then
        Json.Decode.succeed (I.forceVersion4 uuid)

    else
        Json.Decode.fail "UUID not Version 4"
