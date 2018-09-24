module Tests exposing (suite)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Random exposing (Generator)
import Regex exposing (Regex)
import Result exposing (Result)
import Test exposing (..)
import UUID exposing (..)


suite : Test
suite =
    describe "UUID"
        [ describe "Version 3"
            [ describe "Variant 1"
                [ test "Correctly hashes nil UUID with hello" <|
                    \_ -> Expect.equal "a6c0426f-f9a3-3b59-a62f-4807c382b768" (canonical (nil |> v3ChildNamed "hello"))
                , test "Correctly hashes nil UUID with 👍" <|
                    \_ -> Expect.equal "4d97f1ba-003a-3129-97bf-84e54402e734" (canonical (nil |> v3ChildNamed "👍"))
                , test "Correctly hashes DNS UUID with hello" <|
                    \_ -> Expect.equal "0bacede4-4014-3f9d-b720-173f68a1c933" (canonical (dns |> v3ChildNamed "hello"))
                , test "Correctly hashes URL UUID with 👍" <|
                    \_ -> Expect.equal "6d1e7a51-75f1-3fdc-b354-816393a441fe" (canonical (url |> v3ChildNamed "👍"))
                ]
            , describe "Variant 2"
                [ test "Correctly hashes nil UUID with hello" <|
                    \_ -> Expect.equal "a6c0426f-f9a3-3b59-c62f-4807c382b768" (canonical (nil |> v3ChildNamed "hello" |> toVariant2))
                , test "Correctly hashes nil UUID with 👍" <|
                    \_ -> Expect.equal "4d97f1ba-003a-3129-d7bf-84e54402e734" (canonical (nil |> v3ChildNamed "👍" |> toVariant2))
                , test "Correctly hashes DNS UUID with hello" <|
                    \_ -> Expect.equal "0bacede4-4014-3f9d-d720-173f68a1c933" (canonical (dns |> v3ChildNamed "hello" |> toVariant2))
                , test "Correctly hashes URL UUID with 👍" <|
                    \_ -> Expect.equal "6d1e7a51-75f1-3fdc-d354-816393a441fe" (canonical (url |> v3ChildNamed "👍" |> toVariant2))
                ]
            ]
        , describe "Version 4"
            [ v4Test 1 uuidFuzzer
            , v4Test 2 (uuidFuzzer |> Fuzz.map toVariant2)
            ]
        , describe "Nil UUID"
            [ test "Is all zeroes" <|
                \_ -> Expect.equal "00000000-0000-0000-0000-000000000000" (canonical nil)
            ]
        , describe "formatting"
            [ fuzz uuidFuzzer "Canonical" <|
                \uuid ->
                    canonical uuid
                        |> Regex.contains uuidRegex
                        |> Expect.true (canonical uuid ++ " did not match canonical regex")
            , fuzz uuidFuzzer "Microsoft GUID" <|
                \uuid ->
                    microsoftGUID uuid
                        |> Regex.contains microsoftGUIDRegex
                        |> Expect.true (microsoftGUID uuid ++ " did not match Microsoft GUID regex")
            , fuzz uuidFuzzer "URN GUID" <|
                \uuid ->
                    urn uuid
                        |> Regex.contains urnRegex
                        |> Expect.true (urn uuid ++ " did not match URN regex")
            , fuzz uuidFuzzer "toString is just canonical" <|
                \uuid -> Expect.equal (canonical uuid) (toString uuid)
            ]
        ]


v4Test : Int -> Fuzzer UUID -> Test
v4Test var fuzzer =
    describe ("Variant " ++ String.fromInt var)
        [ fuzz fuzzer "Generates valid UUIDs" <|
            canonical
                >> Regex.contains uuidRegex
                >> Expect.true "Is not valid UUID"
        , fuzz fuzzer "Has correct version number" <|
            canonical
                >> String.slice 14 15
                >> Expect.equal "4"
        , fuzz fuzzer "Has correct variant number" <|
            case var of
                1 ->
                    variantDigitsIn [ "8", "9", "a", "b" ]

                2 ->
                    variantDigitsIn [ "c", "d" ]

                _ ->
                    always (Expect.fail "Variant digit incorrect")
        , fuzz fuzzer "Can be converted to String and back" <|
            toStringsAndBack (fromString >> Result.andThen (checkVersion 4) >> Result.andThen (checkVariant var))
        ]


uuidFuzzer : Fuzzer UUID
uuidFuzzer =
    Fuzz.int
        |> Fuzz.map Random.initialSeed
        |> Fuzz.map (Random.step generator)
        |> Fuzz.map Tuple.first


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


variantDigitsIn : List String -> UUID -> Expectation
variantDigitsIn list =
    canonical >> String.slice 19 20 >> (\digit -> List.member digit list) >> Expect.true "Variant digit incorrect"


toStringsAndBack : (String -> Result String UUID) -> UUID -> Expectation
toStringsAndBack fromStringFn =
    Expect.all
        [ toStringsAndBackWith canonical fromStringFn
        , toStringsAndBackWith microsoftGUID fromStringFn
        , toStringsAndBackWith urn fromStringFn
        ]


toStringsAndBackWith : (UUID -> String) -> (String -> Result String UUID) -> UUID -> Expectation
toStringsAndBackWith toStringFn fromStringFn uuid =
    Expect.equal (Ok uuid) (fromStringFn <| toStringFn uuid)
