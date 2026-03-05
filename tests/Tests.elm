module Tests exposing (suite)

import Bytes.Encode
import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Random
import Regex exposing (Regex)
import Test exposing (Test, describe, fuzz, test)
import Time
import UUID
    exposing
        ( Error(..)
        , Representation(..)
        , UUID
        , forBytes
        , forBytesV3
        , forName
        , forNameV3
        , fromBytes
        , fromString
        , generator
        , generatorV7
        , initialV7State
        , stepV7
        , toBytes
        , toRepresentation
        , toString
        )


suite : Test
suite =
    describe "UUID"
        [ describe "formatting"
            [ fuzz fuzzer "Canonical" <|
                \uuid ->
                    expectTrue (toRepresentation Canonical uuid ++ " is not in the canonical textual representation") <|
                        isCanonicalFormat (toRepresentation Canonical uuid)
            , fuzz fuzzer "GUID" <|
                \uuid ->
                    expectTrue (toRepresentation Guid uuid ++ " is not in Microsoft's textual representation of GUIDs") <|
                        isGuidFormat (toRepresentation Guid uuid)
            , fuzz fuzzer "Compact" <|
                \uuid ->
                    expectTrue (toRepresentation Compact uuid ++ " is not in a compact representation") <|
                        isCompactFormat (toRepresentation Compact uuid)
            , fuzz fuzzer "URN" <|
                \uuid ->
                    expectTrue (toRepresentation Urn uuid ++ " is not a correctly-formatted URN for the UUID") <|
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
        , describe "fromString" <|
            [ test "reads version 1 UUIDs" <|
                \_ -> Expect.ok (fromString "12345678-1234-1234-8888-abcdefabcdef")
            , test "reads version 2 UUIDs" <|
                \_ -> Expect.ok (fromString "12345678-1234-2234-8888-abcdefabcdef")
            , test "reads version 3 UUIDs" <|
                \_ -> Expect.ok (fromString "12345678-1234-3234-8888-abcdefabcdef")
            , test "reads version 4 UUIDs" <|
                \_ -> Expect.ok (fromString "12345678-1234-4234-8888-abcdefabcdef")
            , test "reads version 5 UUIDs" <|
                \_ -> Expect.ok (fromString "12345678-1234-5234-8888-abcdefabcdef")
            , test "reads version 6 UUIDs" <|
                \_ -> Expect.ok (fromString "12345678-1234-6234-8888-abcdefabcdef")
            , test "reads version 7 UUIDs" <|
                \_ -> Expect.ok (fromString "12345678-1234-7234-8888-abcdefabcdef")
            , test "reads version 8 UUIDs" <|
                \_ -> Expect.ok (fromString "12345678-1234-8234-8888-abcdefabcdef")
            , test "doesn't read version 9 UUIDs" <|
                \_ -> Expect.err (fromString "12345678-1234-9234-8888-abcdefabcdef")
            , test "reads UUIDs with missing dashes" <|
                \_ -> Expect.ok (fromString "12345678123412348888abcdefabcdef")
            , test "doesn't read variant 0 UUIDs" <|
                \_ -> Expect.err (fromString "12345678-1234-1234-0888-abcdefabcdef")
            , test "doesn't read variant 2 UUIDs" <|
                \_ -> Expect.err (fromString "12345678-1234-1234-d888-abcdefabcdef")
            , test "doesn't read too-small UUIDs" <|
                \_ -> Expect.err (fromString "12345678-1234-1234-8888-abcdefabcde")
            , test "doesn't read too-long UUIDs" <|
                \_ -> Expect.err (fromString "12345678-1234-1234-8888-abcdefabcdeff")
            , test "doesn't read non-hex UUIDs" <|
                \_ -> Expect.err (fromString "12345678-1234-1234-8888-abcdefgabcde")
            ]
        , describe "compare"
            [ test "equal UUIDs are EQ" <|
                compareTest "12345678-1234-4234-8888-abcdefabcdef" EQ "12345678-1234-4234-8888-abcdefabcdef"
            , test "lower UUIDs in the first quarter are LT" <|
                compareTest "12245678-1234-4234-8888-abcdefabcdef" LT "12345678-1234-4234-8888-abcdefabcdef"
            , test "greater UUIDs in the second quarter are GT" <|
                compareTest "12345678-1244-4234-8888-abcdefabcdef" GT "12345678-1234-4234-8888-abcdefabcdef"
            , test "lower UUIDs in the third quarter are LT" <|
                compareTest "12345678-1234-4234-8878-abcdefabcdef" LT "12345678-1234-4234-8888-abcdefabcdef"
            , test "greater UUIDs in the fourth quarter are GT" <|
                compareTest "12345678-1234-4234-8888-abcdefabcdff" GT "12345678-1234-4234-8888-abcdefabcdef"
            ]
        , describe "generatorV7"
            [ fuzz fuzzerV7 "generates version 7 UUIDs" <|
                \uuid -> Expect.equal 7 (UUID.version uuid)
            , fuzz fuzzerV7 "round-trips through toString/fromString" <|
                \uuid -> Expect.equal (Ok uuid) (fromString (toString uuid))
            , fuzz fuzzerV7 "round-trips through toBytes/fromBytes" <|
                \uuid -> Expect.equal (Ok uuid) (fromBytes (toBytes uuid))
            , test "embeds the correct timestamp" <|
                \_ ->
                    let
                        millis =
                            1234567890000

                        uuid =
                            Random.step (generatorV7 (Time.millisToPosix millis)) (Random.initialSeed 42)
                                |> Tuple.first

                        str =
                            toString uuid

                        -- Extract timestamp hex from canonical format:
                        -- xxxxxxxx-xxxx-7xxx-xxxx-xxxxxxxxxxxx
                        -- The 48-bit timestamp occupies: first 8 hex (32 bits) + next 4 hex (16 bits)
                        tsHex =
                            String.left 8 str ++ String.slice 9 13 str
                    in
                    Expect.equal "011f71fb0450" (String.toLower tsHex)
            ]
        , describe "stepV7 monotonicity"
            [ test "UUIDs from stepV7 with the same timestamp are monotonically ordered" <|
                \_ ->
                    let
                        time =
                            Time.millisToPosix 1700000000000

                        ( state0, _ ) =
                            Random.step initialV7State (Random.initialSeed 99)

                        ( uuid1, state1 ) =
                            stepV7 time state0

                        ( uuid2, state2 ) =
                            stepV7 time state1

                        ( uuid3, _ ) =
                            stepV7 time state2
                    in
                    Expect.all
                        [ \_ -> Expect.equal LT (UUID.compare uuid1 uuid2)
                        , \_ -> Expect.equal LT (UUID.compare uuid2 uuid3)
                        , \_ -> Expect.equal 7 (UUID.version uuid1)
                        , \_ -> Expect.equal 7 (UUID.version uuid2)
                        , \_ -> Expect.equal 7 (UUID.version uuid3)
                        ]
                        ()
            , test "UUIDs from stepV7 with increasing timestamps are ordered" <|
                \_ ->
                    let
                        ( state0, _ ) =
                            Random.step initialV7State (Random.initialSeed 99)

                        ( uuid1, state1 ) =
                            stepV7 (Time.millisToPosix 1700000000000) state0

                        ( uuid2, _ ) =
                            stepV7 (Time.millisToPosix 1700000000001) state1
                    in
                    Expect.equal LT (UUID.compare uuid1 uuid2)
            ]
        ]



-- FUZZER


fuzzer : Fuzzer UUID
fuzzer =
    Fuzz.oneOf [ fuzzerV3, fuzzerV4, fuzzerV5, fuzzerV7 ]


fuzzerV3 : Fuzzer UUID
fuzzerV3 =
    Fuzz.oneOf
        [ Fuzz.map2 forNameV3 Fuzz.string fuzzerV4
        , Fuzz.map2 forBytesV3 (Fuzz.map (Bytes.Encode.encode << Bytes.Encode.string) Fuzz.string) fuzzerV4
        ]


fuzzerV4 : Fuzzer UUID
fuzzerV4 =
    Fuzz.fromGenerator generator


fuzzerV5 : Fuzzer UUID
fuzzerV5 =
    Fuzz.oneOf
        [ Fuzz.map2 forName Fuzz.string fuzzerV4
        , Fuzz.map2 forBytes (Fuzz.map (Bytes.Encode.encode << Bytes.Encode.string) Fuzz.string) fuzzerV4
        ]


fuzzerV7 : Fuzzer UUID
fuzzerV7 =
    Fuzz.fromGenerator
        (Random.int 0 Random.maxInt
            |> Random.andThen (\millis -> generatorV7 (Time.millisToPosix millis))
        )



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


isCompactFormat : String -> Bool
isCompactFormat =
    Regex.contains compactRegex


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


compactRegex : Regex
compactRegex =
    Regex.fromString "[0-f]{12}[1-8][0-f]{3}[8-d][0-f]{15}"
        |> Maybe.withDefault Regex.never


uuidRegexString : String
uuidRegexString =
    "[0-f]{8}-[0-f]{4}-[1-8][0-f]{3}-[8-d][0-f]{3}-[0-f]{12}"



-- COMPARE HELPER


compareTest : String -> Basics.Order -> String -> () -> Expectation
compareTest uuid1 order uuid2 () =
    Expect.equal (Ok order) <|
        Result.map2 UUID.compare (fromString uuid1) (fromString uuid2)


expectTrue : String -> Bool -> Expectation
expectTrue failureMessage bool =
    if bool then
        Expect.pass

    else
        Expect.fail failureMessage
