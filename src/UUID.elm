module UUID exposing
    ( UUID
    , fromString, Error(..)
    , generator
    , forName, forBytes, forNameV3, forBytesV3
    , dnsNamespace, urlNamespace, oidNamespace, x500Namespace
    , fromBytes, decoder, toBytes, encoder
    , toString, toRepresentation, Representation(..)
    , version
    , nilBytes, isNilBytes, nilString, isNilString, nilRepresentation
    )

{-| A UUID looks something like `e1631449-6321-4a58-920c-5440029b092e`, and can
be used as an identifier for anything. Each 128-bit number, usually represented
as 32 hexadecimal digits, is generally used under the assumption that it is
Universally Unique (hence the name).

This package supports variant 1 UUIDs (those outlined in [RFC 4122][rfc]), which
covers the vast majority of those in use (versions 1-5).

@docs UUID


## Reading UUIDs

@docs fromString, Error


## Creating UUIDs


### Random UUIDs (Version 4)

@docs generator


### Hierarchical, namespaced UUIDs (Version 3, Version 5)

UUIDs can be created using a namespace UUID and a name, which is then hashed
to create a new UUID. The hash function used depends on the version of UUID:
verison 3 UUIDs use MD5, and version 5 UUIDs use SHA-1. **Version 5 is the
[officially recommended] version to use.**

Although the [RFC defining UUIDs][rfc] defines some [base
namespaces][appendix-c], any UUID can be used as a namespace, making a
hierarchy. I think this is pretty cool! You can use this method for consistently
making the same UUID from the same data, which can be very useful in some
situations.

[officially recommended]: https://tools.ietf.org/html/rfc4122#section-4.3
[rfc]: https://tools.ietf.org/html/rfc4122
[appendix-c]: https://tools.ietf.org/html/rfc4122#appendix-C

@docs forName, forBytes, forNameV3, forBytesV3


#### Officially-recognized namespaces

@docs dnsNamespace, urlNamespace, oidNamespace, x500Namespace


## Binary representation

@docs fromBytes, decoder, toBytes, encoder


## Formatting UUIDs

UUIDs are generally represented by 32 hexadecimal digits in the form
`00112233-4455-M677-N899-aabbccddeeff`, where the four bits at position `M`
denote the UUID version, and the first two or three bits at position `N` denote
the variant. This is the "canonical" representation, but there is also a URN
representation and a format used mostly by Microsoft, where they are more
commonly named GUIDs.

@docs toString, toRepresentation, Representation


## Inspecting UUIDs

@docs version


## The Nil UUID

One more, special UUID is the nil UUID. This is just
`"00000000-0000-0000-0000-000000000000"`. I suppose it can work as a placeholder
in some cases, but elm has `Maybe` for that! Nevertheless, you might need to
check for nil UUIDs, or print the nil UUID.

@docs nilBytes, isNilBytes, nilString, isNilString, nilRepresentation

-}

import Bitwise
import Bytes exposing (Bytes, Endianness(..))
import Bytes.Decode
import Bytes.Decode.Extra
import Bytes.Encode
import Bytes.Extra
import MD5
import Random
import Result exposing (Result)
import SHA1



-- TYPES


{-| This modules provides a UUID type, and functions to work with them. It is an
[opaque type], which basically means you have to use the provided functions if
you want to do anything with it!

[opaque type]: https://medium.com/@ckoster22/advanced-types-in-elm-opaque-types-ec5ec3b84ed2

Here is an example of a `Book` model, which uses UUIDs to identify both the book
and its authors:

    type alias Book =
        { title : String
        , uuid : UUID
        , published : Maybe Date
        , authors : List UUID
        }

-}
type UUID
    = UUID Int Int Int Int


