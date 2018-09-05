module Tests exposing (suite)

import Expect
import Fuzz exposing (Fuzzer)
import Json.Decode
import Random exposing (Generator)
import Regex exposing (Regex)
import Test exposing (..)
import UUID exposing (..)
import UUID.Version4.Variant1 as V4V1
import UUID.Version4.Variant2 as V4V2


suite : Test
suite =
    describe "UUID"
        [ describe "Version 4"
            [ describe "Variant 1"
                [ describe "generator"
                    [ fuzz v4v1UUID "Generates valid UUIDs" <|
                        \uuid ->
                            canonical uuid
                                |> Regex.contains uuidRegex
                                |> Expect.true "Expected canonical UUID to match UUID regex"
                    , fuzz v4v1UUID "Has correct version number" <|
                        \uuid ->
                            canonical uuid
                                |> String.slice 14 15
                                |> Expect.equal "4"
                    , fuzz v4v1UUID "Has correct variant number" <|
                        \uuid ->
                            canonical uuid
                                |> String.slice 19 20
                                |> inVariant1Digits
                                |> Expect.true "Expected variant hex digit to be in 0b10xx"
                    , fuzz v4v1UUID "Can be encoded and decoded" <|
                        \uuid ->
                            V4V1.encode uuid
                                |> Json.Decode.decodeValue V4V1.decoder
                                |> Expect.equal (Ok uuid)
                    ]
                ]
            , describe "Variant 2"
                [ describe "generator"
                    [ fuzz v4v2UUID "Generates valid UUIDs" <|
                        \uuid ->
                            canonical uuid
                                |> Regex.contains uuidRegex
                                |> Expect.true "Expected canonical UUID to match UUID regex"
                    , fuzz v4v2UUID "Has correct version number" <|
                        \uuid ->
                            canonical uuid
                                |> String.slice 14 15
                                |> Expect.equal "4"
                    , fuzz v4v2UUID "Has correct variant number" <|
                        \uuid ->
                            canonical uuid
                                |> String.slice 19 20
                                |> inVariant2Digits
                                |> Expect.true "Expected variant hex digit to be in 0b110x"
                    , fuzz v4v2UUID "Can be encoded and decoded" <|
                        \uuid ->
                            V4V2.encode uuid
                                |> Json.Decode.decodeValue V4V2.decoder
                                |> Expect.equal (Ok uuid)
                    ]
                ]
            ]
        , describe "Nil UUID"
            [ test "Is all zeroes" <|
                \_ ->
                    canonical UUID.nil
                        |> Expect.equal "00000000-0000-0000-0000-000000000000"
            ]
        , describe "formatting"
            [ fuzz v4v1UUID "Canonical" <|
                \uuid ->
                    canonical uuid
                        |> Regex.contains uuidRegex
                        |> Expect.true "Expected canonical UUID to match regex"
            , fuzz v4v1UUID "Microsoft GUID" <|
                \uuid ->
                    microsoftGUID uuid
                        |> Regex.contains microsoftGUIDRegex
                        |> Expect.true "Expected Microsoft GUID to match regex"
            , fuzz v4v1UUID "URN GUID" <|
                \uuid ->
                    urn uuid
                        |> Regex.contains urnRegex
                        |> Expect.true "Expected URN UUID to match regex"
            ]
        ]


v4v1UUID : Fuzzer (UUID Version4 Variant1)
v4v1UUID =
    fromGenerator V4V1.generator


v4v2UUID : Fuzzer (UUID Version4 Variant2)
v4v2UUID =
    fromGenerator V4V2.generator


fromGenerator : Generator a -> Fuzzer a
fromGenerator generator =
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


inVariant1Digits : String -> Bool
inVariant1Digits str =
    List.member str [ "8", "9", "a", "b" ]


inVariant2Digits : String -> Bool
inVariant2Digits str =
    List.member str [ "c", "d" ]
