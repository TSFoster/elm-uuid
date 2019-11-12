module Randomness exposing (suite)

import Expect exposing (Expectation)
import Fuzz exposing (Fuzzer)
import Random
import Set exposing (Set)
import Shrink exposing (noShrink)
import Test exposing (Test, describe, fuzzWith)
import UUID exposing (generator, toString)


suite : Test
suite =
    describe "Generator is sufficiently random"
        [ fuzzWith { runs = 5 } seedFuzzer "No collisions in 1m UUIDs" <|
            testRandomness 1000000 Set.empty
        ]


seedFuzzer : Fuzzer Random.Seed
seedFuzzer =
    Fuzz.custom (Random.int Random.minInt Random.maxInt) noShrink
        |> Fuzz.map Random.initialSeed


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