{-| This enumerates all the possible errors that can happen when reading
existing UUIDs.

    import Bytes.Extra exposing (fromByteValues)

    -- Note the non-hexadecimal characters in this string!
    fromString "12345678-9abc-4567-89ab-cdefghijklmn"
    --> Err WrongFormat

    fromBytes (fromByteValues [ 223 ])
    --> Err WrongLength

    -- This package only supports variant 1 UUIDs
    fromString "urn:uuid:12345678-9abc-4567-c234-abcd12345678"
    --> Err UnsupportedVariant

    fromBytes (fromByteValues [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    --> Err IsNil

    fromString "{00000000-0000-0000-0000-000000000000}"
    --> Err IsNil

    fromString "6ba7b814-9dad-71d1-80b4-00c04fd430c8"
    --> Err NoVersion

-}
type Error
    = WrongFormat
    | WrongLength
    | UnsupportedVariant
    | IsNil
    | NoVersion


{-| There are three typical human-readable representations of UUID: canonical, a
Uniform Resource Name and Microsoft's formatting for its GUIDs (which are just
version 4 UUIDs nowadays).
-}
type Representation
    = Canonical
    | Urn
    | Guid



-- FORMATTING


{-| The canonical representation of the UUID. This is the same as
`toRepresentation Canonical`.

    toString dnsNamespace
    --> "6ba7b810-9dad-11d1-80b4-00c04fd430c8"

-}
toString : UUID -> String
toString (UUID a b c d) =
    String.padLeft 8 '0' (toHex [] a)
        ++ "-"
        ++ String.padLeft 4 '0' (toHex [] (Bitwise.shiftRightZfBy 16 b))
        ++ "-"
        ++ String.padLeft 4 '0' (toHex [] (Bitwise.and 0xFFFF b))
        ++ "-"
        ++ String.padLeft 4 '0' (toHex [] (Bitwise.shiftRightZfBy 16 c))
        ++ "-"
        ++ String.padLeft 4 '0' (toHex [] (Bitwise.and 0xFFFF c))
        ++ String.padLeft 8 '0' (toHex [] d)


{-| Convert UUID to [a given format](https://en.wikipedia.org/wiki/Universally_unique_identifier#Format)

    toRepresentation Canonical dnsNamespace
    --> "6ba7b810-9dad-11d1-80b4-00c04fd430c8"

    toRepresentation Urn dnsNamespace
    --> "urn:uuid:6ba7b810-9dad-11d1-80b4-00c04fd430c8"

    toRepresentation Guid dnsNamespace
    --> "{6ba7b810-9dad-11d1-80b4-00c04fd430c8}"

-}
toRepresentation : Representation -> UUID -> String
toRepresentation representation uuid =
    case representation of
        Canonical ->
            toString uuid

        Urn ->
            "urn:uuid:" ++ toString uuid

        Guid ->
            "{" ++ toString uuid ++ "}"


{-| Generating a random UUID (version 4) is, I think, the most straightforward
way of making a UUID, and I see them used all the time. There are a couple of
ways of using a generator to create a value, which are described nicely in the
[elm/random docs][elm-random].

[elm-random]: https://package.elm-lang.org/packages/elm/random/latest/

    import Random

    Random.step UUID.generator (Random.initialSeed 12345)
        |> Tuple.first
        |> UUID.toRepresentation Urn
    --> "urn:uuid:5b58931d-bb69-406d-81a9-7746c300838c"

-}
generator : Random.Generator UUID
generator =
    Random.map4 UUID randomU32 randomU32 randomU32 randomU32
        |> Random.map (toVersion 4 >> toVariant1)


randomU32 : Random.Generator Int
randomU32 =
    Random.int Random.minInt Random.maxInt
        |> Random.map forceUnsigned


{-| You can attempt to create a UUID from a string. This function can interpret
a fairly broad range of formatted (and mis-formatted) UUIDs, including ones with
too much whitespace, too many (or not enough) hyphens, or uppercase characters.

    fromString "c72c207b-0847-386d-bdbc-2e5def81cf811"
    --> Err WrongLength

    fromString "c72c207b-0847-386d-bdbc-2e5def81cg81"
    --> Err WrongFormat

    fromString "c72c207b-0847-386d-bdbc-2e5def81cf81"
        |> Result.map version
    --> Ok 3

    fromString "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
    --> Ok dnsNamespace

-}
fromString : String -> Result Error UUID
fromString string =
    let
        normalized =
            string
                |> String.replace "\n" ""
                |> String.replace "\t" ""
                |> String.replace " " ""
                |> String.replace "-" ""
                |> String.toLower
                |> (\str ->
                        if String.startsWith "urn:uuid:" str then
                            String.dropLeft 9 str

                        else if String.startsWith "{" str && String.endsWith "}" str then
                            String.slice 1 -1 str

                        else
                            str
                   )
    in
    if String.length normalized /= 32 then
        Err WrongLength

    else
        case List.filterMap toNibbleValue (String.toList normalized) of
            [ a1, a2, a3, a4, a5, a6, a7, a8, b1, b2, b3, b4, b5, b6, b7, b8, c1, c2, c3, c4, c5, c6, c7, c8, d1, d2, d3, d4, d5, d6, d7, d8 ] ->
                fromInt32s
                    (nibbleValuesToU32 a1 a2 a3 a4 a5 a6 a7 a8)
                    (nibbleValuesToU32 b1 b2 b3 b4 b5 b6 b7 b8)
                    (nibbleValuesToU32 c1 c2 c3 c4 c5 c6 c7 c8)
                    (nibbleValuesToU32 d1 d2 d3 d4 d5 d6 d7 d8)

            _ ->
                Err WrongFormat


{-| Get the version number of a `UUID`. Only versions 3, 4 and 5 are supported
in this package, so you should only expect the returned `Int` to be `3`, `4` or
`5`.

    import Random

    Random.step generator (Random.initialSeed 1)
        |> Tuple.first
        |> version
    --> 4

    fromString "{12345678-1234-5678-8888-0123456789ab}"
        |> Result.map version
    --> Ok 5

-}
version : UUID -> Int
version (UUID _ b _ _) =
    -- Version bits are stored in the 13th to 10th least significant bits of b.
    -- The value of this "nibble" (4 bits) == the version.
    Bitwise.shiftRightZfBy 12 b
        |> Bitwise.and 0x0F


isVariant1 : UUID -> Bool
isVariant1 (UUID _ _ c _) =
    -- The 2 most significant bits of c have to be 0b10 for it to be Variant 1
    Bitwise.shiftRightZfBy 30 c == 2



-- NAMESPACED UUIDS


{-| Create a version 5 UUID from a `String` and a namespace, which should be a
`UUID`. The same name and namespace will always produce the same UUID, which can
be used to your advantage. Furthermore, the UUID created from this can be used
as a namespace for another UUID, creating a hierarchy of sorts.

    apiNamespace : UUID
    apiNamespace =
        forName "https://api.example.com/v2/" dnsNamespace

    widgetNamespace : UUID
    widgetNamespace =
        forName "Widget" apiNamespace


    toString apiNamespace
    --> "bad122ad-b5b6-527c-b544-4406328d8b13"

    toString widgetNamespace
    --> "7b0db628-d793-550b-a883-937a276f4908"

-}
forName : String -> UUID -> UUID
forName =
    forBytes << Bytes.Encode.encode << Bytes.Encode.string


{-| Similar to [`forName`](#forName), creates a UUID based on the given String
and namespace UUID, but creates a version 3 UUID. If you can choose between the
two, it is recommended that you choose version 5 UUIDs.

    apiNamespace : UUID
    apiNamespace =
        forNameV3 "https://api.example.com/v1/" dnsNamespace

    toString apiNamespace
    --> "f72dd2ff-b8e7-3c58-afe1-352d5e273de4"

-}
forNameV3 : String -> UUID -> UUID
forNameV3 =
    forBytesV3 << Bytes.Encode.encode << Bytes.Encode.string


{-| Create a version 5 UUID from `Bytes` and a namespace, which should be a
`UUID`. The same name and namespace will always produce the same UUID, which can
be used to your advantage. Furthermore, the UUID created from this can be used
as a namespace for another UUID, creating a hierarchy of sorts.

    import Bytes
    import Bytes.Encode

    type alias Widget = { name: String, value: Float }

    apiNamespace : UUID
    apiNamespace =
        forName "https://api.example.com/v2/" dnsNamespace

    widgetNamespace : UUID
    widgetNamespace =
        forName "Widget" apiNamespace

    uuidForWidget : Widget -> UUID
    uuidForWidget { name, value } =
        let
           bytes =
             Bytes.Encode.encode <| Bytes.Encode.sequence
                [ Bytes.Encode.unsignedInt32 Bytes.BE (String.length name)
                , Bytes.Encode.string name
                , Bytes.Encode.float64 Bytes.BE value
                ]
        in
        forBytes bytes widgetNamespace


    Widget "Exponent" 0.233
        |> uuidForWidget
        |> toString
    --> "46dab34b-5447-5c5c-8e24-fe4e3daab014"

-}
forBytes : Bytes -> UUID -> UUID
forBytes bytes namespace =
    [ encoder namespace, Bytes.Encode.bytes bytes ]
        |> Bytes.Encode.sequence
        |> Bytes.Encode.encode
        |> SHA1.fromBytes
        |> SHA1.toInt32s
        |> (\{ a, b, c, d } -> UUID a b c d)
        |> toVersion 5
        |> toVariant1


{-| Similar to [`forBytes`](#forBytes), creates a UUID based on the given Bytes
and namespace UUID, but creates a version 3 UUID. If you can choose between the
two, it is recommended that you choose version 5 UUIDs.

    import Bytes
    import Bytes.Encode

    apiNamespace : UUID
    apiNamespace =
        forName "https://api.example.com/v2/" dnsNamespace

    forBytesV3 (Bytes.Encode.encode (Bytes.Encode.unsignedInt8 245)) apiNamespace
        |> toString
    --> "4ad1f4bf-cf83-3c1d-b4f5-975f7d0fc9ba"

-}
forBytesV3 : Bytes -> UUID -> UUID
forBytesV3 bytes namespace =
    [ encoder namespace, Bytes.Encode.bytes bytes ]
        |> Bytes.Encode.sequence
        |> Bytes.Encode.encode
        |> Bytes.Extra.toByteValues
        |> MD5.fromBytes
        |> fromByteValuesUnchecked
        |> toVersion 3
        |> toVariant1



-- NIL UUID


{-| 128 bits of nothing.
-}
nilBytes : Bytes
nilBytes =
    toBytes (UUID 0 0 0 0)


{-| `True` if the given bytes are the nil UUID (00000000-0000-0000-0000-000000000000).

    isNilBytes nilBytes
    --> True

-}
isNilBytes : Bytes -> Bool
isNilBytes bytes =
    fromBytes bytes == Err IsNil


{-| `True` if the given string represents the nil UUID (00000000-0000-0000-0000-000000000000).
-}
isNilString : String -> Bool
isNilString string =
    fromString string == Err IsNil


{-|

    nilString
    --> "00000000-0000-0000-0000-000000000000"

-}
nilString : String
nilString =
    "00000000-0000-0000-0000-000000000000"


{-|

    nilRepresentation Canonical
    --> "00000000-0000-0000-0000-000000000000"

    nilRepresentation Urn
    --> "urn:uuid:00000000-0000-0000-0000-000000000000"

    nilRepresentation Guid
    --> "{00000000-0000-0000-0000-000000000000}"

-}
nilRepresentation : Representation -> String
nilRepresentation representation =
    case representation of
        Canonical ->
            nilString

        Urn ->
            "urn:uuid:" ++ nilString

        Guid ->
            "{" ++ nilString ++ "}"



-- BINARY REPRESENTATION


{-| You can attempt to create a UUID from some `Bytes`, the only contents of which much be the UUID.

    import Bytes.Extra exposing (fromByteValues)

    fromBytes (fromByteValues [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    --> Err IsNil

    fromBytes (fromByteValues [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0])
    --> Err WrongLength

    fromBytes (fromByteValues [0x6b, 0xa7, 0xb8, 0x14, 0x9d, 0xad, 0x11, 0xd1, 0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8])
    --> Ok x500Namespace

-}
fromBytes : Bytes -> Result Error UUID
fromBytes bytes =
    if Bytes.width bytes /= 16 then
        Err WrongLength

    else
        Bytes.Decode.decode resultDecoder bytes
            |> Maybe.withDefault (Err WrongLength)


{-| A `Bytes.Decode.Decoder`, for integrating with a broader decode.

    import Bytes
    import Bytes.Decode exposing (Decoder)
    import Bytes.Extra exposing (fromByteValues)

    type alias Record =
        { name : String
        , value : Int
        , id : UUID
        }

    recordDecoder : Decoder Record
    recordDecoder =
        Bytes.Decode.map3 Record
            (Bytes.Decode.unsignedInt16 Bytes.BE |> Bytes.Decode.andThen Bytes.Decode.string)
            (Bytes.Decode.unsignedInt32 Bytes.BE)
            UUID.decoder

    Bytes.Decode.decode recordDecoder <| fromByteValues
        [ 0x00, 0x0b -- 11
        , 0x68, 0x65, 0x6c, 0x6c, 0x6f, 0x20, 0x77, 0x6f, 0x72, 0x6c, 0x64 -- "hello world"
        , 0x00, 0x00, 0x00, 0xFF -- 255
        , 0x6b, 0xa7, 0xb8, 0x11, 0x9d, 0xad, 0x11, 0xd1, 0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8 -- UUID
        ]
    --> Just
    -->     { name = "hello world"
    -->     , value = 255
    -->     , id = urlNamespace
    -->     }

-}
decoder : Bytes.Decode.Decoder UUID
decoder =
    Bytes.Decode.Extra.onlyOks resultDecoder


resultDecoder : Bytes.Decode.Decoder (Result Error UUID)
resultDecoder =
    Bytes.Decode.map4 fromInt32s
        (Bytes.Decode.unsignedInt32 BE)
        (Bytes.Decode.unsignedInt32 BE)
        (Bytes.Decode.unsignedInt32 BE)
        (Bytes.Decode.unsignedInt32 BE)


{-| Convert a UUID to `Bytes`.

    import Bytes.Extra exposing (toByteValues)

    toBytes dnsNamespace
        |> toByteValues
    --> [0x6b, 0xa7, 0xb8, 0x10, 0x9d, 0xad, 0x11, 0xd1, 0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8]

-}
toBytes : UUID -> Bytes
toBytes =
    Bytes.Encode.encode << encoder


{-| An encoder for encoding data that includes a UUID.

    import Bytes.Extra exposing (toByteValues)
    import Bytes.Encode
    import Bytes.Encode.Extra

    defaultNamespaces : List UUID
    defaultNamespaces =
        [ dnsNamespace, urlNamespace, oidNamespace, x500Namespace ]

    Bytes.Encode.Extra.list UUID.encoder defaultNamespaces
        |> Bytes.Encode.encode
        |> toByteValues
    --> [ 0x6b, 0xa7, 0xb8, 0x10, 0x9d, 0xad, 0x11, 0xd1, 0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8
    --> , 0x6b, 0xa7, 0xb8, 0x11, 0x9d, 0xad, 0x11, 0xd1, 0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8
    --> , 0x6b, 0xa7, 0xb8, 0x12, 0x9d, 0xad, 0x11, 0xd1, 0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8
    --> , 0x6b, 0xa7, 0xb8, 0x14, 0x9d, 0xad, 0x11, 0xd1, 0x80, 0xb4, 0x00, 0xc0, 0x4f, 0xd4, 0x30, 0xc8
    --> ]

-}
encoder : UUID -> Bytes.Encode.Encoder
encoder (UUID a b c d) =
    Bytes.Encode.sequence
        [ Bytes.Encode.unsignedInt32 BE a
        , Bytes.Encode.unsignedInt32 BE b
        , Bytes.Encode.unsignedInt32 BE c
        , Bytes.Encode.unsignedInt32 BE d
        ]



-- RECOGNIZED NAMESPACES


{-| A UUID for the DNS namespace, "6ba7b810-9dad-11d1-80b4-00c04fd430c8".

    forName "elm-lang.org" dnsNamespace
        |> toString
    --> "c6d62c23-3406-5fc7-836e-9d6bef13e18c"

-}
dnsNamespace : UUID
dnsNamespace =
    UUID 0x6BA7B810 0x9DAD11D1 0x80B400C0 0x4FD430C8


{-| A UUID for the URL namespace, "6ba7b811-9dad-11d1-80b4-00c04fd430c8".

    forName "https://package.elm-lang.org" urlNamespace
        |> toString
    --> "e1dba7a5-c338-53f3-bc90-353f045447be"

-}
urlNamespace : UUID
urlNamespace =
    UUID 0x6BA7B811 0x9DAD11D1 0x80B400C0 0x4FD430C8


{-| A UUID for the [ISO object ID (OID)][oid] namespace,
"6ba7b812-9dad-11d1-80b4-00c04fd430c8".

[oid]: https://en.wikipedia.org/wiki/Object_identifier

    forName "1.2.250.1" oidNamespace
        |> toString
    --> "87a2ac60-306f-5131-b748-3787f9f55685"

-}
oidNamespace : UUID
oidNamespace =
    UUID 0x6BA7B812 0x9DAD11D1 0x80B400C0 0x4FD430C8


{-| A UUID for the [X.500 Distinguished Name (DN)][x500] namespace,
"6ba7b814-9dad-11d1-80b4-00c04fd430c8".

If you don't know what this is for, I can't help you, because I don't know
either.

[x500]: https://en.wikipedia.org/wiki/X.500

-}
x500Namespace : UUID
x500Namespace =
    UUID 0x6BA7B814 0x9DAD11D1 0x80B400C0 0x4FD430C8



-- INTERNAL CONVERSION HELPERS


toVersion : Int -> UUID -> UUID
toVersion v (UUID a b c d) =
    UUID a (Bitwise.or (Bitwise.shiftLeftBy 12 v) (Bitwise.and 0xFFFF0FFF b) |> forceUnsigned) c d


toVariant1 : UUID -> UUID
toVariant1 (UUID a b c d) =
    UUID a b (Bitwise.or 0x80000000 (Bitwise.and 0x3FFFFFFF c) |> forceUnsigned) d


fromByteValuesUnchecked : List Int -> UUID
fromByteValuesUnchecked ints =
    let
        int32 : Int -> Int -> Int -> Int -> Int
        int32 a b c d =
            d
                + Bitwise.shiftLeftBy 0x08 c
                + Bitwise.shiftLeftBy 0x10 b
                + Bitwise.shiftLeftBy 0x18 a
                |> forceUnsigned
    in
    case ints of
        [ a1, a2, a3, a4, b1, b2, b3, b4, c1, c2, c3, c4, d1, d2, d3, d4 ] ->
            UUID (int32 a1 a2 a3 a4) (int32 b1 b2 b3 b4) (int32 c1 c2 c3 c4) (int32 d1 d2 d3 d4)

        _ ->
            UUID 0 0 0 0


fromInt32s : Int -> Int -> Int -> Int -> Result Error UUID
fromInt32s a b c d =
    let
        wouldBeUUID =
            UUID a b c d
    in
    if a == 0 && b == 0 && c == 0 && d == 0 then
        Err IsNil

    else if version wouldBeUUID > 5 then
        Err NoVersion

    else if not (isVariant1 wouldBeUUID) then
        Err UnsupportedVariant

    else
        Ok wouldBeUUID


nibbleValuesToU32 : Int -> Int -> Int -> Int -> Int -> Int -> Int -> Int -> Int
nibbleValuesToU32 a b c d e f g h =
    h
        |> Bitwise.or (Bitwise.shiftLeftBy 0x04 g)
        |> Bitwise.or (Bitwise.shiftLeftBy 0x08 f)
        |> Bitwise.or (Bitwise.shiftLeftBy 0x0C e)
        |> Bitwise.or (Bitwise.shiftLeftBy 0x10 d)
        |> Bitwise.or (Bitwise.shiftLeftBy 0x14 c)
        |> Bitwise.or (Bitwise.shiftLeftBy 0x18 b)
        |> Bitwise.or (Bitwise.shiftLeftBy 0x1C a)
        |> forceUnsigned


toNibbleValue : Char -> Maybe Int
toNibbleValue char =
    case char of
        '0' ->
            Just 0

        '1' ->
            Just 1

        '2' ->
            Just 2

        '3' ->
            Just 3

        '4' ->
            Just 4

        '5' ->
            Just 5

        '6' ->
            Just 6

        '7' ->
            Just 7

        '8' ->
            Just 8

        '9' ->
            Just 9

        'a' ->
            Just 10

        'b' ->
            Just 11

        'c' ->
            Just 12

        'd' ->
            Just 13

        'e' ->
            Just 14

        'f' ->
            Just 15

        _ ->
            Nothing


toHex : List Char -> Int -> String
toHex acc int =
    if int == 0 then
        String.fromList acc

    else
        let
            char =
                case Bitwise.and 0x0F int of
                    0x00 ->
                        '0'

                    0x01 ->
                        '1'

                    0x02 ->
                        '2'

                    0x03 ->
                        '3'

                    0x04 ->
                        '4'

                    0x05 ->
                        '5'

                    0x06 ->
                        '6'

                    0x07 ->
                        '7'

                    0x08 ->
                        '8'

                    0x09 ->
                        '9'

                    0x0A ->
                        'a'

                    0x0B ->
                        'b'

                    0x0C ->
                        'c'

                    0x0D ->
                        'd'

                    0x0E ->
                        'e'

                    _ ->
                        'f'
        in
        toHex (char :: acc) (Bitwise.shiftRightZfBy 4 int)


forceUnsigned : Int -> Int
forceUnsigned =
    Bitwise.shiftRightZfBy 0
