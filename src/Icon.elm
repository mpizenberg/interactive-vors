-- Module containing svg icons generated from 1602/elm-feather-icons
--
-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/


module Icon exposing
    ( boundingBox
    , chevronLeft
    , chevronRight
    , database
    , defaultAttributes
    , download
    , from
    , image
    , line
    , move
    , outline
    , pause
    , play
    , point
    , polygon
    , settings
    , toHtml
    , trash2
    , until
    , zoomFit
    , zoomIn
    , zoomOut
    )

import Html exposing (Html)
import Svg exposing (Svg, svg)
import Svg.Attributes exposing (..)


toHtml : Float -> List (Svg msg) -> Html msg
toHtml size icon =
    svg (width (String.fromFloat size) :: height (String.fromFloat size) :: defaultAttributes) icon


defaultAttributes : List (Svg.Attribute msg)
defaultAttributes =
    [ fill "none"
    , Svg.Attributes.stroke "currentColor"
    , strokeLinecap "round"
    , strokeLinejoin "round"
    , strokeWidth "2"
    , viewBox "0 0 24 24"
    ]



-- Designed by Matthieu ####################################


zoomFit : List (Svg msg)
zoomFit =
    [ Svg.circle [ cx "11", cy "11", r "8" ] []
    , Svg.line [ x1 "21", y1 "21", x2 "16.65", y2 "16.65" ] []
    , Svg.path [ d "M 6 8 v 6 h 10 v -6 h -10" ] []
    ]


boundingBox : List (Svg msg)
boundingBox =
    [ Svg.path [ d "M 23 17 h -6 m -3 0 H 4 V 7 H 20 V 11 m 0 3 v 6" ] []
    ]


polygon : List (Svg msg)
polygon =
    [ Svg.polygon [ points "12 22, 2 11, 7 2, 12 9, 17 2, 22 11" ] []
    , Svg.circle [ cx "12", cy "22", r "1" ] []
    , Svg.circle [ cx "2", cy "11", r "1" ] []
    , Svg.circle [ cx "7", cy "2", r "1" ] []
    , Svg.circle [ cx "12", cy "9", r "1" ] []
    , Svg.circle [ cx "17", cy "2", r "1" ] []
    , Svg.circle [ cx "22", cy "11", r "1" ] []
    ]


outline : List (Svg msg)
outline =
    [ Svg.path [ d "M12,22 Q1,15 4,6 t6,0 t6,0 t6,0 T12,22" ] [] ]
        |> Svg.g [ transform "rotate(90 12 12)" ]
        |> List.singleton


line : List (Svg msg)
line =
    [ Svg.path [ d "M1,12 Q6,5 12,12 t11,0" ] [] ]


point : List (Svg msg)
point =
    [ Svg.circle [ cx "12", cy "12", r "3", fill "currentColor" ] [] ]



-- Feather icons ###########################################


database : List (Svg msg)
database =
    [ Svg.ellipse [ cx "12", cy "5", rx "9", ry "3" ] []
    , Svg.path [ d "M21 12c0 1.66-4 3-9 3s-9-1.34-9-3" ] []
    , Svg.path [ d "M3 5v14c0 1.66 4 3 9 3s9-1.34 9-3V5" ] []
    ]


until : List (Svg msg)
until =
    [ Svg.path [ d "M15 3h4a2 2 0 0 1 2 2v14a2 2 0 0 1-2 2h-4" ] []
    , Svg.polyline [ points "10 17 15 12 10 7" ] []
    , Svg.line [ x1 "15", y1 "12", x2 "3", y2 "12" ] []
    ]


from : List (Svg msg)
from =
    [ Svg.path [ d "M9 21H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h4" ] []
    , Svg.polyline [ points "16 17 21 12 16 7" ] []
    , Svg.line [ x1 "21", y1 "12", x2 "9", y2 "12" ] []
    ]


pause : List (Svg msg)
pause =
    [ Svg.rect [ Svg.Attributes.x "6", y "4", width "4", height "16" ] []
    , Svg.rect [ Svg.Attributes.x "14", y "4", width "4", height "16" ] []
    ]


play : List (Svg msg)
play =
    [ Svg.polygon [ points "5 3 19 12 5 21 5 3" ] []
    ]


