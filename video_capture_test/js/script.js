"use strict";

var myVideoStream;
var myVideo;

// ローカルメディアの取得
window.onload = function()
{
    myVideo = document.getElementById("myVideo");
    getMedia();
}

function getMedia()
{
    getUserMedia({ "audio": true, "video": true }, gotUserMedia, didntGetUserMedia);
}

function gotUserMedia(stream)
{
    myVideoStream = stream;

    // キャプチャしたメディアストリーム<video>エレメントで再生
    attachMediaStream(myVideo, myVideoStream);
}

function didntGetUserMedia()
{
    console.log("couldn't get video");
}
