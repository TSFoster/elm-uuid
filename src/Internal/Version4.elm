module Internal.Version4 exposing (generator)

import Internal.Hex as Hex
import Internal.UUID exposing (UUID, Variant(..), Version4, fromStrings, setVariantBits)
import Random exposing (Generator)


generator : Variant -> Generator (UUID Version4 a)
generator variant =
    Random.map5 (makeUUID variant) Hex.sevenGenerator Hex.sevenGenerator Hex.sevenGenerator Hex.sevenGenerator Hex.sevenGenerator


makeUUID : Variant -> Hex.Seven -> Hex.Seven -> Hex.Seven -> Hex.Seven -> Hex.Seven -> UUID Version4 a
makeUUID variant (Hex.Seven c1 c2 c3 c4 c5 c6 c7) (Hex.Seven c8 c9 c10 c11 c12 c13 c14) (Hex.Seven c15 c16 c17 c18 c19 c20 c21) (Hex.Seven c22 c23 c24 c25 c26 c27 c28) (Hex.Seven c29 c30 c31 _ _ _ _) =
    let
        s1 =
            String.fromList [ c1, c2, c3, c4, c5, c6, c7, c8 ]

        s2 =
            String.fromList [ c9, c10, c11, c12 ]

        s3 =
            String.fromList [ '4', c13, c14, c15 ]

        s4 =
            String.fromList [ setVariantBits variant c16, c17, c18, c19 ]

        s5 =
            String.fromList [ c20, c21, c22, c23, c24, c25, c26, c27, c28, c29, c30, c31 ]
    in
    fromStrings s1 s2 s3 s4 s5
