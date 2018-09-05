module Internal.UUID exposing
    ( Nil
    , UUID
    , Variant(..)
    , Variant1
    , Variant2
    , Version4
    , canonical
    , decoder
    , encode
    , forceVariant1
    , forceVariant2
    , forceVersion4
    , fromStrings
    , microsoftGUID
    , setVariantBits
    , urn
    , variant
    , version
    )

import Bitwise
import Hex
import Json.Decode as Decode exposing (Decoder)
import Json.Encode as Encode
import Result


type UUID version variant
    = UUID String String String String String


type Version4
    = Version4


type Variant2
    = Variant2


type Variant1
    = Variant1


type Nil
    = Nil


type Variant
    = V1
    | V2


fromStrings : String -> String -> String -> String -> String -> UUID version variant
fromStrings =
    UUID


forceVariant1 : UUID version variant -> UUID version Variant1
forceVariant1 (UUID a b c d e) =
    UUID a b c d e


forceVariant2 : UUID version variant -> UUID version Variant2
forceVariant2 (UUID a b c d e) =
    UUID a b c d e


forceVersion4 : UUID version variant -> UUID Version4 variant
forceVersion4 (UUID a b c d e) =
    UUID a b c d e


version : UUID version variant -> Maybe Int
version (UUID _ _ section _ _) =
    section
        |> String.slice 0 1
        |> String.toInt


variant : UUID version variant -> Maybe Int
variant (UUID _ _ _ section _) =
    section
        |> String.slice 0 1
        |> Hex.fromString
        |> Result.toMaybe
        |> Maybe.andThen
            (\i ->
                if i >= 8 && i < 12 then
                    Just 1

                else if i >= 12 && i < 14 then
                    Just 2

                else
                    Nothing
            )


setVariantBits : Variant -> Char -> Char
setVariantBits var =
    let
        ( variantBits, andAmount, defaultChar ) =
            case var of
                V1 ->
                    ( 8, 3, '8' )

                V2 ->
                    ( 12, 1, 'c' )
    in
    String.fromChar
        >> Hex.fromString
        >> Result.withDefault 0
        >> Bitwise.and andAmount
        >> (+) variantBits
        >> Hex.toString
        >> String.uncons
        >> Maybe.map Tuple.first
        >> Maybe.withDefault defaultChar


canonical : UUID version variant -> String
canonical (UUID a b c d e) =
    String.join "-" [ a, b, c, d, e ]


microsoftGUID : UUID version variant -> String
microsoftGUID uuid =
    "{" ++ canonical uuid ++ "}"


urn : UUID version variant -> String
urn uuid =
    "urn:uuid:" ++ canonical uuid


encode : UUID version variant -> Encode.Value
encode =
    canonical >> Encode.string


decoder : Decoder (UUID version variant)
decoder =
    Decode.string |> Decode.andThen strToUUID


strToUUID : String -> Decoder (UUID version variant)
strToUUID string =
    if String.length string /= 36 then
        Decode.fail "UUID not right length"

    else
        case String.split "-" string of
            a :: b :: c :: d :: e :: [] ->
                Decode.map5 fromStrings
                    (checkHexLength 8 a)
                    (checkHexLength 4 b)
                    (checkHexLength 4 c)
                    (checkHexLength 4 d)
                    (checkHexLength 12 e)

            _ ->
                Decode.fail "UUID has wrong number of sections"


checkHexLength : Int -> String -> Decoder String
checkHexLength length section =
    if String.length section /= length then
        Decode.fail ("Section length is not " ++ String.fromInt length)

    else if not (String.all Char.isHexDigit section) then
        Decode.fail "Not all characters are hex digits"

    else
        Decode.succeed (String.toLower section)