move : List (Svg msg)
move =
    [ Svg.polyline [ points "5 9 2 12 5 15" ] []
    , Svg.polyline [ points "9 5 12 2 15 5" ] []
    , Svg.polyline [ points "15 19 12 22 9 19" ] []
    , Svg.polyline [ points "19 9 22 12 19 15" ] []
    , Svg.line [ x1 "2", y1 "12", x2 "22", y2 "12" ] []
    , Svg.line [ x1 "12", y1 "2", x2 "12", y2 "22" ] []
    ]


trash2 : List (Svg msg)
trash2 =
    [ Svg.polyline [ points "3 6 5 6 21 6" ] []
    , Svg.path [ d "M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2" ] []
    , Svg.line [ x1 "10", y1 "11", x2 "10", y2 "17" ] []
    , Svg.line [ x1 "14", y1 "11", x2 "14", y2 "17" ] []
    ]


zoomIn : List (Svg msg)
zoomIn =
    [ Svg.circle [ cx "11", cy "11", r "8" ] []
    , Svg.line [ x1 "21", y1 "21", x2 "16.65", y2 "16.65" ] []
    , Svg.line [ x1 "11", y1 "8", x2 "11", y2 "14" ] []
    , Svg.line [ x1 "8", y1 "11", x2 "14", y2 "11" ] []
    ]


zoomOut : List (Svg msg)
zoomOut =
    [ Svg.circle [ cx "11", cy "11", r "8" ] []
    , Svg.line [ x1 "21", y1 "21", x2 "16.65", y2 "16.65" ] []
    , Svg.line [ x1 "8", y1 "11", x2 "14", y2 "11" ] []
    ]


download : List (Svg msg)
download =
    [ Svg.path [ d "M3 17v3a2 2 0 0 0 2 2h14a2 2 0 0 0 2-2v-3" ] []
    , Svg.polyline [ points "8 12 12 16 16 12" ] []
    , Svg.line [ x1 "12", y1 "2", x2 "12", y2 "16" ] []
    ]


image : List (Svg msg)
image =
    [ Svg.rect [ x "3", y "3", width "18", height "18", rx "2", ry "2" ] []
    , Svg.circle [ cx "8.5", cy "8.5", r "1.5" ] []
    , Svg.polyline [ points "21 15 16 10 5 21" ] []
    ]


chevronLeft : List (Svg msg)
chevronLeft =
    [ Svg.polyline [ points "15 18 9 12 15 6" ] [] ]


chevronRight : List (Svg msg)
chevronRight =
    [ Svg.polyline [ points "9 18 15 12 9 6" ] [] ]


settings : List (Svg msg)
settings =
    [ Svg.circle [ cx "12", cy "12", r "3" ] []
    , Svg.path [ d "M19.4 15a1.65 1.65 0 0 0 .33 1.82l.06.06a2 2 0 0 1 0 2.83 2 2 0 0 1-2.83 0l-.06-.06a1.65 1.65 0 0 0-1.82-.33 1.65 1.65 0 0 0-1 1.51V21a2 2 0 0 1-2 2 2 2 0 0 1-2-2v-.09A1.65 1.65 0 0 0 9 19.4a1.65 1.65 0 0 0-1.82.33l-.06.06a2 2 0 0 1-2.83 0 2 2 0 0 1 0-2.83l.06-.06a1.65 1.65 0 0 0 .33-1.82 1.65 1.65 0 0 0-1.51-1H3a2 2 0 0 1-2-2 2 2 0 0 1 2-2h.09A1.65 1.65 0 0 0 4.6 9a1.65 1.65 0 0 0-.33-1.82l-.06-.06a2 2 0 0 1 0-2.83 2 2 0 0 1 2.83 0l.06.06a1.65 1.65 0 0 0 1.82.33H9a1.65 1.65 0 0 0 1-1.51V3a2 2 0 0 1 2-2 2 2 0 0 1 2 2v.09a1.65 1.65 0 0 0 1 1.51 1.65 1.65 0 0 0 1.82-.33l.06-.06a2 2 0 0 1 2.83 0 2 2 0 0 1 0 2.83l-.06.06a1.65 1.65 0 0 0-.33 1.82V9a1.65 1.65 0 0 0 1.51 1H21a2 2 0 0 1 2 2 2 2 0 0 1-2 2h-.09a1.65 1.65 0 0 0-1.51 1z" ] []
    ]
