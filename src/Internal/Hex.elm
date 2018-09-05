module Internal.Hex exposing (Seven(..), sevenGenerator)

import Hex
import Random exposing (Generator)


type Seven
    = Seven Char Char Char Char Char Char Char


sevenGenerator : Generator Seven
sevenGenerator =
    Random.map intToSeven (Random.int 0 0x7FFFFFFF)


intToSeven : Int -> Seven
intToSeven i =
    let
        chars =
            Hex.toString i
                |> String.padLeft 7 '0'
                |> String.right 7
                |> String.toList
    in
    case chars of
        a :: b :: c :: d :: e :: f :: g :: _ ->
            Seven a b c d e f g

        _ ->
            -- This will not happen!
            Seven 'x' 'x' 'x' 'x' 'x' 'x' 'x'
