module UUID exposing
    ( UUID
    , Version1, Version2, Version3, Version4, Version5
    , Variant1, Variant2
    , nil
    , canonical, microsoftGUID, urn
    , generator
    , v3WithNamespace
    , dns, url, oid, x500
    , toVariant2
    , isNil, version, isVersion, variant, isVariant
    , encode, decoder
    , checkVersion1, checkVersion2, checkVersion3, checkVersion4, checkVersion5
    , checkVariant1, checkVariant2
    )

{-| A UUID looks something like `e1631449-6321-4a58-920c-5440029b092e`, and can
be used as an identifier for anything. Each 128-bit number, usually represented
as 32 hexadecimal digits, is generally assumed to be Universally Unique (hence
the name).

@docs UUID

UUIDs have version numbers (1-5) and variant numbers (1-2). In the above
example, the UUIDs used are version 4 (which means they're randomly generated),
and variant 1. If you need to specify a specific version or variant your UUIDs
should be, this can be done with the [phantom types] associated with the UUID.
For example, if you do not mind which version your UUID uses, but it needs to be
variant 1, the type you will need is `UUID version Variant1`. If you do not care
which version _or_ variant your UUID is, just use `UUID version  variant`, or
`UUID a b` for short.

[phantom types]: https://medium.com/@ckoster22/advanced-types-in-elm-phantom-types-808044c5946d

A phantom type is defined for each available version and variant:

@docs Version1, Version2, Version3, Version4, Version5
@docs Variant1, Variant2


## Nil UUID

@docs nil


## Formatting

UUIDs are generally represented by 32 hexadecimal digits in the form
`00112233-4455-M677-N899-aabbccddeeff`, where the four bits at position `M`
denote the UUID version, and the first two or three bits at position `N` denote
the variant.

@docs canonical, microsoftGUID, urn


## Random UUIDs (Version 4)

Randomly-generated UUIDs are called version 4 UUIDs. This package provides a
`Random.Generator` for the [`elm/random`][elm-random] library.

[elm-random]: https://package.elm-lang.org/packages/elm/random/latest/

@docs generator


## Hierarchical, namespaced UUIDs (Version 3, Version 5)

UUIDs can be created using a namespace UUID and a name, which is then hashed to
create a new UUID. The hash function used depends on the version of UUID:
verison 3 UUIDs use MD5, and version 5 UUIDs use SHA-1. **Currently, this
package can only create version 3 UUIDs.**

Once generated, these UUIDs can then be used as a namespace, making a hierarchy!
I think this is pretty cool! You can use this method for making predictable
UUIDs from data, and it also has the added bonus that you don't have to deal
with random generators/seeds.

@docs v3WithNamespace

The [RFC defining UUIDs][rfc] defines some [base UUIDs][appendix-c] to start
your hierarchy.

[rfc]: https://tools.ietf.org/html/rfc4122
[appendix-c]: https://tools.ietf.org/html/rfc4122#appendix-C

@docs dns, url, oid, x500


## Using variant 2 UUIDs

You may have noticed that `generator` and `v3WithNamespace` make variant 1
UUIDs. If you need to create a variant 2 UUID, any UUID can be converted to a
variant 2 UUID with `toVariant2`. Note that variant 2 UUIDs cannot be converted
to variant 1 UUIDs.

@docs toVariant2


## Inspecting UUIDs

@docs isNil, version, isVersion, variant, isVariant


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


{-| This modules provides a UUID type, and functions to work with them. The
`UUID version variant` type is an [opaque type], which basically means you have
to use the provided functions if you want to do anything with it!

[opaque type]: https://medium.com/@ckoster22/advanced-types-in-elm-opaque-types-ec5ec3b84ed2

Here is an example of a `Book` model, which uses UUIDs to identify both the book
and its authors:

    type alias Book =
        { title : String
        , uuid : UUID Version4 Variant1
        , published : Maybe Date
        , authors : List (UUID Version4 Variant1)
        }

-}
type UUID version variant
    = UUID (List Int)


{-| -}
type Variant1
    = Variant1


{-| -}
type Variant2
    = Variant2


{-| -}
type Version1
    = Version1


{-| -}
type Version2
    = Version2


{-| -}
type Version3
    = Version3


{-| -}
type Version4
    = Version4


{-| -}
type Version5
    = Version5



-- DEFINED UUIDS


{-| One type of UUID not defined above is the nil UUID. This is a ["special form
of UUID"][nil-rfc] defined as "00000000-0000-0000-0000-000000000000". I suppose
it can be used as a placeholder for something that doesn't have a UUID yet?

[nil-rfc]: https://tools.ietf.org/html/rfc4122#section-4.1.7

-}
nil : UUID version variant
nil =
    UUID <| List.repeat 16 0x00


{-| A UUID for the DNS namespace, "6ba7b810-9dad-11d1-80b4-00c04fd430c8".

    v3WithNamespace UUID.dns "elm-lang.org"

-}
dns : UUID Version1 Variant1
dns =
    UUID [ 0x6B, 0xA7, 0xB8, 0x10, 0x9D, 0xAD, 0x11, 0xD1, 0x80, 0xB4, 0x00, 0xC0, 0x4F, 0xD4, 0x30, 0xC8 ]


{-| A UUID for the URL namespace, "6ba7b811-9dad-11d1-80b4-00c04fd430c8"

    v3WithNamespace UUID.url "https://package.elm-lang.org"

-}
url : UUID Version1 Variant1
url =
    UUID [ 0x6B, 0xA7, 0xB8, 0x11, 0x9D, 0xAD, 0x11, 0xD1, 0x80, 0xB4, 0x00, 0xC0, 0x4F, 0xD4, 0x30, 0xC8 ]


{-| A UUID for the [ISO object ID (OID)][oid] namespace,
"6ba7b812-9dad-11d1-80b4-00c04fd430c8". I am not going to try to explain what an
OID is, if you need to use this, you probably have a better grasp of them than I
do!

[oid]: https://en.wikipedia.org/wiki/Object_identifier

    v3WithNamespace UUID.oid "1.2.250.1"

-}
oid : UUID Version1 Variant1
oid =
    UUID [ 0x6B, 0xA7, 0xB8, 0x12, 0x9D, 0xAD, 0x11, 0xD1, 0x80, 0xB4, 0x00, 0xC0, 0x4F, 0xD4, 0x30, 0xC8 ]


{-| A UUID for the [X.500 Distinguished Name (DN)][x500] namespace,
"6ba7b814-9dad-11d1-80b4-00c04fd430c8". I am not going to try to explain what a
X.500 DN is, if you need to use this, you probably have a better grasp of them
than I do!

[x500]: https://en.wikipedia.org/wiki/X.500

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


{-| Decodes a UUID of any version or variant from a JSON string. The decoder is
intentionally pretty lenient, so should be able to successfully decode any UUID
string, as long as it only contains 32 hexadecimal digits in uppercase or
lowercase, and any amount of curly braces, hyphens, spaces or "<urn:uuid:">.

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


{-| Generating a random UUID is, I think, the most straightforward way of making a UUID, and I see them used all the time. There are a couple of ways of using a generator to create a value, which are described nicely in the [elm/random docs][elm-random]. Here is an example of how you might use the UUID generator:

[elm-random]: https://package.elm-lang.org/packages/elm/random/latest/

    type Comment
        = Comment String (UUID Version4 Variant1)

    makeComment : String -> Random.Seed -> ( Comment, Random.Seed )
    makeComment comment seed =
        UUID.generator
            |> Random.map (Comment comment)
            |> Random.step seed

-}
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


checkVersion1 : UUID version variant -> Json.Decode.Decoder (UUID Version1 variant)
checkVersion1 =
    checkVersion Version1 1


checkVersion2 : UUID version variant -> Json.Decode.Decoder (UUID Version2 variant)
checkVersion2 =
    checkVersion Version2 2


checkVersion3 : UUID version variant -> Json.Decode.Decoder (UUID Version3 variant)
checkVersion3 =
    checkVersion Version3 3


checkVersion4 : UUID version variant -> Json.Decode.Decoder (UUID Version4 variant)
checkVersion4 =
    checkVersion Version4 4


checkVersion5 : UUID version variant -> Json.Decode.Decoder (UUID Version5 variant)
checkVersion5 =
    checkVersion Version5 5


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


{-| Variant 2 UUIDs are very similar to variant 1 UUIDs, the main _end-user_
difference being that they provide 1 fewer bit of randomness, but are a
Microsoft standard. Note the single digit change in the following example:

    -- c72c207b-0847-386d-bdbc-2e5def81cf81 : UUID Version3 Variant1
    var1UUID =
        "hello world" |> v3WithNamespace nil


    -- c72c207b-0847-386d-ddbc-2e5def81cf81 : UUID Version3 Variant2
    var2UUID =
        var1UUID |> toVariant2

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
                |> String.toLower
                |> String.replace "-" ""
                |> String.replace "urn:uuid:" ""
                |> String.replace "{" ""
                |> String.replace "}" ""
                |> String.replace " " ""
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


{-| Start with an existing UUID as a "parent" UUID, and provide a name to create a new UUID.

    grandparent = nil
    parent = v3WithNamespace grandparent "parent"
    parentsSibling = v3WithNamespace grandparent "parent's sibling"
    child1 = v3WithNamespace parent "child1"
    child2 = v3WithNamespace parent "child2"
    cousin = v3WithNamespace otherParent "cousin"

    UUID.canonical child2 == "4cacaf93-fcc5-3a02-bc41-c0a3e359e11d"

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


{-| If the bits of the UUID indicate that it is properly versioned UUID e.g. version 1,
returns e.g. `Just 1`. Otherwise, `Nothing`!

    version nil == Nothing

    version (v3WithNamespace nil "Hello") == Just 3

-}
version : UUID version variant -> Maybe Int
version (UUID bytes) =
    bytes
        |> List.drop 6
        |> List.head
        |> Maybe.map (Bitwise.shiftRightZfBy 4)
        |> Maybe.Extra.filter (\v -> v <= 5 && v >= 1)


{-| If the bits of the UUID indicate that it is a variant 1 or 2 UUID, returns
`Just 1` or `Just 2`, respectively. Otherwise, `Nothing`!

    version nil == Nothing

    version (v3WithNamespace nil "Hello") == Just 1

-}
variant : UUID version variant -> Maybe Int
variant (UUID bytes) =
    bytes
        |> List.drop 8
        |> List.head
        |> Maybe.map (Bitwise.shiftRightZfBy 5)
        |> Maybe.Extra.filter (\v -> v >= 4 && v <= 6)
        |> Maybe.map (\v -> (v // 2) - 1)


{-| `True` if the given UUID is the given version number. Always `False` is the
integer provided is not 1, 2, 3, 4 or 5! This function checks the actual bits of
the UUID, not the phantom type.

    isVersion 8 someUUID -- always False!

    isVersion 4 nil -- False!

    someJsonValue
        |> Json.Decode.decodeValue UUID.decoder
        |> UUID.isVersion 5

    isVersion 3 (v3WithNamespace nil "hello") -- True

-}
isVersion : Int -> UUID version variant -> Bool
isVersion v uuid =
    version uuid == Just v


{-| `True` if the given UUID is the given variant number. Always `False` is the
integer provided is not 1 or 2! This function checks the actual bits of the
UUID, not the phantom type.

    isVariant 4 someUUID -- always False!

    someJsonValue
        |> Json.Decode.decodeValue UUID.decoder
        |> UUID.isVariant 1

    isVariant 2 (someUUID |> toVariant2) -- True

-}
isVariant : Int -> UUID version variant -> Bool
isVariant v uuid =
    variant uuid == Just v


{-| `True` if the given UUID is "00000000-0000-0000-0000-000000000000".
-}
isNil : UUID version variant -> Bool
isNil (UUID bytes) =
    UUID bytes == nil
