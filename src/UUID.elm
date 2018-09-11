module UUID exposing
    ( UUID
    , Nil, nil
    , Version3, v3WithNamespace
    , dns, url, oid, x500
    , Version4, generator
    , Version1(..), Version2(..), Version5(..)
    , Variant1, Variant2
    , toVariant2
    , isNil, version, isVersion, variant, isVariant
    , canonical, microsoftGUID, urn
    , encode, decoder
    , checkVersion3, checkVersion4
    , checkVariant1, checkVariant2
    )

{-| A UUID can be used as an identifier for anything. Each 128 bit nubmer,
usually represented as 32 hexadecimal digits, is generally assumed to be
Universally Unique (hence the name).

@docs UUID


## Nil UUID

@docs Nil, nil


## UUIDs from hashes

UUIDs can be created using a namespace UUID and a name, which is then hashed to
create a UUID. The hash function used depends on the version of UUID: verison 3
UUIDs use MD5, and version 5 UUIDs use SHA-1. Currently, this package can only
create version 3 UUIDs.

@docs Version3, v3WithNamespace
@docs dns, url, oid, x500


## Random UUIDs

Randomly-generated UUIDs are defined in the version 4
UUID specification. This package provides a generator for
the [`elm/random`](https://package.elm-lang.org/packages/elm/random/latest/)
library.

@docs Version4, generator


## Unsupported versions

This module cannot currently create version 1, 2, or 5 UUIDs, but it can still
encode and decode them. As such, the following types are provided to be used as
phantom types for the UUID version.

@docs Version1, Version2, Version5


## Variants

By default, UUIDs are created as variant 1 UUIDs, but this module does have
support for variant 2 UUIDs. The following phantom types can be used to restrict
use of UUIDs to a specific variant.

@docs Variant1, Variant2

If you need to create a variant 2 UUID, any variant 1 UUID can be converted to a
variant 2 UUID with `toVariant2`. Note that variant 2 UUIDs cannot be converted
to variant 1 UUIDs.

@docs toVariant2


## Inspecting UUIDs

@docs isNil, version, isVersion, variant, isVariant


## Formatting

UUIDs are generally represented by 32 hexadecimal digits in the form
`00112233-4455-M677-N899-aabbccddeeff`, where the four bits at position `M`
denote the UUID version, and the first two or three bits at position `N` denote
the variant.

@docs canonical, microsoftGUID, urn


## JSON

UUID.encode will encode any UUID to a JSON string. UUID.decoder will decode any
valid UUID, and can be combined with one of the following functions to ensure
decoded UUIDs are a specific version or variant.

@docs encode, decoder
@docs checkVersion1, checkVersion2, checkVersion3, checkVersion4, checkVersion5
@docs checkVariant1, checkVariant2

-}

import Bitwise
import Hex
import Json.Decode
import Json.Encode
import List.Extra
import MD5
import Maybe.Extra
import Random
import Result
import String.Extra
import String.UTF8



-- TYPES


{-| Opaque type to encapsulate UUIDs. Uses [phantom types](https://medium.com/@ckoster22/advanced-types-in-elm-phantom-types-808044c5946d) to provide information about version and variant.

    type alias Model =
        { title : String
        , uuid : UUID Version4 Variant1
        , published : Maybe Date
        , authors : List (UUID Version4 Variant1)
        }

-}
type UUID version variant
    = UUID (List Int)


{-| Used to denote version and variant of the nil UUID.
-}
type Nil
    = Nil


{-| Used to denote variant 1 UUIDs.
-}
type Variant1
    = Variant1


{-| Used to denote variant 2 UUIDs.
-}
type Variant2
    = Variant2


{-| Used to denote version 1 UUIDs.
-}
type Version1
    = Version1


{-| Used to denote version 2 UUIDs.
-}
type Version2
    = Version2


{-| Used to denote version 3 UUIDs.
-}
type Version3
    = Version3


{-| Used to denote version 4 UUIDs.
-}
type Version4
    = Version4


{-| Used to denote version 5 UUIDs.
-}
type Version5
    = Version5



-- DEFINED UUIDS


{-| The nil UUID. This is the special UUID "00000000-0000-0000-0000-000000000000".
-}
nil : UUID Nil Nil
nil =
    UUID <| List.repeat 16 0x00


{-| A UUID for the DNS namespace, "6ba7b810-9dad-11d1-80b4-00c04fd430c8"
-}
dns : UUID Version1 Variant1
dns =
    UUID [ 0x6B, 0xA7, 0xB8, 0x10, 0x9D, 0xAD, 0x11, 0xD1, 0x80, 0xB4, 0x00, 0xC0, 0x4F, 0xD4, 0x30, 0xC8 ]


{-| A UUID for the URL namespace, "6ba7b811-9dad-11d1-80b4-00c04fd430c8"
-}
url : UUID Version1 Variant1
url =
    UUID [ 0x6B, 0xA7, 0xB8, 0x11, 0x9D, 0xAD, 0x11, 0xD1, 0x80, 0xB4, 0x00, 0xC0, 0x4F, 0xD4, 0x30, 0xC8 ]


{-| A UUID for the object ID (OID) namespace, "6ba7b812-9dad-11d1-80b4-00c04fd430c8"
-}
oid : UUID Version1 Variant1
oid =
    UUID [ 0x6B, 0xA7, 0xB8, 0x12, 0x9D, 0xAD, 0x11, 0xD1, 0x80, 0xB4, 0x00, 0xC0, 0x4F, 0xD4, 0x30, 0xC8 ]


{-| A UUID for the X.500 namespace, "6ba7b814-9dad1-80b4-00c04fd430c8"
-}
x500 : UUID Version1 Variant1
x500 =
    UUID [ 0x6B, 0xA7, 0xB8, 0x14, 0x9D, 0xAD, 0x11, 0xD1, 0x80, 0xB4, 0x00, 0xC0, 0x4F, 0xD4, 0x30, 0xC8 ]


{-| Encode a UUID of any version or variant as a JSON string.

    Json.Encode.encode 0 (encode 0 nil) == "\"00000000-0000-0000-0000-000000000000\""

-}
encode : UUID version variant -> Json.Encode.Value
encode =
    encodeWith canonical


{-| Encode a UUID of any version or variant as a JSON string, using a given
format function (by default, `UUID.encode` uses the `canonical` representation).

    Json.Encode.encode 0 (encodeWith urn 0 nil) == "\"{00000000-0000-0000-0000-000000000000}\""

-}
encodeWith : (UUID version variant -> String) -> UUID version variant -> Json.Encode.Value
encodeWith method =
    method >> Json.Encode.string


{-| Decodes a UUID of any version or variant from a JSON string.

    "\"123e4567-e89b-12d3-a456-426655440000\""
        |> Json.Decode.decodeString decoder
        |> canonical -- == "123e4567-e89b-12d3-a456-426655440000"

-}
decoder : Json.Decode.Decoder (UUID version variant)
decoder =
    Json.Decode.string |> Json.Decode.andThen stringToUUID


{-| Convert UUID to [canonical textual representation](https://en.wikipedia.org/wiki/Universally_unique_identifier#Format)

    canonical nil == "00000000-0000-0000-0000-000000000000"

-}
canonical : UUID version variant -> String
canonical (UUID bytes) =
    let
        strings =
            bytes
                |> List.map Hex.toString
                |> List.map (String.padLeft 2 '0')
                |> String.concat
                |> String.Extra.break 4
    in
    case strings of
        a :: b :: c :: d :: e :: f :: g :: h :: [] ->
            a ++ b ++ "-" ++ c ++ "-" ++ d ++ "-" ++ e ++ "-" ++ f ++ g ++ h

        _ ->
            "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"


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


asBytes : UUID version variant -> List Int
asBytes (UUID bytes) =
    bytes


fromBytes : List Int -> Result String (UUID version variant)
fromBytes bytes =
    if List.any (\x -> x < 0 || x > 15) bytes then
        Err "At least one integer given represented more than 1 byte"

    else if List.length bytes > 16 then
        Err "Too many bytes were given"

    else if List.length bytes < 16 then
        Err "Not enough bytes were given"

    else
        Ok <| UUID bytes


generator : Random.Generator (UUID Version4 Variant1)
generator =
    Random.int 0 255
        |> Random.list 16
        |> Random.map UUID
        |> Random.map toVersion4
        |> Random.map toVariant1



-- CHECKING VERSION/VARIANT


checkVariant1 : UUID version variant -> Json.Decode.Decoder (UUID version Variant1)
checkVariant1 =
    checkVariant Variant1 1


checkVariant2 : UUID version variant -> Json.Decode.Decoder (UUID version Variant2)
checkVariant2 =
    checkVariant Variant2 2


checkVariant : variant -> Int -> UUID version anyVariant -> Json.Decode.Decoder (UUID version variant)
checkVariant _ var uuid =
    if variant uuid == Just var then
        Json.Decode.succeed <| UUID <| asBytes uuid

    else
        Json.Decode.fail <| "UUID not variant " ++ String.fromInt var


checkVersion3 : UUID version variant -> Json.Decode.Decoder (UUID Version3 variant)
checkVersion3 =
    checkVersion Version3 3


checkVersion4 : UUID version variant -> Json.Decode.Decoder (UUID Version4 variant)
checkVersion4 =
    checkVersion Version4 4


checkVersion : version -> Int -> UUID anyVersion variant -> Json.Decode.Decoder (UUID version variant)
checkVersion _ ver uuid =
    if version uuid == Just ver then
        Json.Decode.succeed <| UUID <| asBytes uuid

    else
        Json.Decode.fail <| "UUID not Version " ++ String.fromInt ver


toVersion3 : UUID version variant -> UUID Version3 variant
toVersion3 =
    toVersion Version3 3


toVersion4 : UUID version variant -> UUID Version4 variant
toVersion4 =
    toVersion Version4 4


toVersion : version -> Int -> UUID anyVersion variant -> UUID version variant
toVersion _ ver (UUID bytes) =
    let
        versionBits =
            ver
                |> Bitwise.and 0x0F
                |> Bitwise.shiftLeftBy 4
    in
    UUID <| List.Extra.updateAt 6 (Bitwise.and 0x0F >> Bitwise.or versionBits) bytes


toVariant1 : UUID version variant -> UUID version Variant1
toVariant1 =
    toVariant Variant1 1


{-| Variant 2 UUIDs are very similar to variant 1 UUIDs, the main end-user different being that they provide 1 fewer bit of randomness, vut are a Microsoft standard.
-}
toVariant2 : UUID version variant -> UUID version Variant2
toVariant2 =
    toVariant Variant2 2


toVariant : variant -> Int -> UUID version anyVariant -> UUID version variant
toVariant _ var (UUID bytes) =
    UUID <| List.Extra.updateAt 8 (setVariantBits var) bytes


setVariantBits : Int -> Int -> Int
setVariantBits var =
    case var of
        1 ->
            Bitwise.and 0x3F >> Bitwise.or 0x80

        2 ->
            Bitwise.and 0x1F >> Bitwise.or 0xC0

        _ ->
            identity


stringToUUID : String -> Json.Decode.Decoder (UUID version variant)
stringToUUID string =
    let
        ints =
            string
                |> String.replace "-" ""
                |> String.toLower
                |> String.Extra.break 2
                |> List.map (Hex.fromString >> Result.toMaybe)
    in
    if List.any ((==) Nothing) ints then
        Json.Decode.fail "UUID contained non-hexadecimal digits"

    else if List.length ints /= 16 then
        Json.Decode.fail "UUID was not correct length"

    else
        ints
            |> Maybe.Extra.values
            |> UUID
            |> Json.Decode.succeed


{-| Version 3 UUIDs are generated using an MD5 hash of an existing "namespace" UUID and a name.

    "hello"
        |> v3WithNamespace nil
        |> UUID.canonical -- == "a6c0426f-f9a3-3b59-a62f-4807c382b768"

-}
v3WithNamespace : UUID version variant -> String -> UUID Version3 Variant1
v3WithNamespace uuid =
    withHashedNamespace MD5.hexInOctets uuid
        >> toVersion3
        >> toVariant1


withHashedNamespace : (String -> List Int) -> UUID version variant -> String -> UUID version variant
withHashedNamespace hashFn (UUID namespaceBytes) name =
    let
        namespaceString =
            namespaceBytes
                |> String.UTF8.toString
                |> Result.withDefault ""

        digest =
            hashFn (namespaceString ++ name)
    in
    namespaceBytes
        |> (++) digest
        |> List.take 16
        |> UUID



-- INSPECTING


version : UUID version variant -> Maybe Int
version (UUID bytes) =
    bytes
        |> List.drop 6
        |> List.head
        |> Maybe.map (Bitwise.shiftRightZfBy 4)


variant : UUID version variant -> Maybe Int
variant (UUID bytes) =
    bytes
        |> List.drop 8
        |> List.head
        |> Maybe.map (Bitwise.shiftRightZfBy 5)
        |> Maybe.Extra.filter (\v -> v >= 4 && v <= 6)
        |> Maybe.map (\v -> (v // 2) - 1)


isVersion : Int -> UUID version variant -> Bool
isVersion v uuid =
    version uuid == Just v


isVariant : Int -> UUID version variant -> Bool
isVariant v uuid =
    variant uuid == Just v


isNil : UUID version variant -> Bool
isNil (UUID bytes) =
    UUID bytes == nil
