module UUID exposing
    ( UUID, Version4, Variant1, Variant2, Nil, nil
    , encode, decoder
    , canonical, microsoftGUID, urn
    )

{-| A module defining UUIDs in the general, and providing functions for encoding, decoding and formatting UUIDs.

@docs UUID, Version4, Variant1, Variant2, Nil, nil


## JSON

@docs encode, decoder


## Formatting

@docs canonical, microsoftGUID, urn

-}

import Internal.UUID as I
import Json.Decode
import Json.Encode


{-| Opaque type to encapsulate UUIDs. Uses [phantom types](https://medium.com/@ckoster22/advanced-types-in-elm-phantom-types-808044c5946d) to provide information about version and variant.
-}
type alias UUID version variant =
    I.UUID version variant


{-| Used to denote version and variant of the nil UUID.
-}
type alias Nil =
    I.Nil


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
    I.fromStrings "00000000" "0000" "0000" "0000" "000000000000"


{-| Encode a UUID of any version or variant as a JSON string.
-}
encode : UUID version variant -> Json.Encode.Value
encode =
    I.encode


{-| Decodes a UUID of any version or variant from a JSON string.
-}
decoder : Json.Decode.Decoder (UUID version variant)
decoder =
    I.decoder


{-| Convert UUID to [canonical textual representation](https://en.wikipedia.org/wiki/Universally_unique_identifier#Format)
-}
canonical : UUID version variant -> String
canonical =
    I.canonical


{-| Convert UUID to [Microsoft GUID representation](https://en.wikipedia.org/wiki/Universally_unique_identifier#Format)
-}
microsoftGUID : UUID version variant -> String
microsoftGUID =
    I.microsoftGUID


{-| Convert UUID to [URN-namespaced representation](https://en.wikipedia.org/wiki/Universally_unique_identifier#Format)
-}
urn : UUID version variant -> String
urn =
    I.urn
