module UUID.Version3 exposing (encode, decoder)

{-| Version 3 and version 5 UUIDs are hashes of a namespace and an optional name. Currently only version 3 hashes (using MD5) are supported.


## JSON

@docs encode, decoder

-}

import Internal.UUID as I
import Json.Decode
import Json.Encode
import UUID exposing (UUID, Version3)


{-| Encode a version 3 UUID of any variant as a JSON string.
-}
encode : UUID Version3 variant -> Json.Encode.Value
encode =
    I.encode


{-| Decodes a version 3 UUID of any variant from a JSON string.
-}
decoder : Json.Decode.Decoder (UUID Version3 variant)
decoder =
    I.decoder |> Json.Decode.andThen I.checkVersion3
