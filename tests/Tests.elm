module Tests exposing (suite)

import Bytes.Encode
import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Regex exposing (Regex)
import Shrink exposing (noShrink)
import Test exposing (Test, describe, fuzz, test)
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
                    Expect.true (toRepresentation Canonical uuid ++ " is not in the canonical textual representation") <|
                        isCanonicalFormat (toRepresentation Canonical uuid)
            , fuzz fuzzer "GUID" <|
                \uuid ->
                    Expect.true (toRepresentation Guid uuid ++ " is not in Microsoft’s textual representation of GUIDs") <|
                        isGuidFormat (toRepresentation Guid uuid)
            , fuzz fuzzer "Compact" <|
                \uuid ->
                    Expect.true (toRepresentation Compact uuid ++ " is not in a compact respresentation") <|
                        isCompactFormat (toRepresentation Compact uuid)
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
        ]



-- FUZZER


fuzzer : Fuzzer UUID
fuzzer =
    Fuzz.oneOf [ fuzzerV3, fuzzerV4, fuzzerV5 ]


fuzzerV3 : Fuzzer UUID
fuzzerV3 =
    Fuzz.oneOf
        [ Fuzz.map2 forNameV3 Fuzz.string fuzzerV4
        , Fuzz.map2 forBytesV3 (Fuzz.map (Bytes.Encode.encode << Bytes.Encode.string) Fuzz.string) fuzzerV4
        ]


fuzzerV4 : Fuzzer UUID
fuzzerV4 =
    Fuzz.custom generator noShrink


fuzzerV5 : Fuzzer UUID
fuzzerV5 =
    Fuzz.oneOf
        [ Fuzz.map2 forName Fuzz.string fuzzerV4
        , Fuzz.map2 forBytes (Fuzz.map (Bytes.Encode.encode << Bytes.Encode.string) Fuzz.string) fuzzerV4
        ]



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
    Regex.fromString "[0-f]{12}[1-5][0-f]{3}[8-d][0-f]{15}"
        |> Maybe.withDefault Regex.never


uuidRegexString : String
uuidRegexString =
    "[0-f]{8}-[0-f]{4}-[1-5][0-f]{3}-[8-d][0-f]{3}-[0-f]{12}"



-- COMPARE HELPER


compareTest : String -> Basics.Order -> String -> () -> Expectation
compareTest uuid1 order uuid2 () =
    Expect.equal (Ok order) <|
        Result.map2 UUID.compare (fromString uuid1) (fromString uuid2)
