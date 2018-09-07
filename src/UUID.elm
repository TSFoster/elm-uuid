module UUID exposing
    ( UUID, Version3, Version4, Variant1, Variant2, Nil, nil
    , encode, decoder
    , canonical, microsoftGUID, urn
    )

{-| A module defining UUIDs in the general, and providing functions for encoding, decoding and formatting UUIDs.

@docs UUID, Version3, Version4, Variant1, Variant2, Nil, nil


## JSON

@docs encode, decoder


## Formatting

@docs canonical, microsoftGUID, urn

-}

import Internal.UUID as I
import Json.Decode
import Json.Encode


{-| Opaque type to encapsulate UUIDs. Uses [phantom types](https://medium.com/@ckoster22/advanced-types-in-elm-phantom-types-808044c5946d) to provide information about version and variant.

    type alias Model =
        { title : String
        , uuid : UUID Version4 Variant1
        , published : Maybe Date
        , authors : List (UUID Version4 Variant1)
        }

-}
type alias UUID version variant =
    I.UUID version variant


{-| Used to denote version and variant of the nil UUID.
-}
type alias Nil =
    I.Nil


{-| Used to denote version of version 4 UUIDs.
-}
type alias Version3 =
    I.Version3


{-| Used to denote version of version 4 UUIDs.
-}
type alias Version4 =
    I.Version4


{-| Used to denote variation of variation 1 UUIDs.
-}
type alias Variant1 =
    I.Variant1


{-| Used to denote variation of variation 2 UUIDs.
-}
type alias Variant2 =
    I.Variant2


{-| The nil UUID. This is the special UUID "00000000-0000-0000-0000-000000000000".
-}
nil : UUID Nil Nil
nil =
    I.nil


{-| Encode a UUID of any version or variant as a JSON string.

    Json.Encode.encode 0 (encode 0 nil) == "\"00000000-0000-0000-0000-000000000000\""

-}
encode : UUID version variant -> Json.Encode.Value
encode =
    I.encode


{-| Decodes a UUID of any version or variant from a JSON string.

    "\"123e4567-e89b-12d3-a456-426655440000\""
        |> Json.Decode.decodeString decoder
        |> canonical -- == "123e4567-e89b-12d3-a456-426655440000"

-}
decoder : Json.Decode.Decoder (UUID version variant)
decoder =
    I.decoder


{-| Convert UUID to [canonical textual representation](https://en.wikipedia.org/wiki/Universally_unique_identifier#Format)

    canonical nil == "00000000-0000-0000-0000-000000000000"

-}
canonical : UUID version variant -> String
canonical =
    I.canonical


{-| Convert UUID to [Microsoft GUID representation](https://en.wikipedia.org/wiki/Universally_unique_identifier#Format)

    microsoftGUID nil == "{00000000-0000-0000-0000-000000000000}"

-}
microsoftGUID : UUID version variant -> String
microsoftGUID uuid =
    "{" ++ canonical uuid ++ "}"


{-| Convert UUID to [URN-namespaced representation](https://en.wikipedia.org/wiki/Universally_unique_identifier#Format)

    urn nil == "urn:uuid:00000000-0000-0000-0000-000000000000"

-}
urn : UUID version variant -> String
urn uuid =
    "urn:uuid:" ++ canonical uuid
