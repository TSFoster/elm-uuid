module Internal.UUID exposing
    ( Nil
    , UUID
    , Variant1
    , Variant2
    , Version3
    , Version4
    , canonical
    , checkVariant1
    , checkVariant2
    , checkVersion3
    , checkVersion4
    , decoder
    , encode
    , generator
    , nil
    , setVariant1
    , setVariant2
    , setVersion3
    , setVersion4
    , withHashedNamespace
    )

import Bitwise
import Hex
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import List.Extra
import Maybe.Extra
import Random exposing (Generator)
import Result
import String.Extra
import String.UTF8


type UUID version variant
    = UUID (List Int)


type Variant1
    = Variant1


type Variant2
    = Variant2


type Version3
    = Version3


type Version4
    = Version4


type Nil
    = Nil


asBytes : UUID version variant -> List Int
asBytes (UUID bytes) =
    bytes


fromBytes : List Int -> Maybe (UUID version variant)
fromBytes bytes =
    if List.length bytes /= 16 then
        Nothing

    else if List.any (\x -> x < 0 || x > 15) bytes then
        Nothing

    else
        Just <| UUID bytes


nil : UUID Nil Nil
nil =
    UUID <| List.repeat 16 0x00


generator : Generator (UUID version variant)
generator =
    Random.int 0 255
        |> Random.list 16
        |> Random.map UUID


checkVariant1 : UUID version variant -> Decoder (UUID version Variant1)
checkVariant1 =
    checkVariant Variant1 1


checkVariant2 : UUID version variant -> Decoder (UUID version Variant2)
checkVariant2 =
    checkVariant Variant2 2


checkVariant : variant -> Int -> UUID version anyVariant -> Decoder (UUID version variant)
checkVariant phantomType var uuid =
    if variant uuid == Just var then
        Decode.succeed <| forceVariant phantomType uuid

    else
        Decode.fail <| "UUID not variant " ++ String.fromInt var


checkVersion3 : UUID version variant -> Decoder (UUID Version3 variant)
checkVersion3 =
    checkVersion Version3 3


checkVersion4 : UUID version variant -> Decoder (UUID Version4 variant)
checkVersion4 =
    checkVersion Version4 4


checkVersion : version -> Int -> UUID anyVersion variant -> Decoder (UUID version variant)
checkVersion phantomType ver uuid =
    if version uuid == Just ver then
        Decode.succeed <| forceVersion phantomType uuid

    else
        Decode.fail <| "UUID not Version " ++ String.fromInt ver


forceVariant : variant -> UUID version anyVariant -> UUID version variant
forceVariant _ (UUID bytes) =
    UUID bytes


forceVersion : version -> UUID anyVersion variant -> UUID version variant
forceVersion _ (UUID bytes) =
    UUID bytes


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


setVersion3 : UUID version variant -> UUID Version3 variant
setVersion3 =
    setVersion Version3 3


setVersion4 : UUID version variant -> UUID Version4 variant
setVersion4 =
    setVersion Version4 4


setVersion : version -> Int -> UUID anyVersion variant -> UUID version variant
setVersion _ ver (UUID bytes) =
    let
        versionBits =
            ver
                |> Bitwise.and 0x0F
                |> Bitwise.shiftLeftBy 4
    in
    UUID <| List.Extra.updateAt 6 (Bitwise.and 0x0F >> Bitwise.or versionBits) bytes


setVariant1 : UUID version variant -> UUID version Variant1
setVariant1 =
    setVariant Variant1 1


setVariant2 : UUID version variant -> UUID version Variant2
setVariant2 =
    setVariant Variant2 2


setVariant : variant -> Int -> UUID version anyVariant -> UUID version variant
setVariant _ var (UUID bytes) =
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
            ""


encode : UUID version variant -> Encode.Value
encode =
    canonical >> Encode.string


decoder : Decoder (UUID version variant)
decoder =
    Decode.string |> Decode.andThen stringToUUID


stringToUUID : String -> Decoder (UUID version variant)
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
        Decode.fail "UUID contained non-hexadecimal digits"

    else if List.length ints /= 16 then
        Decode.fail "UUID was not correct length"

    else
        ints
            |> Maybe.Extra.values
            |> UUID
            |> Decode.succeed


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
