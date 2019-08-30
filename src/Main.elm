module Main exposing (main)

import Browser
import Browser.Events
import Element exposing (Element, centerY, el, fill, height, px, rgb255, width)
import Element.Background as Background
import Element.Border as Border
import Element.Events
import Element.Input as Input
import Html exposing (Html)
import Html.Attributes as Attr exposing (attribute)
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
    | DatasetLoaded Device Int Slider Bool Fps


type alias Fps =
    { exact : Float
    , smoothed : Float
    , stable : Int
    , accumMs : Float
    }


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
    = Track Float
    | Pick Float
    | LoadDataset Value
    | DatasetLoadedMsg Int
    | WindowResizes Device.Size
    | NewKeyFrame Int
    | ToogleTracking
    | ExportObj


update : Msg -> State -> ( State, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( LoadDataset jsValue, Initial _ ) ->
            ( model, Ports.loadDataset jsValue )

        ( DatasetLoadedMsg nb_frames, Initial device ) ->
            ( DatasetLoaded device nb_frames initialSlider False (Fps 60 60 60 0), Cmd.none )

        ( Track delta, DatasetLoaded device nb_frames slid play fps ) ->
            let
                newModel =
                    DatasetLoaded device nb_frames slid play (updateFps delta fps)
            in
            if play then
                ( newModel, Ports.track () )

            else
                ( newModel, Cmd.none )

        ( Pick value, DatasetLoaded device nb_frames slid play fps ) ->
            ( DatasetLoaded device nb_frames { slid | current = round value } play fps, Cmd.none )

        ( NewKeyFrame _, DatasetLoaded device nb_frames slid play fps ) ->
            ( DatasetLoaded device nb_frames (updateTimeline slid) play fps, Cmd.none )

        ( ToogleTracking, DatasetLoaded device nb_frames slid play fps ) ->
            ( DatasetLoaded device nb_frames slid (not play) fps, Cmd.none )

        ( ExportObj, DatasetLoaded _ _ _ _ _ ) ->
            ( model, Ports.exportObj () )

        -- Window resizes
        ( WindowResizes size, Initial device ) ->
            ( Initial { device | size = size }, Cmd.none )

        ( WindowResizes size, DatasetLoaded device nb_frames slid play fps ) ->
            ( DatasetLoaded { device | size = size } nb_frames slid play fps, Cmd.none )

        _ ->
            ( model, Cmd.none )


updateTimeline : Slider -> Slider
updateTimeline slid =
    let
        newMax =
            slid.max + 1

        newCurrent =
            if slid.current == slid.max then
                newMax

            else
                slid.current
    in
    { min = slid.min
    , max = newMax
    , current = newCurrent
    }


updateFps : Float -> Fps -> Fps
updateFps delta fps =
    let
        exact =
            1000 / delta

        smoothed =
            0.8 * fps.smoothed + 0.2 * exact

        accumMs =
            fps.accumMs + delta

        newAccumMs =
            if accumMs > 500 then
                0

            else
                accumMs

        stable =
            if accumMs > 500 then
                round smoothed

            else
                fps.stable
    in
    { exact = exact
    , smoothed = smoothed
    , stable = stable
    , accumMs = newAccumMs
    }


subscriptions : State -> Sub Msg
subscriptions state =
    case state of
        Initial _ ->
            Sub.batch
                [ Ports.resizes WindowResizes
                , Ports.datasetLoaded DatasetLoadedMsg
                ]

        DatasetLoaded _ _ _ _ _ ->
            Sub.batch
                [ Ports.resizes WindowResizes
                , Browser.Events.onAnimationFrameDelta Track
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

        DatasetLoaded device nb_frames slid play fps ->
            let
                rendererSize =
                    { width = device.size.width
                    , height = device.size.height - 50
                    }
            in
            Element.column [ width fill, height fill, Element.clip ]
                [ renderer rendererSize nb_frames slid
                , bottomToolbar slid play fps.stable
                ]


renderer : Device.Size -> Int -> Slider -> Element msg
renderer size nb_frames s =
    el
        [ width fill
        , height fill
        , Background.color (rgb255 255 220 255)
        , Element.inFront keyframeCanvas
        ]
        (Element.html (customRenderer size nb_frames s))


keyframeCanvas : Element msg
keyframeCanvas =
    el [ width (px 320), height (px 240) ] (Element.html htmlKeyframeCanvas)


htmlKeyframeCanvas : Html msg
htmlKeyframeCanvas =
    Html.canvas [ Attr.id "canvas-kf", Attr.width 320, Attr.height 240, Attr.style "display" "block" ] []


customRenderer : Device.Size -> Int -> Slider -> Html msg
customRenderer { width, height } nb_frames s =
    Html.node "custom-renderer"
        [ attribute "width" (String.fromFloat width)
        , attribute "height" (String.fromFloat height)
        , attribute "canvas-id" "canvas-kf"
        , attribute "nb-frames" (String.fromInt nb_frames)
        , attribute "current" (String.fromInt s.current)
        ]
        []


bottomToolbar : Slider -> Bool -> Int -> Element Msg
bottomToolbar slid play fps =
    Element.row [ width fill, height (px 50), Element.padding 10, Element.spacing 10 ]
        [ fpsViewer fps, playPauseButton play, slider slid, exportObjButton ]


fpsViewer : Int -> Element msg
fpsViewer fps =
    Element.text (String.fromInt fps ++ " fps")


playPauseButton : Bool -> Element Msg
playPauseButton play =
    let
        ( icon, title ) =
            if play then
                ( Icon.pause, "pause" )

            else
                ( Icon.play, "play" )
    in
    abledButton ToogleTracking title (Icon.toHtml 30 icon)


exportObjButton : Element Msg
exportObjButton =
    abledButton ExportObj "Export to obj file" (Icon.toHtml 30 Icon.download)


abledButton : msg -> String -> Html msg -> Element msg
abledButton msg title icon =
    Html.div (centerFlexAttributes 50) [ icon ]
        |> Element.html
        |> Element.el
            [ Element.mouseOver [ Background.color Style.hoveredItemBG ]
            , Element.pointer
            , Element.Events.onClick msg
            , Element.htmlAttribute (Attr.title title)
            ]


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
                    , Element.htmlAttribute (Attr.title "Load dataset archive")
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
    Attr.for uniqueId
        :: Attr.style "cursor" "pointer"
        :: centerFlexAttributes 100


centerFlexAttributes : Int -> List (Html.Attribute msg)
centerFlexAttributes size =
    let
        sizeString =
            String.fromInt size ++ "px"
    in
    [ Attr.style "width" sizeString
    , Attr.style "height" sizeString
    , Attr.style "display" "flex"
    , Attr.style "align-items" "center"
    , Attr.style "justify-content" "center"
    ]
