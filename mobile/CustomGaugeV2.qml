/*
    Copyright 2018 - 2019 Benjamin Vedder	benjamin@vedder.se

    This file is part of VESC Tool.

    VESC Tool is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    VESC Tool is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
    */

import QtQuick 2.0
import QtQuick.Controls 2.2
import QtQuick.Layouts 1.3
import Qt5Compat.GraphicalEffects
import QtQuick.Controls.Material 2.2

import Vedder.vesc.utility 1.0

Item {
    id: gauge
    property double minimumValue: 0
    property double maximumValue: 100
    property double value: 0
    property string unitText: ""
    property string typeText: ""
    property string tickmarkSuffix: ""
    property double labelStep: 10
    property double tickmarkScale: 1
    property color traceColor: Utility.getAppHexColor("lightestBackground")
    property double maxAngle: 144
    property double minAngle: -144

    // Geometry shared with the canvas/needle (mirrors the old CircularGaugeStyle).
    readonly property double outerRadius: Math.min(width, height) / 2

    // Map a gauge value to an angle in degrees (0 = pointing straight down,
    // positive = clockwise), matching QtQuick.Extras CircularGauge semantics.
    function valueToAngle(v) {
        var range = maximumValue - minimumValue
        if (range === 0) {
            return minAngle
        }
        var clamped = Math.max(minimumValue, Math.min(maximumValue, v))
        return minAngle + (clamped - minimumValue) / range * (maxAngle - minAngle)
    }

    Behavior on value {
        NumberAnimation {
            easing.type: Easing.OutCirc
            duration: 100
        }
    }

    onValueChanged: { background.requestPaint(); ticks.requestPaint() }
    onMinimumValueChanged: { background.requestPaint(); ticks.requestPaint() }
    onMaximumValueChanged: { background.requestPaint(); ticks.requestPaint() }
    onLabelStepChanged: ticks.requestPaint()
    onMinAngleChanged: { background.requestPaint(); ticks.requestPaint() }
    onMaxAngleChanged: { background.requestPaint(); ticks.requestPaint() }

    Item {
        id: gaugeArea
        width: gauge.outerRadius * 2
        height: gauge.outerRadius * 2
        anchors.centerIn: parent

        function d2r(degrees) {
            return degrees * (Math.PI / 180.0)
        }

        function isCovered(v) {
            var res = false
            if (gauge.value > 0) {
                if (v <= gauge.value && v >= 0) {
                    res = true
                }
            } else {
                if (v >= gauge.value && v <= 0) {
                    res = true
                }
            }
            return res
        }

        // Background: filled disc + trace arcs (was CircularGaugeStyle.background)
        Canvas {
            id: background
            anchors.fill: parent

            onPaint: {
                var outerRadius = gauge.outerRadius
                var ctx = getContext("2d")
                ctx.reset()
                ctx.beginPath()

                ctx.fillStyle = Utility.getAppHexColor("normalBackground")
                ctx.arc(outerRadius, outerRadius, outerRadius, 0, Math.PI * 2)
                ctx.fill()

                ctx.beginPath();
                ctx.strokeStyle = Utility.getAppHexColor("darkBackground")
                ctx.lineWidth = outerRadius
                ctx.arc(outerRadius,
                        outerRadius,
                        outerRadius / 2,
                        gaugeArea.d2r(gauge.valueToAngle(Math.max(gauge.value, 0)) - 90),
                        gaugeArea.d2r(gauge.valueToAngle(gauge.maximumValue) - 90));
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(outerRadius,
                        outerRadius,
                        outerRadius / 2,
                        gaugeArea.d2r(gauge.valueToAngle(gauge.minimumValue) - 90),
                        gaugeArea.d2r(gauge.valueToAngle(Math.min(gauge.value, 0)) - 90));
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(outerRadius,
                        outerRadius,
                        outerRadius / 2,
                        gaugeArea.d2r(gauge.valueToAngle(gauge.maximumValue) - 90),
                        gaugeArea.d2r(gauge.valueToAngle(gauge.minimumValue) - 90));
                ctx.stroke();

                ctx.beginPath();
                ctx.strokeStyle = Utility.getAppHexColor("normalText")
                ctx.lineWidth = 1
                ctx.arc(outerRadius,
                        outerRadius,
                        outerRadius - 0.5,
                        0, 2 * Math.PI);
                ctx.stroke();

                if (gauge.value < 0) {
                    ctx.beginPath();
                    ctx.strokeStyle = Utility.getAppHexColor("lightAccent")
                    ctx.lineWidth = outerRadius * 0.1
                    ctx.arc(outerRadius,
                            outerRadius,
                            outerRadius - outerRadius * 0.05,
                            gaugeArea.d2r(gauge.valueToAngle(gauge.value) - 90),
                            gaugeArea.d2r(gauge.valueToAngle(0) - 90));
                    ctx.stroke();
                } else {
                    ctx.beginPath();
                    ctx.strokeStyle = Utility.getAppHexColor("lightAccent")
                    ctx.lineWidth = outerRadius * 0.1
                    ctx.arc(outerRadius,
                            outerRadius,
                            outerRadius - outerRadius * 0.05,
                            gaugeArea.d2r(gauge.valueToAngle(0) - 90),
                            gaugeArea.d2r(gauge.valueToAngle(gauge.value) - 90));
                    ctx.stroke();
                }
            }
        }

        // Tick marks, minor tick marks and tick labels
        // (was CircularGaugeStyle.tickmark / minorTickmark / tickmarkLabel)
        Canvas {
            id: ticks
            anchors.fill: parent

            onPaint: {
                var outerRadius = gauge.outerRadius
                var ctx = getContext("2d")
                ctx.reset()

                if (gauge.labelStep <= 0) {
                    return
                }

                var labelInset = outerRadius * 0.28
                var minorCount = 4

                ctx.textAlign = "center"
                ctx.textBaseline = "middle"
                ctx.font = (outerRadius * 0.15) + "px sans-serif"

                for (var v = gauge.minimumValue;
                     v <= gauge.maximumValue + 1e-9;
                     v += gauge.labelStep) {
                    var covered = gaugeArea.isCovered(v)
                    var col = covered ? Utility.getAppHexColor("lightText")
                                      : Utility.getAppHexColor("lightestBackground")
                    var ang = gaugeArea.d2r(gauge.valueToAngle(v) - 90)

                    // Major tickmark: 2 x (outerRadius * 0.09), drawn radially,
                    // inset 2px from the rim (was CircularGaugeStyle.tickmarkInset).
                    var tickLen = outerRadius * 0.09
                    var tickOuter = outerRadius - 2
                    var tickInner = tickOuter - tickLen
                    ctx.beginPath()
                    ctx.strokeStyle = col
                    ctx.lineWidth = 2
                    ctx.moveTo(outerRadius + Math.cos(ang) * tickInner,
                               outerRadius + Math.sin(ang) * tickInner)
                    ctx.lineTo(outerRadius + Math.cos(ang) * tickOuter,
                               outerRadius + Math.sin(ang) * tickOuter)
                    ctx.stroke()

                    // Tickmark label
                    var labelRadius = outerRadius - labelInset
                    ctx.fillStyle = col
                    ctx.fillText(parseFloat(v * gauge.tickmarkScale).toFixed(0) + gauge.tickmarkSuffix,
                                 outerRadius + Math.cos(ang) * labelRadius,
                                 outerRadius + Math.sin(ang) * labelRadius)

                    // Minor tickmarks between this major and the next.
                    if (v + gauge.labelStep <= gauge.maximumValue + 1e-9) {
                        for (var m = 1; m < minorCount + 1; m++) {
                            var mv = v + gauge.labelStep * m / (minorCount + 1)
                            var mCovered = gaugeArea.isCovered(mv)
                            var mCol = mCovered ? Utility.getAppHexColor("lightText")
                                                : Utility.getAppHexColor("normalText")
                            var mAng = gaugeArea.d2r(gauge.valueToAngle(mv) - 90)
                            var mLen = outerRadius * 0.05
                            // inset 2px from the rim (was minorTickmarkInset)
                            var mOuter = outerRadius - 2
                            ctx.beginPath()
                            ctx.strokeStyle = mCol
                            ctx.lineWidth = 1.5
                            ctx.moveTo(outerRadius + Math.cos(mAng) * (mOuter - mLen),
                                       outerRadius + Math.sin(mAng) * (mOuter - mLen))
                            ctx.lineTo(outerRadius + Math.cos(mAng) * mOuter,
                                       outerRadius + Math.sin(mAng) * mOuter)
                            ctx.stroke()
                        }
                    }
                }
            }
        }

        // Needle (was CircularGaugeStyle.needle)
        Item {
            id: needleContainer
            anchors.centerIn: parent
            width: 1
            height: 1
            rotation: gauge.valueToAngle(gauge.value)

            Item {
                y: -gauge.outerRadius * 0.82
                x: -needle.width / 2
                height: gauge.outerRadius * 0.18
                width: needle.width

                Rectangle {
                    id: needle
                    height: parent.height
                    color: Utility.getAppHexColor("darkAccent")
                    width: height * 0.13
                    antialiasing: true
                    radius: 10
                }

                Glow {
                    anchors.fill: needle
                    radius: 5
                    samples: 10
                    spread: 0.6
                    color: Utility.getAppHexColor("lightAccent")
                    source: needle
                }
            }
        }

        // Foreground value/unit/type text (was CircularGaugeStyle.foreground)
        Item {
            anchors.fill: parent

            Text {
                id: speedLabel
                anchors.verticalCenterOffset: gauge.outerRadius * 0.08
                anchors.centerIn: parent
                text: gauge.value.toFixed(0)
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: gauge.outerRadius * 0.3
                color: Utility.getAppHexColor("lightText")
                antialiasing: true
            }

            Text {
                id: speedLabelUnit
                text: unitText
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: speedLabel.bottom
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: gauge.outerRadius * 0.15
                color: Utility.getAppHexColor("lightText")
                antialiasing: true
            }

            Text {
                id: typeLabel
                text: typeText
                verticalAlignment: Text.AlignVCenter
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -gauge.outerRadius * 0.3
                anchors.bottomMargin: gauge.outerRadius * 0.05
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: gauge.outerRadius * 0.15
                color: Utility.getAppHexColor("lightText")
                antialiasing: true
            }
        }
    }
}
