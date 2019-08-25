module Main exposing (main)

import Browser
import Element exposing (Element, centerY, el, fill, height, padding, px, rgb255, text, width)
import Element.Background as Background
import Element.Border as Border
import Element.Font as Font
import Element.Input as Input
import Html exposing (Html)
import Html.Attributes exposing (attribute)
import Time


main : Program () Slider Msg
main =
    Browser.element
        { init = \() -> ( initialModel, Cmd.none )
        , view = view
        , update = update
        , subscriptions = subscriptions
        }


type alias Slider =
    { min : Int
    , max : Int
    , current : Int
    }


initialModel : Slider
initialModel =
    { min = 0
    , max = 1
    , current = 0
    }


type Msg
    = IncrementMax
    | Pick Float


update : Msg -> Slider -> ( Slider, Cmd Msg )
update msg model =
    case msg of
        IncrementMax ->
            ( { model | max = model.max + 1 }, Cmd.none )

        Pick value ->
            ( { model | current = round value }, Cmd.none )


subscriptions : Slider -> Sub Msg
subscriptions _ =
    Time.every 1000 (always IncrementMax)


view : Slider -> Html Msg
view model =
    Element.layout [] (appLayout model)


appLayout : Slider -> Element Msg
appLayout model =
    Element.column [ width fill, height fill ]
        [ renderer model
        , el [ width fill, height (px 50), Element.paddingXY 10 0 ] (slider model)
        ]


renderer : Slider -> Element msg
renderer model =
    el
        [ width fill
        , height fill
        , Background.color (rgb255 240 0 245)
        , Font.color (rgb255 255 255 255)
        , padding 30
        ]
        (Element.html (customRenderer model))


customRenderer : Slider -> Html msg
customRenderer s =
    Html.node "custom-renderer"
        [ attribute "value" (String.fromInt s.current)
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
