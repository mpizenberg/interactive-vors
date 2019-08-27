module Main exposing (main)

import Browser
import Element exposing (Element, centerY, el, fill, height, padding, px, rgb255, width)
import Element.Background as Background
import Element.Border as Border
import Element.Input as Input
import Html exposing (Html)
import Html.Attributes exposing (attribute)
import Icon
import Json.Encode exposing (Value)
import Packages.FileInput as FileInput
import Ports
import Style
import Time


main : Program () State Msg
main =
    Browser.element
        { init = \() -> ( Initial, Cmd.none )
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type State
    = Initial
    | DatasetLoaded Int Slider


type alias Slider =
    { min : Int
    , max : Int
    , current : Int
    }


initialSlider : Slider
initialSlider =
    { min = 0
    , max = 1
    , current = 0
    }


type Msg
    = IncrementMax
    | Pick Float
    | LoadDataset Value
    | DatasetLoadedMsg Int


update : Msg -> State -> ( State, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( LoadDataset jsValue, Initial ) ->
            ( model, Ports.loadDataset jsValue )

        ( DatasetLoadedMsg nb_frames, Initial ) ->
            ( DatasetLoaded nb_frames initialSlider, Cmd.none )

        ( IncrementMax, DatasetLoaded nb_frames slid ) ->
            if slid.max + 1 < nb_frames then
                ( DatasetLoaded nb_frames { slid | max = slid.max + 1 }, Cmd.none )

            else
                ( model, Cmd.none )

        ( Pick value, DatasetLoaded nb_frames slid ) ->
            ( DatasetLoaded nb_frames { slid | current = round value }, Cmd.none )

        _ ->
            ( model, Cmd.none )


subscriptions : State -> Sub Msg
subscriptions state =
    case state of
        Initial ->
            Ports.datasetLoaded DatasetLoadedMsg

        DatasetLoaded _ _ ->
            Time.every 1000 (always IncrementMax)


view : State -> Html Msg
view model =
    Element.layout [] (appLayout model)


appLayout : State -> Element Msg
appLayout model =
    case model of
        Initial ->
            loadDatasetButton LoadDataset

        DatasetLoaded nb_frames slid ->
            Element.column [ width fill, height fill ]
                [ renderer nb_frames slid
                , el [ width fill, height (px 50), Element.paddingXY 10 0 ] (slider slid)
                ]


renderer : Int -> Slider -> Element msg
renderer nb_frames s =
    el
        [ width fill
        , height fill
        , Background.color (rgb255 255 220 255)
        , padding 30
        ]
        (Element.html (customRenderer nb_frames s))


customRenderer : Int -> Slider -> Html msg
customRenderer nb_frames s =
    Html.node "custom-renderer"
        [ attribute "current" (String.fromInt s.current)
        , attribute "nb-frames" (String.fromInt nb_frames)
        , attribute "trigger-compute" (String.fromInt s.max)
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
