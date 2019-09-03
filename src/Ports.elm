-- This Source Code Form is subject to the terms of the Mozilla Public
-- License, v. 2.0. If a copy of the MPL was not distributed with this
-- file, You can obtain one at http://mozilla.org/MPL/2.0/


port module Ports exposing
    ( animationFrame
    , datasetLoaded
    , exportObj
    , loadDataset
    , newKeyFrame
    , resizes
    , restartFrom
    , track
    )

import Json.Encode exposing (Value)
import Packages.Device as Device


port resizes : (Device.Size -> msg) -> Sub msg


port loadDataset : { file : Value, camera : String } -> Cmd msg


port datasetLoaded : (Int -> msg) -> Sub msg


port animationFrame : (Float -> msg) -> Sub msg


port newKeyFrame : (Int -> msg) -> Sub msg


port track : () -> Cmd msg


port restartFrom : Int -> Cmd msg


port exportObj : () -> Cmd msg
