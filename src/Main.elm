module Main exposing (main)

import Browser
import Browser.Events
import Element exposing (Element, centerY, el, fill, height, px, rgb255, width)
import Element.Background as Background
import Element.Border as Border
import Element.Input as Input
import Html exposing (Html)
import Html.Attributes exposing (attribute)
import Icon
import Json.Encode exposing (Value)
import Packages.Device as Device exposing (Device)
import Packages.FileInput as FileInput
import Ports
import Style


main : Program Device.Size State Msg
main =
    Browser.element
        { init = \size -> ( Initial (Device.classify size), Cmd.none )
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type State
    = Initial Device
    | DatasetLoaded Device Int Slider


type alias Slider =
    { min : Int
    , max : Int
    , current : Int
    }


initialSlider : Slider
initialSlider =
    { min = 0
    , max = 0
    , current = 0
    }


type Msg
    = Track
    | Pick Float
    | LoadDataset Value
    | DatasetLoadedMsg Int
    | WindowResizes Device.Size
    | NewKeyFrame Int


update : Msg -> State -> ( State, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( LoadDataset jsValue, Initial _ ) ->
            ( model, Ports.loadDataset jsValue )

        ( DatasetLoadedMsg nb_frames, Initial device ) ->
            ( DatasetLoaded device nb_frames initialSlider, Cmd.none )

        ( Track, DatasetLoaded _ _ _ ) ->
            ( model, Ports.track () )

        ( Pick value, DatasetLoaded device nb_frames slid ) ->
            ( DatasetLoaded device nb_frames { slid | current = round value }, Cmd.none )

        ( NewKeyFrame _, DatasetLoaded device nb_frames slid ) ->
            ( DatasetLoaded device nb_frames { slid | max = slid.max + 1 }, Cmd.none )

        -- Window resizes
        ( WindowResizes size, Initial device ) ->
            ( Initial { device | size = size }, Cmd.none )

        ( WindowResizes size, DatasetLoaded device nb_frames slid ) ->
            ( DatasetLoaded { device | size = size } nb_frames slid, Cmd.none )

        _ ->
            ( model, Cmd.none )


subscriptions : State -> Sub Msg
subscriptions state =
    case state of
        Initial _ ->
            Sub.batch
                [ Ports.resizes WindowResizes
                , Ports.datasetLoaded DatasetLoadedMsg
                ]

        DatasetLoaded _ _ _ ->
            Sub.batch
                [ Ports.resizes WindowResizes
                , Browser.Events.onAnimationFrameDelta (always Track)
                , Ports.newKeyFrame NewKeyFrame
                ]


view : State -> Html Msg
view model =
    Element.layout [] (appLayout model)


appLayout : State -> Element Msg
appLayout model =
    case model of
        Initial _ ->
            loadDatasetButton LoadDataset

        DatasetLoaded device nb_frames slid ->
            let
                rendererSize =
                    { width = device.size.width
                    , height = device.size.height - 50
                    }
            in
            Element.column [ width fill, height fill, Element.clip ]
                [ renderer rendererSize nb_frames slid
                , el [ width fill, height (px 50), Element.paddingXY 10 0 ] (slider slid)
                ]


renderer : Device.Size -> Int -> Slider -> Element msg
renderer size nb_frames s =
    el
        [ width fill
        , height fill
        , Background.color (rgb255 255 220 255)
        ]
        (Element.html (customRenderer size nb_frames s))


customRenderer : Device.Size -> Int -> Slider -> Html msg
customRenderer { width, height } nb_frames s =
    Html.node "custom-renderer"
        [ attribute "width" (String.fromFloat width)
        , attribute "height" (String.fromFloat height)
        , attribute "current" (String.fromInt s.current)
        , attribute "nb-frames" (String.fromInt nb_frames)
        ]
        []


slider : Slider -> Element Msg
slider s =
    Input.slider
        [ height fill
        , width fill

        -- Here is where we're creating/styling the "track"
        , Element.behindContent
            (el
                [ width fill
                , height (px 5)
                , centerY
                , Background.color (rgb255 50 50 50)
                , Border.rounded 2
                ]
                Element.none
            )
        ]
        { onChange = Pick
        , label = Input.labelHidden "slider"
        , min = toFloat s.min
        , max = toFloat s.max
        , value = toFloat s.current
        , thumb = Input.defaultThumb
        , step = Just 1
        }


loadDatasetButton : (Value -> msg) -> Element msg
loadDatasetButton loadDatasetMsg =
    let
        uniqueId =
            "load-dataset"

        icon =
            [ Icon.toHtml 60 Icon.settings ]
                |> Html.label (iconLabelAttributes uniqueId)
                |> Element.html
                |> Element.el
                    [ Element.mouseOver [ Background.color Style.hoveredItemBG ]
                    , Element.htmlAttribute (Html.Attributes.title "Load dataset archive")
                    ]

        invisibleInput =
            FileInput.invisible
                { id = uniqueId
                , accept = ".tar"
                , quantity = FileInput.SingleWith loadDatasetMsg
                }
    in
    Element.row [] [ icon, Element.html invisibleInput ]


iconLabelAttributes : String -> List (Html.Attribute msg)
iconLabelAttributes uniqueId =
    -- need to manually add a cursor because the class given by elm-ui
    -- gets overwritten by user agent stylesheet for a label
    Html.Attributes.for uniqueId
        :: Html.Attributes.style "cursor" "pointer"
        :: centerFlexAttributes


centerFlexAttributes : List (Html.Attribute msg)
centerFlexAttributes =
    [ Html.Attributes.style "width" "100px"
    , Html.Attributes.style "height" "100px"
    , Html.Attributes.style "display" "flex"
    , Html.Attributes.style "align-items" "center"
    , Html.Attributes.style "justify-content" "center"
    ]
