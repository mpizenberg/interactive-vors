module Main exposing (main)

import Browser
import Element exposing (Element, centerX, centerY, el, fill, height, px, rgb255, width)
import Element.Background as Background
import Element.Border as Border
import Element.Events
import Element.Font
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
        { init = \size -> ( Initial (Device.classify size) (Camera "icl"), Cmd.none )
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type State
    = Initial Device Camera
    | DatasetLoaded Device Int Slider Bool Fps Fixer


type Fixer
    = NoFix
    | ReferenceKeyframe Int
    | KeyframesPair Int Int


type Camera
    = Camera String


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
    | SelectCamera Camera
    | LoadDataset Value
    | DatasetLoadedMsg Int
    | WindowResizes Device.Size
    | NewKeyFrame Int
    | ToogleTracking
    | PickReference Int
    | RestartFrom Int Int
    | ExportObj


update : Msg -> State -> ( State, Cmd Msg )
update msg model =
    case ( msg, model ) of
        ( SelectCamera camera, Initial device _ ) ->
            ( Initial device camera, Cmd.none )

        ( LoadDataset jsValue, Initial _ (Camera camera) ) ->
            ( model, Ports.loadDataset { file = jsValue, camera = camera } )

        ( DatasetLoadedMsg nb_frames, Initial device _ ) ->
            ( DatasetLoaded device nb_frames initialSlider False (Fps 60 60 60 0) NoFix, Cmd.none )

        ( Track delta, DatasetLoaded device nb_frames slid play fps fixer ) ->
            let
                newModel =
                    DatasetLoaded device nb_frames slid play (updateFps delta fps) fixer
            in
            if play then
                ( newModel, Ports.track () )

            else
                ( newModel, Cmd.none )

        ( Pick value, DatasetLoaded device nb_frames slid play fps fixer ) ->
            ( DatasetLoaded device nb_frames { slid | current = round value } play fps fixer, Cmd.none )

        ( NewKeyFrame _, DatasetLoaded device nb_frames slid play fps fixer ) ->
            ( DatasetLoaded device nb_frames (updateTimeline slid) play fps fixer, Cmd.none )

        ( ToogleTracking, DatasetLoaded device nb_frames slid play fps _ ) ->
            ( DatasetLoaded device nb_frames slid (not play) fps NoFix, Cmd.none )

        ( PickReference keyframe, DatasetLoaded device nb_frames slid play fps _ ) ->
            ( DatasetLoaded device nb_frames slid play fps (ReferenceKeyframe keyframe)
            , Ports.pickReference keyframe
            )

        ( RestartFrom baseKf keyframe, DatasetLoaded device nb_frames _ play fps (ReferenceKeyframe _) ) ->
            ( DatasetLoaded device nb_frames (sliderRestart keyframe) play fps (KeyframesPair baseKf keyframe)
            , Ports.restartFrom { reference = baseKf, restartFrom = keyframe }
            )

        ( RestartFrom baseKf keyframe, DatasetLoaded device nb_frames _ play fps (KeyframesPair _ _) ) ->
            ( DatasetLoaded device nb_frames (sliderRestart keyframe) play fps (KeyframesPair baseKf keyframe)
            , Ports.restartFrom { reference = baseKf, restartFrom = keyframe }
            )

        ( ExportObj, DatasetLoaded _ _ _ _ _ _ ) ->
            ( model, Ports.exportObj () )

        -- Window resizes
        ( WindowResizes size, Initial device camera ) ->
            ( Initial { device | size = size } camera, Cmd.none )

        ( WindowResizes size, DatasetLoaded device nb_frames slid play fps fixer ) ->
            ( DatasetLoaded { device | size = size } nb_frames slid play fps fixer, Cmd.none )

        _ ->
            ( model, Cmd.none )


sliderRestart : Int -> Slider
sliderRestart keyframe =
    { min = 0
    , max = keyframe
    , current = keyframe
    }


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
        Initial _ _ ->
            Sub.batch
                [ Ports.resizes WindowResizes
                , Ports.datasetLoaded DatasetLoadedMsg
                ]

        DatasetLoaded _ _ _ _ _ _ ->
            Sub.batch
                [ Ports.resizes WindowResizes
                , Ports.animationFrame Track
                , Ports.newKeyFrame NewKeyFrame
                ]


view : State -> Html Msg
view model =
    Element.layout [] (appLayout model)


appLayout : State -> Element Msg
appLayout model =
    case model of
        Initial _ camera ->
            initialLayout camera

        DatasetLoaded device nb_frames slid play fps fixer ->
            let
                rendererSize =
                    { width = device.size.width
                    , height = device.size.height - 50
                    }
            in
            Element.column [ width fill, height fill, Element.clip ]
                [ renderer rendererSize nb_frames slid fixer
                , bottomToolbar slid play fps.stable fixer
                ]


initialLayout : Camera -> Element Msg
initialLayout camera =
    Element.column [ centerX, centerY, Element.spacing 30 ]
        [ Input.radio []
            { onChange = SelectCamera
            , selected = Just camera
            , label = Input.labelAbove [] (Element.text "Camera model:")
            , options =
                [ Input.option (Camera "icl") (Element.text "ICL NUIM synthetic dataset")
                , Input.option (Camera "fr1") (Element.text "TUM Freiburg 1")
                , Input.option (Camera "fr2") (Element.text "TUM Freiburg 2")
                , Input.option (Camera "fr3") (Element.text "TUM Freiburg 3")
                ]
            }
        , Element.column [] [ Element.text "Dataset to load:", loadDatasetButton LoadDataset ]
        ]


renderer : Device.Size -> Int -> Slider -> Fixer -> Element msg
renderer size nb_frames s fixer =
    let
        refCanvas =
            case fixer of
                NoFix ->
                    referenceCanvas "none"

                ReferenceKeyframe _ ->
                    referenceCanvas "block"

                KeyframesPair _ _ ->
                    referenceCanvas "block"
    in
    el
        [ width fill
        , height fill
        , Background.color (rgb255 255 220 255)
        , Element.inFront keyframeCanvas
        , Element.inFront refCanvas
        ]
        (Element.html (customRenderer size nb_frames s))


referenceCanvas : String -> Element msg
referenceCanvas display =
    el [ width (px 320), height (px 240), Element.moveDown 240, Element.htmlAttribute (Attr.style "display" display) ]
        (Element.html (htmlKeyframeCanvas "canvas-kf-ref" display))


keyframeCanvas : Element msg
keyframeCanvas =
    el [ width (px 320), height (px 240) ] (Element.html (htmlKeyframeCanvas "canvas-kf" "block"))


htmlKeyframeCanvas : String -> String -> Html msg
htmlKeyframeCanvas id display =
    Html.canvas [ Attr.id id, Attr.width 320, Attr.height 240, Attr.style "display" display ] []


customRenderer : Device.Size -> Int -> Slider -> Html msg
customRenderer { width, height } nb_frames s =
    Html.node "custom-renderer"
        [ attribute "width" (String.fromFloat width)
        , attribute "height" (String.fromFloat height)
        , attribute "canvas-id" "canvas-kf"
        , attribute "canvas-id-ref" "canvas-kf-ref"
        , attribute "nb-frames" (String.fromInt nb_frames)
        , attribute "current" (String.fromInt s.current)
        ]
        []


bottomToolbar : Slider -> Bool -> Int -> Fixer -> Element Msg
bottomToolbar slid play fps fixer =
    Element.row [ width fill, height (px 50), Element.padding 10, Element.spacing 10 ]
        [ fpsViewer fps
        , playPauseButton play
        , slider fixer slid
        , pickRefButton play slid.current
        , restartFromButton play slid.current fixer
        , exportObjButton
        ]


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


pickRefButton : Bool -> Int -> Element Msg
pickRefButton play current_frame =
    if play then
        disabledButton "Keep until current frame" (Icon.toHtml 30 Icon.until)

    else
        abledButton (PickReference current_frame) "Keep until current frame" (Icon.toHtml 30 Icon.until)


restartFromButton : Bool -> Int -> Fixer -> Element Msg
restartFromButton play current_frame fixer =
    case ( play, fixer ) of
        ( False, ReferenceKeyframe baseKf ) ->
            restartFromButtonCondition baseKf current_frame

        ( False, KeyframesPair baseKf _ ) ->
            restartFromButtonCondition baseKf current_frame

        _ ->
            disabledButton "Restart from currrent frame" (Icon.toHtml 30 Icon.from)


restartFromButtonCondition : Int -> Int -> Element Msg
restartFromButtonCondition base current =
    if current > base then
        abledButton (RestartFrom base current) "Restart from current frame" (Icon.toHtml 30 Icon.from)

    else
        disabledButton "Restart from currrent frame" (Icon.toHtml 30 Icon.from)


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


disabledButton : String -> Html msg -> Element msg
disabledButton title icon =
    Html.div (centerFlexAttributes 50) [ icon ]
        |> Element.html
        |> Element.el
            [ Element.Font.color Style.disabledText
            , Element.htmlAttribute (Attr.title title)
            ]


slider : Fixer -> Slider -> Element Msg
slider fixer s =
    let
        fixerMarker =
            case fixer of
                NoFix ->
                    Element.none

                ReferenceKeyframe kf ->
                    fixerMarkeElement kf s.max

                KeyframesPair kf _ ->
                    fixerMarkeElement kf s.max
    in
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
        , Element.behindContent fixerMarker
        ]
        { onChange = Pick
        , label = Input.labelHidden "slider"
        , min = toFloat s.min
        , max = toFloat s.max
        , value = toFloat s.current
        , thumb = Input.defaultThumb
        , step = Just 1
        }


fixerMarkeElement : Int -> Int -> Element msg
fixerMarkeElement kf sliderMax =
    Element.row [ width fill, height fill, Element.paddingXY 7 0 ]
        [ el [ width (Element.fillPortion kf) ] Element.none
        , el [ width (px 3), height fill, Background.color (rgb255 255 0 0) ] Element.none
        , el [ width (Element.fillPortion (sliderMax - kf)) ] Element.none
        ]


loadDatasetButton : (Value -> msg) -> Element msg
loadDatasetButton loadDatasetMsg =
    let
        uniqueId =
            "load-dataset"

        icon =
            [ Icon.toHtml 60 Icon.database ]
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
