module UUID exposing
    ( UUID
    , nil
    , generator
    , v3ChildNamed
    , dns, url, oid, x500
    , toVariant2
    , fromString
    , toString, canonical, microsoftGUID, urn
    , isNil, version, isVersion, variant, isVariant
    , checkVersion, checkVariant, checkNotNil
    )

{-| A UUID looks something like `e1631449-6321-4a58-920c-5440029b092e`, and can
be used as an identifier for anything. Each 128-bit number, usually represented
as 32 hexadecimal digits, is generally assumed to be Universally Unique (hence
the name).

@docs UUID


## Creating UUIDs

UUIDs have version numbers (1-5), which describe how they were created, and
variant numbers (1-2) which describes how they are stored. This module can read
all UUIDs, but can only currently create versions 3 (a namespaced, heirarchical
system) and 4 (a randomly-generated UUID). It creates variant 1 UUIDs (probably
the best choice if you don't have a specific need for variant 2), but can
convert them to variant 2.


### Nil UUID

@docs nil


### Random UUIDs (Version 4)

Randomly-generated UUIDs are called version 4 UUIDs. This package provides a
`Random.Generator` for the [`elm/random`][elm-random] library.

[elm-random]: https://package.elm-lang.org/packages/elm/random/latest/

@docs generator


### Hierarchical, namespaced UUIDs (Version 3, Version 5)

UUIDs can be created using a namespace UUID and a name, which is then hashed to
create a new UUID. The hash function used depends on the version of UUID:
verison 3 UUIDs use MD5, and version 5 UUIDs use SHA-1. **Currently, this
package can only create version 3 UUIDs.**

Once generated, these UUIDs can then be used as a namespace, making a hierarchy!
I think this is pretty cool! You can use this method for making predictable
UUIDs from data, and it also has the added bonus that you don't have to deal
with random generators/seeds.

@docs v3ChildNamed

The [RFC defining UUIDs][rfc] defines some [base UUIDs][appendix-c] to start
your hierarchy.

[rfc]: https://tools.ietf.org/html/rfc4122
[appendix-c]: https://tools.ietf.org/html/rfc4122#appendix-C

@docs dns, url, oid, x500


### Making variant 2 UUIDs

You may have noticed that `generator` and `v3ChildNamed` make variant 1
UUIDs. If you need to create a variant 2 UUID, any UUID can be converted to a
variant 2 UUID with `toVariant2`. Note that variant 2 UUIDs cannot be converted
to variant 1 UUIDs.

@docs toVariant2


### Existing UUIDs

@docs fromString


## Formatting

UUIDs are generally represented by 32 hexadecimal digits in the form
`00112233-4455-M677-N899-aabbccddeeff`, where the four bits at position `M`
denote the UUID version, and the first two or three bits at position `N` denote
the variant. This is the "canonical" representation, but there is also a
Microsoft GUID representation and a URN representation.

@docs toString, canonical, microsoftGUID, urn


## Inspecting UUIDs

Sometimes you may need to check a UUID's version, variant, or whether it's nil.

@docs isNil, version, isVersion, variant, isVariant

Sometimes you may need to ensure that a UUID is definitely a certain version or
variant. If you're decoding from JSON, you may find the following functions
useful in conjunction with [json-extra's fromResult function][fromResult].

[fromResult]: https://package.elm-lang.org/packages/elm-community/json-extra/latest/Json-Decode-Extra#fromResult

    uuidDecoder =
        Json.Decode.string
            |> Json.Decode.andThen (Json.Decode.Extra.fromResult << UUID.fromString)
            |> Json.Decode.andThen (Json.Decode.Extra.fromResult << UUID.checkVersion 4)
            |> Json.Decode.andThen (Json.Decode.Extra.fromResult << UUID.checkVariant 1)

@docs checkVersion, checkVariant, checkNotNil

-}

import Bitwise
import Hex
import List.Extra
import MD5
import Maybe.Extra
import Random
import Result exposing (Result)
import String.Extra
import String.UTF8



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
    = UUID (List Int)



-- DEFINED UUIDS


{-| One type of UUID not defined above is the nil UUID. This is a ["special form
of UUID"][nil-rfc] defined as "00000000-0000-0000-0000-000000000000". I suppose
it can be used as a placeholder for something that doesn't have a UUID yet?

[nil-rfc]: https://tools.ietf.org/html/rfc4122#section-4.1.7

-}
nil : UUID
nil =
    UUID (List.repeat 16 0x00)


{-| A UUID for the DNS namespace, "6ba7b810-9dad-11d1-80b4-00c04fd430c8".

    UUID.dns |> v3ChildNamed "elm-lang.org"

-}
dns : UUID
dns =
    UUID [ 0x6B, 0xA7, 0xB8, 0x10, 0x9D, 0xAD, 0x11, 0xD1, 0x80, 0xB4, 0x00, 0xC0, 0x4F, 0xD4, 0x30, 0xC8 ]


{-| A UUID for the URL namespace, "6ba7b811-9dad-11d1-80b4-00c04fd430c8"

    UUID.url |> v3ChildNamed "https://package.elm-lang.org"

-}
url : UUID
url =
    UUID [ 0x6B, 0xA7, 0xB8, 0x11, 0x9D, 0xAD, 0x11, 0xD1, 0x80, 0xB4, 0x00, 0xC0, 0x4F, 0xD4, 0x30, 0xC8 ]


{-| A UUID for the [ISO object ID (OID)][oid] namespace,
"6ba7b812-9dad-11d1-80b4-00c04fd430c8". I am not going to try to explain what an
OID is, if you need to use this, you probably have a better grasp of them than I
do!

[oid]: https://en.wikipedia.org/wiki/Object_identifier

    UUID.oid |> v3ChildNamed "1.2.250.1"

-}
oid : UUID
oid =
    UUID [ 0x6B, 0xA7, 0xB8, 0x12, 0x9D, 0xAD, 0x11, 0xD1, 0x80, 0xB4, 0x00, 0xC0, 0x4F, 0xD4, 0x30, 0xC8 ]


{-| A UUID for the [X.500 Distinguished Name (DN)][x500] namespace,
"6ba7b814-9dad-11d1-80b4-00c04fd430c8". I am not going to try to explain what a
X.500 DN is, if you need to use this, you probably have a better grasp of them
than I do!

[x500]: https://en.wikipedia.org/wiki/X.500

-}
x500 : UUID
x500 =
    UUID [ 0x6B, 0xA7, 0xB8, 0x14, 0x9D, 0xAD, 0x11, 0xD1, 0x80, 0xB4, 0x00, 0xC0, 0x4F, 0xD4, 0x30, 0xC8 ]



-- FORMATTING


{-| This is just an alias for `canonical`, the most common way to represent a UUID.

    canonical someUUID == toString someUUID

-}
toString : UUID -> String
toString =
    canonical


{-| Convert UUID to [canonical textual representation](https://en.wikipedia.org/wiki/Universally_unique_identifier#Format)

    canonical nil == "00000000-0000-0000-0000-000000000000"

-}
canonical : UUID -> String
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
microsoftGUID : UUID -> String
microsoftGUID uuid =
    "{" ++ canonical uuid ++ "}"


{-| Convert UUID to [URN-namespaced representation](https://en.wikipedia.org/wiki/Universally_unique_identifier#Format)

    urn nil == "urn:uuid:00000000-0000-0000-0000-000000000000"

-}
urn : UUID -> String
urn uuid =
    "urn:uuid:" ++ canonical uuid


fromBytes : List Int -> Result String UUID
fromBytes bytes =
    if List.any (\x -> x < 0 || x > 15) bytes then
        Err "At least one integer given represented more than 1 byte"

    else if List.length bytes > 16 then
        Err "Too many bytes were given"

    else if List.length bytes < 16 then
        Err "Not enough bytes were given"

    else
        Ok (UUID bytes)


{-| Generating a random UUID is, I think, the most straightforward way of making a UUID, and I see them used all the time. There are a couple of ways of using a generator to create a value, which are described nicely in the [elm/random docs][elm-random]. Here is an example of how you might use the UUID generator:

[elm-random]: https://package.elm-lang.org/packages/elm/random/latest/

    type Comment
        = Comment String UUID

    makeComment : String -> Random.Seed -> ( Comment, Random.Seed )
    makeComment comment seed =
        UUID.generator
            |> Random.map (Comment comment)
            |> Random.step seed

-}
generator : Random.Generator UUID
generator =
    Random.int 0 255
        |> Random.list 16
        |> Random.map UUID
        |> Random.map (toVersion 4)
        |> Random.map (toVariant 1)



-- CHECKING VERSION/VARIANT


{-| Check which variant a UUID is, and if it's not the right one, return an `Err`.

    (nil |> v3ChildNamed "hello" |> checkVariant 2) == Err "UUID is not variant 2"

    (nil |> checkVariant 2) == Err "UUID does not define a valid variant"

    (someVariant1UUID |> checkVariant 1) == Ok someVariant1UUID

-}
checkVariant : Int -> UUID -> Result String UUID
checkVariant v uuid =
    case Maybe.map ((==) v) (variant uuid) of
        Just True ->
            Ok uuid

        Just False ->
            Err ("UUID is not variant " ++ String.fromInt v)

        Nothing ->
            Err "UUID does not define a valid variant"


{-| Check which version a UUID is, and if it's not the right one, return an `Err`.

    (nil |> v3ChildNamed "hello" |> checkVersion 4) == Err "UUID is not Version 4"

    (nil |> checkVersion 1) == Err "UUID does not define a valid version"

    (someVersion4UUID |> checkVersion 4) == Ok someVersion4UUID

-}
checkVersion : Int -> UUID -> Result String UUID
checkVersion v uuid =
    case Maybe.map ((==) v) (version uuid) of
        Just True ->
            Ok uuid

        Just False ->
            Err ("UUID not Version " ++ String.fromInt v)

        Nothing ->
            Err "UUID does not define a valid version"


{-| A simple function to use while chaining `Result`s. Makes sure the UUID
you're dealing with isn't the Nil UUID!

    uuid =
        someString
            |> UUID.fromString
            |> Result.andThen (UUID.checkNotNil 4)

-}
checkNotNil : UUID -> Result String UUID
checkNotNil uuid =
    if isNil uuid then
        Err "UUID is nil"

    else
        Ok uuid


toVersion : Int -> UUID -> UUID
toVersion v (UUID bytes) =
    let
        updateFn =
            v
                |> Bitwise.and 0x0F
                |> Bitwise.shiftLeftBy 4
                |> Bitwise.or
                |> (>>) (Bitwise.and 0x0F)
                |> List.Extra.updateAt 6
    in
    UUID (updateFn bytes)


{-| Variant 2 UUIDs are very similar to variant 1 UUIDs, the main _end-user_
difference being that they provide 1 fewer bit of randomness, but are a
Microsoft standard. Note the single digit change in the following example:

    -- c72c207b-0847-386d-bdbc-2e5def81cf81
    var1UUID =
        nil |> v3ChildNamed "hello world"


    -- c72c207b-0847-386d-ddbc-2e5def81cf81
    var2UUID =
        var1UUID |> toVariant2

-}
toVariant2 : UUID -> UUID
toVariant2 =
    toVariant 2


toVariant : Int -> UUID -> UUID
toVariant v (UUID bytes) =
    UUID (List.Extra.updateAt 8 (setVariantBits v) bytes)


setVariantBits : Int -> Int -> Int
setVariantBits v =
    case v of
        1 ->
            Bitwise.and 0x3F >> Bitwise.or 0x80

        2 ->
            Bitwise.and 0x1F >> Bitwise.or 0xC0

        _ ->
            identity


{-| You can attempt to create a UUID from a string. This function can interpret
a fairly broad range of formatted (and mis-formatted) UUIDs, including ones with
too much whitespace, too many (or not enough) hyphens, or uppercase characters.

    fromString "c72c207b-0847-386d-bdbc-2e5def81cf811" == Err "UUID was not correct length"

    fromString "c72c207b-0847-386d-bdbc-2e5def81cg81" == Err "UUID contained non-hexadecimal digits"

    fromString "00000000-0000-0000-0000-000000000000" == Ok nil

    fromString "urn:uuid:00000000-0000-0000-0000-000000000000" == Ok nil

    fromString "{00000000-0000-0000-0000-000000000000}" == Ok nil

    fromString "\n\n     {urn:uuid: 00  000000-0000-0000-0-000-000000000000}" == Ok nil

**Note:** if you are decoding from JSON, you may like [json-extra's fromResult function][fromResult].

[fromResult]: https://package.elm-lang.org/packages/elm-community/json-extra/latest/Json-Decode-Extra#fromResult

    uuidDecoder =
        Json.Decode.string
            |> Json.Decode.andThen (Json.Decode.Extra.fromResult << UUID.fromString)

-}
fromString : String -> Result String UUID
fromString =
    String.toLower
        >> String.trim
        >> String.replace " " ""
        >> String.replace "-" ""
        >> (\string ->
                if String.startsWith "{" string && String.endsWith "}" string then
                    String.slice 1 -1 string

                else
                    string
           )
        >> (\string ->
                if String.startsWith "urn:uuid:" string then
                    String.dropLeft 9 string

                else
                    string
           )
        >> String.Extra.break 2
        >> List.map (Hex.fromString >> Result.toMaybe)
        >> (\ints ->
                if List.any ((==) Nothing) ints then
                    Err "UUID contained non-hexadecimal digits"

                else if List.length ints /= 16 then
                    Err "UUID was not correct length"

                else
                    Ok (UUID (Maybe.Extra.values ints))
           )


{-| Start with an existing UUID as a "parent" UUID, and provide a name to create a new UUID.

    grandparent = nil
    parent = grandparent |> v3ChildNamed "parent"
    parentsSibling = grandparent |> v3ChildNamed "parent's sibling"
    child1 = parent |> v3ChildNamed "child1"
    child2 = parent |> v3ChildNamed "child2"
    cousin = parentsSibling |> v3ChildNamed "cousin"

    UUID.canonical child2 == "4cacaf93-fcc5-3a02-bc41-c0a3e359e11d"

-}
v3ChildNamed : String -> UUID -> UUID
v3ChildNamed name =
    childNamedUsingHash MD5.bytes name
        >> toVersion 3
        >> toVariant 1


childNamedUsingHash : (String -> List Int) -> String -> UUID -> UUID
childNamedUsingHash hashFn name (UUID namespaceBytes) =
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

    version (nil |> v3ChildNamed "Hello") == Just 3

-}
version : UUID -> Maybe Int
version (UUID bytes) =
    bytes
        |> List.drop 6
        |> List.head
        |> Maybe.map (Bitwise.shiftRightZfBy 4)
        |> Maybe.Extra.filter (\v -> v <= 5 && v >= 1)


{-| If the bits of the UUID indicate that it is a variant 1 or 2 UUID, returns
`Just 1` or `Just 2`, respectively. Otherwise, `Nothing`!

    variant nil == Nothing

    variant (nil |> v3ChildNamed "Hello") == Just 1

-}
variant : UUID -> Maybe Int
variant (UUID bytes) =
    bytes
        |> List.drop 8
        |> List.head
        |> Maybe.map (Bitwise.shiftRightZfBy 5)
        |> Maybe.Extra.filter (\v -> v >= 4 && v <= 6)
        |> Maybe.map (\v -> (v // 2) - 1)


{-| `True` if the given UUID is the given version number. Always `False` is the
integer provided is not 1, 2, 3, 4 or 5!

    isVersion 8 someUUID -- always False!

    isVersion 4 nil -- False!

    someJsonValue
        |> Json.Decode.decodeValue UUID.decoder
        |> UUID.isVersion 5

    isVersion 3 (nil |> v3ChildNamed "hello") -- True

-}
isVersion : Int -> UUID -> Bool
isVersion v uuid =
    version uuid == Just v


{-| `True` if the given UUID is the given variant number. Always `False` is the
integer provided is not 1 or 2!

    isVariant 4 someUUID -- Always False, variant 4 doesn't exist!

    someJsonValue
        |> Json.Decode.decodeValue UUID.decoder
        |> UUID.isVariant 1

    isVariant 2 (someUUID |> toVariant2) -- True

-}
isVariant : Int -> UUID -> Bool
isVariant v uuid =
    variant uuid == Just v


{-| `True` if the given UUID is "00000000-0000-0000-0000-000000000000".
-}
isNil : UUID -> Bool
isNil =
    (==) nil
