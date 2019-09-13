module Main exposing (main)

import Browser
import Element exposing (Element, centerX, centerY, el, fill, height, px, rgb255, width)
import Element.Background as Background
import Element.Border as Border
import Element.Events
import Element.Font
import Element.Input as Input
import Element.Keyed
import Html exposing (Html)
import Html.Attributes as Attr exposing (attribute)
import Html.Events.Extra.Mouse as Mouse
import Icon
import Json.Encode exposing (Value)
import Packages.Device as Device exposing (Device)
import Packages.FileInput as FileInput
import Ports
import Style
import Svg
import Svg.Attributes as SvgA


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
    | InteractiveFix Int Int (List PointFix) (List PointFix)


type alias PointFix =
    { id : Int
    , color : Element.Color
    , pos : ( Float, Float )
    }


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
    | ToggleInteractiveFix
    | ClickRef ( Float, Float )
    | ClickKey ( Float, Float )
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

        ( RestartFrom baseKf keyframe, DatasetLoaded device nb_frames _ play fps (InteractiveFix _ _ refPoints keyPoints) ) ->
            ( DatasetLoaded device nb_frames (sliderRestart keyframe) play fps (KeyframesPair baseKf keyframe)
            , Ports.restartFromP3p
                { reference = baseKf
                , restartFrom = keyframe
                , p3pRef = Debug.log "ref" (List.map .pos refPoints)
                , p3pKey = List.map .pos keyPoints
                }
            )

        ( ToggleInteractiveFix, DatasetLoaded device nb_frames slid play fps (KeyframesPair k1 k2) ) ->
            ( DatasetLoaded device nb_frames slid play fps (InteractiveFix k1 k2 [] [])
            , Cmd.none
            )

        ( ToggleInteractiveFix, DatasetLoaded device nb_frames slid play fps (InteractiveFix k1 k2 _ _) ) ->
            ( DatasetLoaded device nb_frames slid play fps (KeyframesPair k1 k2)
            , Cmd.none
            )

        ( ClickRef pos, DatasetLoaded device nb_frames slid play fps (InteractiveFix k1 k2 ref key) ) ->
            ( DatasetLoaded device nb_frames slid play fps (InteractiveFix k1 k2 (updatePoints pos ref) key)
            , Cmd.none
            )

        ( ClickKey pos, DatasetLoaded device nb_frames slid play fps (InteractiveFix k1 k2 ref key) ) ->
            ( DatasetLoaded device nb_frames slid play fps (InteractiveFix k1 k2 ref (updatePoints pos key))
            , Cmd.none
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


updatePoints : ( Float, Float ) -> List PointFix -> List PointFix
updatePoints pos points =
    case points of
        [] ->
            [ PointFix 0 (viridis 0) pos ]

        _ :: [] ->
            PointFix 1 (viridis 1) pos :: points

        _ :: _ :: [] ->
            PointFix 2 (viridis 2) pos :: points

        _ ->
            points


viridis : Int -> Element.Color
viridis id =
    case id of
        0 ->
            Element.rgba255 73 45 116 0.8

        1 ->
            Element.rgba255 23 137 139 0.8

        _ ->
            Element.rgba255 145 214 81 0.8


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


renderer : Device.Size -> Int -> Slider -> Fixer -> Element Msg
renderer size nb_frames s fixer =
    let
        ( kfCanvas, refCanvas ) =
            case fixer of
                NoFix ->
                    ( interactiveKeyframeCanvas "none" []
                    , interactiveReferenceCanvas "none" "none" []
                    )

                ReferenceKeyframe _ ->
                    ( interactiveKeyframeCanvas "none" []
                    , interactiveReferenceCanvas "none" "block" []
                    )

                KeyframesPair _ _ ->
                    ( interactiveKeyframeCanvas "none" []
                    , interactiveReferenceCanvas "none" "block" []
                    )

                InteractiveFix _ _ refPoints kfPoints ->
                    ( interactiveKeyframeCanvas "block" kfPoints
                    , interactiveReferenceCanvas "block" "block" refPoints
                    )
    in
    Element.Keyed.el
        [ width fill
        , height fill
        , Background.color (rgb255 255 220 255)
        , Element.inFront kfCanvas
        , Element.inFront refCanvas
        ]
        ( "rendererElement", Element.html (customRenderer size nb_frames s) )


interactiveReferenceCanvas : String -> String -> List PointFix -> Element Msg
interactiveReferenceCanvas displayInteractive displayCanvas points =
    el
        [ Element.inFront (interactiveSvg displayInteractive points)
        , Element.moveDown 240
        , Element.htmlAttribute (Mouse.onClick (\event -> ClickRef event.offsetPos))
        ]
        (referenceCanvas displayCanvas)


interactiveKeyframeCanvas : String -> List PointFix -> Element Msg
interactiveKeyframeCanvas display points =
    el
        [ Element.inFront (interactiveSvg display points)
        , Element.htmlAttribute (Mouse.onClick (\event -> ClickKey event.offsetPos))
        ]
        keyframeCanvas


interactiveSvg : String -> List PointFix -> Element Msg
interactiveSvg display points =
    Element.html <|
        Svg.svg
            [ SvgA.width "320"
            , SvgA.height "240"
            , Attr.style "display" display
            , Attr.style "pointer-events" "none"
            ]
            (List.map drawCircle points)


drawCircle : PointFix -> Svg.Svg msg
drawCircle { color, pos } =
    let
        ( cx, cy ) =
            pos
    in
    Svg.circle
        [ SvgA.cx (String.fromFloat cx)
        , SvgA.cy (String.fromFloat cy)
        , SvgA.r "5"
        , SvgA.fill (colorStr color)
        ]
        []


colorStr : Element.Color -> String
colorStr color =
    let
        { red, green, blue, alpha } =
            Element.toRgb color
    in
    "rgba("
        ++ String.fromInt (round (255 * red))
        ++ ","
        ++ String.fromInt (round (255 * green))
        ++ ","
        ++ String.fromInt (round (255 * blue))
        ++ ","
        ++ String.fromFloat alpha
        ++ ")"


referenceCanvas : String -> Element msg
referenceCanvas display =
    el [ width (px 320), height (px 240), Element.htmlAttribute (Attr.style "display" display) ]
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
    Element.row
        [ width fill
        , height (px 50)
        , Element.padding 10
        , Element.spacing 10
        , Element.above (fixerHelper fixer)
        ]
        [ fpsViewer fps
        , playPauseButton play
        , slider fixer slid
        , pickRefButton play slid.current
        , restartFromButton play slid.current fixer
        , interactiveFixButton fixer
        , exportObjButton
        ]


fixerHelper : Fixer -> Element msg
fixerHelper fixer =
    case fixer of
        InteractiveFix _ _ ref key ->
            fixerHelperText (List.length ref) (List.length key)

        _ ->
            Element.none


fixerHelperText : Int -> Int -> Element msg
fixerHelperText nbRefPoints nbKeyPoints =
    let
        textContent =
            if nbRefPoints == 3 && nbKeyPoints == 3 then
                "Now try again clicking on the 'Restart from current frame' button."

            else
                "Pick 3 corresponding points on each image."
    in
    el
        [ Element.alignRight
        , Background.color (Element.rgba255 255 255 255 0.8)
        , Element.padding 5
        , Element.clip
        , Element.Font.size 20
        ]
        (Element.text textContent)


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

        ( False, InteractiveFix ref key refPoints keyPoints ) ->
            interactiveRestartFromButton current_frame ref key (List.length refPoints) (List.length keyPoints)

        _ ->
            disabledButton "Restart from currrent frame" (Icon.toHtml 30 Icon.from)


interactiveRestartFromButton : Int -> Int -> Int -> Int -> Int -> Element Msg
interactiveRestartFromButton current ref key nbRefPoints nbKeyPoints =
    if current == key && nbRefPoints == 3 && nbKeyPoints == 3 then
        abledButton (RestartFrom ref key) "Restart from current frame" (Icon.toHtml 30 Icon.from)

    else
        disabledButton "Restart from currrent frame" (Icon.toHtml 30 Icon.from)


restartFromButtonCondition : Int -> Int -> Element Msg
restartFromButtonCondition base current =
    if current > base then
        abledButton (RestartFrom base current) "Restart from current frame" (Icon.toHtml 30 Icon.from)

    else
        disabledButton "Restart from currrent frame" (Icon.toHtml 30 Icon.from)


interactiveFixButton : Fixer -> Element Msg
interactiveFixButton fixer =
    case fixer of
        NoFix ->
            disabledButton "Pick points to fix camera pose" (Icon.toHtml 30 Icon.edit)

        ReferenceKeyframe _ ->
            disabledButton "Pick points to fix camera pose" (Icon.toHtml 30 Icon.edit)

        KeyframesPair _ _ ->
            abledButton ToggleInteractiveFix "Pick points to fix camera pose" (Icon.toHtml 30 Icon.edit)

        InteractiveFix _ _ _ _ ->
            activeButton ToggleInteractiveFix "Pick points to fix camera pose" (Icon.toHtml 30 Icon.edit)


activeButton : msg -> String -> Html msg -> Element msg
activeButton msg title icon =
    Html.div (centerFlexAttributes 50) [ icon ]
        |> Element.html
        |> Element.el
            [ Background.color Style.hoveredItemBG
            , Element.pointer
            , Element.Events.onClick msg
            , Element.htmlAttribute (Attr.title title)
            ]


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

                InteractiveFix kf _ _ _ ->
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
