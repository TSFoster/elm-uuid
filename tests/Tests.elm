module Tests exposing (suite)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Random exposing (Generator)
import Regex exposing (Regex)
import Result exposing (Result)
import Set exposing (Set)
import Shrink exposing (noShrink)
import Test exposing (..)
import UUID exposing (..)


suite : Test
suite =
    describe "UUID"
        [ describe "formatting"
            [ fuzz fuzzer "Canonical" <|
                \uuid ->
                    Expect.true (toRepresentation Canonical uuid ++ " is not in the canonical textual representation") <|
                        isCanonicalFormat (toRepresentation Canonical uuid)
            , fuzz fuzzer "GUID" <|
                \uuid ->
                    Expect.true (toRepresentation Guid uuid ++ " is not in Microsoft’s textual representation of GUIDs") <|
                        isGuidFormat (toRepresentation Guid uuid)
            , fuzz fuzzer "URN" <|
                \uuid ->
                    Expect.true (toRepresentation Urn uuid ++ " is not a correctly-formatted URN for the UUID") <|
                        isUrnFormat (toRepresentation Urn uuid)
            , fuzz fuzzer "toString is canonical" <|
                \uuid -> Expect.equal (toRepresentation Canonical uuid) (toString uuid)
            , fuzz fuzzer "Can read any representation" <|
                \uuid ->
                    Expect.all
                        [ Expect.equal (fromString (toRepresentation Canonical uuid))
                        , Expect.equal (fromString (toRepresentation Guid uuid))
                        , Expect.equal (fromString (toRepresentation Urn uuid))
                        ]
                        (Ok uuid)
            ]
        , describe "Bytes" <|
            [ fuzz fuzzer "can convert to and from bytes without a problem" <|
                \uuid -> Expect.equal (Ok uuid) (fromBytes (toBytes uuid))
            ]
        , describe "Randomness" <|
            [ fuzzWith { runs = 5 } seedFuzzer "No collisions in 1m UUIDs" <|
                testRandomness 1000000 Set.empty
            ]
        ]



-- FUZZER


fuzzer : Fuzzer UUID
fuzzer =
    Fuzz.custom generator noShrink


seedFuzzer : Fuzzer Random.Seed
seedFuzzer =
    Fuzz.custom (Random.int Random.minInt Random.maxInt) noShrink
        |> Fuzz.map Random.initialSeed



-- TESTS


testRandomness : Int -> Set String -> Random.Seed -> Expectation
testRandomness remaining seen seed =
    if remaining <= 0 then
        Expect.pass

    else
        let
            ( uuid, newSeed ) =
                Random.step generator seed
                    |> Tuple.mapFirst toString
        in
        if Set.member uuid seen then
            Expect.fail "collision detected"

        else
            testRandomness (remaining - 1) (Set.insert uuid seen) newSeed



-- REGEX HELPERS


isCanonicalFormat : String -> Bool
isCanonicalFormat =
    Regex.contains canonicalRegex


isUrnFormat : String -> Bool
isUrnFormat =
    Regex.contains urnRegex


isGuidFormat : String -> Bool
isGuidFormat =
    Regex.contains guidRegex


canonicalRegex : Regex
canonicalRegex =
    Regex.fromString ("^" ++ uuidRegexString ++ "$")
        |> Maybe.withDefault Regex.never


urnRegex : Regex
urnRegex =
    Regex.fromString ("^urn:uuid:" ++ uuidRegexString ++ "$")
        |> Maybe.withDefault Regex.never


guidRegex : Regex
guidRegex =
    Regex.fromString ("^\\{" ++ uuidRegexString ++ "\\}$")
        |> Maybe.withDefault Regex.never


uuidRegexString : String
uuidRegexString =
    "[0-f]{8}-[0-f]{4}-[1-5][0-f]{3}-[8-d][0-f]{3}-[0-f]{12}"
