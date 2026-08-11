import QtQuick 2.12
import com.youdao.pen 1.0

import "../commons"
import "../i18n"

Canvas {
    id: id_canvas;
    width: 210;
    height: 50

    property int amplitude: 0
    property var radianOffset : 0;

    function start() {
        id_anim_wave.restart()
    }

    function stop() {
        id_anim_wave.stop()
    }

    onPaint: {
        var ctx = getContext("2d")
        ctx.lineWidth = 1
        ctx.strokeStyle = "blue"
        var dig=Math.PI/90;
        loop(ctx);
    }

    YTimer {
        id:id_anim_wave
        repeat: true;
        interval: 100;
        running: false;
        onTriggered: {
            id_canvas.requestPaint();
        }
        objectName: "YSpeechPage.qml_id_anim_wave"
    }

    function calcAttenuation(x) {
        return Math.pow(8 / (8 + Math.pow(x, 4)), 4);
    }

    //heightPercentage为振幅的显示比例
    function drawAcousticWave(ctx, heightPercentage, alpha, lineWidth, radianOffsets) {
        var halfCanvasHeight = id_canvas.height / 2;
        var attenuationCoefficient = 2;
        // 避免渲染超过限度
        var curAmp = Math.min(amplitude, 30)
        var halfWaveCount = 0.5 - curAmp/10;
        var amplitudePercentage = 0.5 + curAmp/80;
        var canvasWidth = id_canvas.width;
        //one
        var my_gradient=ctx.createLinearGradient(0,0,0,140);
        my_gradient.addColorStop(0,"rgba(240,58,76,1)");
        my_gradient.addColorStop(0.3,"rgba(240,58,76,0.9)");
        my_gradient.addColorStop(0.6,"rgba(240,58,76,0.3)");
        my_gradient.addColorStop(1,"rgba(240,58,76,0)");
        ctx.fillStyle = my_gradient
        ctx.globalAlpha = 0.8;
        ctx.lineWidth =  0.1;
        ctx.beginPath();
        ctx.moveTo(0, halfCanvasHeight);
        var x, y;
        for (var i = -attenuationCoefficient; i <= attenuationCoefficient; i += 0.01) {
            x = canvasWidth * (i + attenuationCoefficient) / (2 * attenuationCoefficient);
            y = halfCanvasHeight + halfCanvasHeight * amplitudePercentage * calcAttenuation(i) * heightPercentage *
                    Math.sin(halfWaveCount * i + radianOffsets);
            ctx.lineTo(x, y);
        }
        ctx.fill();
        ctx.stroke();

        //two
        my_gradient=ctx.createLinearGradient(0,0,0,140);
        my_gradient.addColorStop(0,"rgba(228,28,148,1)");
        my_gradient.addColorStop(0.3,"rgba(228,28,148,0.9)");
        my_gradient.addColorStop(0.6,"rgba(228,28,148,0.1)");
        my_gradient.addColorStop(1,"rgba(228,28,148,0)");
        ctx.beginPath();
        ctx.fillStyle = my_gradient
        ctx.lineWidth = 0.1
        ctx.moveTo(0, halfCanvasHeight);
        amplitudePercentage = 0.1 + curAmp/40
        halfWaveCount = 1 - curAmp/8
        for (i = -attenuationCoefficient; i <= attenuationCoefficient; i += 0.01) {
            x = canvasWidth * (i + attenuationCoefficient) / (2 * attenuationCoefficient);
            y = halfCanvasHeight + halfCanvasHeight * amplitudePercentage * calcAttenuation(i) * heightPercentage *
                    Math.sin(halfWaveCount * i + radianOffsets);
            ctx.lineTo(x, y);
        }
        ctx.fill();
        ctx.stroke();

        //three
        my_gradient=ctx.createLinearGradient(0,0,0,140);
        my_gradient.addColorStop(0,"rgba(125,17,233,1)");
        my_gradient.addColorStop(0.3,"rgba(125,17,233,0.9)");
        my_gradient.addColorStop(0.6,"rgba(125,17,233,0.1)");
        my_gradient.addColorStop(1,"rgba(125,17,233,0)");
        ctx.beginPath();
        ctx.fillStyle = my_gradient
        ctx.lineWidth = 0.1
        ctx.moveTo(0, halfCanvasHeight);
        amplitudePercentage = 0.18 + curAmp/45;
        halfWaveCount = 1.5 - curAmp/9
        for (i = -attenuationCoefficient; i <= attenuationCoefficient; i += 0.01) {
            //i是当前位置相对于整个长度的比率( x=width*(i+K)/(2*K))
            x = canvasWidth * (i + attenuationCoefficient) / (2 * attenuationCoefficient);
            //加offset相当于把sin曲线向右平移
            y = halfCanvasHeight + halfCanvasHeight * amplitudePercentage * calcAttenuation(i) * heightPercentage *
                    Math.sin(halfWaveCount * i + radianOffsets) * -1;
            ctx.lineTo(x, y);
        }
        ctx.fill();
        ctx.stroke();
    }

    function loop(ctx) {
        radianOffset = (radianOffset - 0.05) % (Math.PI*2);
        ctx.clearRect(0, 0, id_canvas.width, id_canvas.height);
        drawAcousticWave(ctx, 1, 1, 2, radianOffset);
    }
}
