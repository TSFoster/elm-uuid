module Tests exposing (suite)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Json.Decode exposing (Decoder, decodeValue)
import Json.Encode exposing (Value)
import Random exposing (Generator)
import Regex exposing (Regex)
import Test exposing (..)
import UUID exposing (..)


suite : Test
suite =
    describe "UUID"
        [ describe "Version 3"
            [ describe "Variant 1"
                [ v3Test v3WithNamespace nil "hello" "a6c0426f-f9a3-3b59-a62f-4807c382b768"
                , v3Test v3WithNamespace nil "👍" "4d97f1ba-003a-3129-97bf-84e54402e734"
                ]
            , describe "Variant 2"
                [ v3Test v3v2WithNamespace nil "hello" "a6c0426f-f9a3-3b59-c62f-4807c382b768"
                , v3Test v3v2WithNamespace nil "👍" "4d97f1ba-003a-3129-d7bf-84e54402e734"
                ]
            ]
        , describe "Version 4"
            [ describe "Variant 1"
                [ fuzz v4v1UUID "Generates valid UUIDs" <|
                    isValid
                , fuzz v4v1UUID "Has correct version number" <|
                    correctVersionNumber "4"
                , fuzz v4v1UUID "Has correct variant number" <|
                    correctVariant1Digits
                , fuzz v4v1UUID "Can be encoded and decoded" <|
                    encodeThenDecode (decoder |> Json.Decode.andThen checkVersion4 |> Json.Decode.andThen checkVariant1)
                ]
            , describe "Variant 2"
                [ fuzz v4v2UUID "Generates valid UUIDs" <|
                    isValid
                , fuzz v4v2UUID "Has correct version number" <|
                    correctVersionNumber "4"
                , fuzz v4v2UUID "Has correct variant number" <|
                    correctVariant2Digits
                , fuzz v4v2UUID "Can be encoded and decoded" <|
                    encodeThenDecode (decoder |> Json.Decode.andThen checkVersion4 |> Json.Decode.andThen checkVariant2)
                ]
            ]
        , describe "Nil UUID"
            [ test "Is all zeroes" <|
                \_ ->
                    Expect.equal "00000000-0000-0000-0000-000000000000" (canonical nil)
            ]
        , describe "formatting"
            [ fuzz v4v1UUID "Canonical" <|
                \uuid ->
                    canonical uuid
                        |> Regex.contains uuidRegex
                        |> Expect.true (canonical uuid ++ " did not match canonical regex")
            , fuzz v4v1UUID "Microsoft GUID" <|
                \uuid ->
                    microsoftGUID uuid
                        |> Regex.contains microsoftGUIDRegex
                        |> Expect.true (microsoftGUID uuid ++ " did not match Microsoft GUID regex")
            , fuzz v4v1UUID "URN GUID" <|
                \uuid ->
                    urn uuid
                        |> Regex.contains urnRegex
                        |> Expect.true (urn uuid ++ " did not match URN regex")
            ]
        ]


v4v1UUID : Fuzzer (UUID Version4 Variant1)
v4v1UUID =
    Fuzz.int
        |> Fuzz.map Random.initialSeed
        |> Fuzz.map (Random.step generator)
        |> Fuzz.map Tuple.first


v4v2UUID : Fuzzer (UUID Version4 Variant2)
v4v2UUID =
    Fuzz.map toVariant2 v4v1UUID


correctVersionNumber : String -> UUID version variant -> Expectation
correctVersionNumber version =
    canonical >> String.slice 14 15 >> Expect.equal version


isValid : UUID version variant -> Expectation
isValid =
    canonical >> Regex.contains uuidRegex >> Expect.true "Is not valid UUID"


uuidRegex : Regex
uuidRegex =
    Regex.fromString "^[0-f]{8}-([0-f]{4}-){3}[0-f]{12}$"
        |> Maybe.withDefault Regex.never


microsoftGUIDRegex : Regex
microsoftGUIDRegex =
    Regex.fromString "^\\{[0-f]{8}-([0-f]{4}-){3}[0-f]{12}\\}$"
        |> Maybe.withDefault Regex.never


urnRegex : Regex
urnRegex =
    Regex.fromString "^urn:uuid:[0-f]{8}-([0-f]{4}-){3}[0-f]{12}$"
        |> Maybe.withDefault Regex.never


correctVariant1Digits : UUID version variant -> Expectation
correctVariant1Digits =
    variantDigitsIn [ "8", "9", "a", "b" ]


correctVariant2Digits : UUID version variant -> Expectation
correctVariant2Digits =
    variantDigitsIn [ "c", "d" ]


variantDigitsIn : List String -> UUID version variant -> Expectation
variantDigitsIn list =
    canonical >> String.slice 19 20 >> (\digit -> List.member digit list) >> Expect.true "Variant digit incorrect"


encodeThenDecode : Decoder (UUID version variant) -> UUID version variant -> Expectation
encodeThenDecode decoder uuid =
    encode uuid |> decodeValue decoder |> Expect.equal (Ok uuid)


v3v2WithNamespace : UUID version variant -> String -> UUID Version3 Variant2
v3v2WithNamespace namespace =
    v3WithNamespace namespace >> toVariant2


v3Test : (UUID version variant -> String -> UUID Version3 anyVariant) -> UUID version variant -> String -> String -> Test
v3Test withNamespace namespace name result =
    test ("Correctly hashes " ++ canonical namespace ++ " + " ++ name) <|
        \_ -> withNamespace namespace name |> canonical |> Expect.equal result
