"use strict";

$(function()
{
    var mode = 'test';

    // Web Speech API で何をしゃべったかメモ
    //var recognition = new webkitSpeechRecognition();
    //recognition.continuous     = true; // 複数の連続した認識を有効にする
    //recognition.interimResults = true; // 途中結果を返す
    //recognition.lang           = 'ja'; // 指定しない場合はドキュメントルートのlangが使われる（BCP 47 を参照）
    //recognition.start();
    var spoken = '';

    // WAVデータ・朗読するテキストの名前の送信用
    var keep_alive_interval = 180000; // ms（config の inactivity_timeout より小さい値でなければならない）
    var uri                 = 'wss://' + location.hostname + '/voice2wav';
    var ws                  = new WebSocket(uri);
    ws.binaryType           = 'arraybuffer';

    // 音声バッファ時間(音声録音開始前時間)
    // この値が音声録音開始イベント前の音声録音時間
    var beforeSecond = 0.2;

    // ここに録音用音声データを保存
    var recentSavedVoice = null;
    var savedVoiceList   = [ [ ] ];

    var is_recording = false; // 音声録音中か否か
    var is_playing   = false; // 音声再生中か否か

    // ブラウザにより異なるAPIを統一
    window.AudioContext = window.AudioContext || window.webkitAudioContext || window.mozAudioContext || window.msAudioContext;
    window.URL          = window.URL || window.webkitURL;

    //サンプリングレート、バッファサイズ等
    var audioContext      = new AudioContext();
    var sampleRate        = audioContext.sampleRate; // AudioContextが扱うオーディオのサンプルレート（１秒あたりのサンプルフレーム数）
    var bufferSize        = 4096;
    var audioData         = [];
    var bufferArrayLength = sampleRate / bufferSize * beforeSecond;

    // 音量解析用
    var analyser    = new Array(3);
    var analysedata = new Array(3);
    var ave_gain    = new Array(3);
    var b_ave_gain  = new Array(3);
    var record_cnt  = 0;

    // 音声可視化用
    var WIDTH       = 256;
    var HEIGHT      = 128;
    var canvas      = document.querySelector('canvas');
    var drawContext = canvas.getContext('2d');

    // 状態表示用
    var status_elem = document.querySelector('#status');

    // 朗読対象テキスト表示用
    var rodoku_text_elem = $("#rodoku-text #text");
    var page_no_elem     = $("#no input");
    var page_max_elem    = $("#no span");
    var page_max         = 0;
    var pe;
    var page_list = [];

    // 投稿時の名前
    var username_elem = $("#rodoku_submit #profile input[type='text']");

    // その他
    var numChannels = 1;
    var src;

    for (var i = 0; i < analyser.length; i++)
    {
        analyser[i] = audioContext.createAnalyser();
    }

    for (var i = 0; i < analysedata.length; i++)
    {
        analysedata[i] = new Uint8Array(256);
    }

    // 初期化用の空のデータ用意
    var nosound = new Float32Array(bufferSize);

    // 音声録音開始前時間分のバッファ準備
    function initAudioData()
    {
        if (mode === 'test') console.log('initAudioData');

        audioData = [];

        for (var i = 0; i < bufferArrayLength; i++)
        {
            audioData.push(nosound);
        }
    }

    // マイクから音声を検知したとき
    // onRecognized()を呼び出す処理は別途書く必要あり
    function onRecognized()
    {
        if (mode === 'test') console.log('onRecognized');

        //音声録音開始前時間分の音声データを保存
        recentSavedVoice = audioData;

        // オーディオデータを新規作成
        initAudioData();
    }

    // 毎音声処理
    function onAudioProcess(e)
    {
        if (mode === 'test') console.log('onAudioProcess');

        // 音声データを取得
        var input = e.inputBuffer.getChannelData(0);

        //console.log(e);

        var bufferData = new Float32Array(bufferSize);

        // 音声データをバッファに書き込む
        for (var i = 0; i < bufferSize; i++)
        {
            bufferData[i] = input[i];
        }

        // 音声録音開始前時間分の音声データを毎回プッシュをしては、シフトして前回のデータを削除
        audioData.push(bufferData);
        audioData.shift();

        // マイクから閾値以上の音量が入っている間、音声データを保存
        // is_recording は音声の音量をみる処理を書いて変更します（今回はここの説明なし）
        if (is_recording)
        {
            recentSavedVoice.push(bufferData);
        }
    }

    function didntGetUserMedia(e)
    {
        if (mode === 'test') console.log('didntGetUserMedia');

        console.log(e);
    }

    var animation = function ()
    {
        if (mode === 'test') console.log('animation');

        // 音声がしきい値以上で録音
        for (var i = 0; i < b_ave_gain.length; i++)
        {
            b_ave_gain[i] = 0;
        }

        for (var i = 0; i < analyser.length; i++)
        {
            analyser[i].getByteFrequencyData(analysedata[i]);
        }

        for (var i = 0; i < analysedata[0].length; i++)
        {
            b_ave_gain[0] = b_ave_gain[0] + analysedata[0][i];
            b_ave_gain[1] = b_ave_gain[1] + analysedata[1][i];
            b_ave_gain[2] = b_ave_gain[2] + analysedata[2][i];
        }

        for (var i = 0; i < ave_gain.length; i++)
        {
            ave_gain[i] = b_ave_gain[i] / analysedata[i].length;
        }

        /* -------------------- *
         * 音を可視化する       *
         * -------------------- */
        drawContext.clearRect(0, 0, WIDTH, HEIGHT); // 前回の描画結果をクリア

        // 周波数領域の描画
        var freqDomain = new Uint8Array(analyser[0].frequencyBinCount);
        analyser[0].getByteFrequencyData(freqDomain);

        for (var i = 0; i < analyser[0].frequencyBinCount; i++)
        {
            var value    = freqDomain[i];
            var percent  = value / 256;
            var height   = HEIGHT * percent;
            var offset   = HEIGHT - height - 1;
            var barWidth = WIDTH / analyser[0].frequencyBinCount;
            var hue      = i / analyser[0].frequencyBinCount * 360;

            drawContext.fillStyle = 'hsl(' + hue + ', 100%, 50%)';
            drawContext.fillRect(i * barWidth, offset, barWidth, height);
        }

        // 時間領域の描画
        var timeDomain = new Uint8Array(analyser[0].frequencyBinCount);
        analyser[0].getByteTimeDomainData(timeDomain);

        for (var i = 0; i < analyser[0].frequencyBinCount; i++)
        {
            var value    = timeDomain[i];
            var percent  = value / 256;
            var height   = HEIGHT * percent;
            var offset   = HEIGHT - height - 1;
            var barWidth = WIDTH / analyser[0].frequencyBinCount;

            //console.log(timeDomain[i]);

            drawContext.fillStyle = 'black';
            drawContext.fillRect(i * barWidth, offset, 1, 1);
        }
        // -- 音の可視化処理 終了

        //console.log(ave_gain[0]);

        if ( ! is_recording )
        {
            //if ( ave_gain[0] > 120 && ! is_playing )
            if (ave_gain[0] > 80)
            {
                console.log("record start");
                onRecognized();
                is_recording = true;
                status_elem.innerText = "録音中♪";
                status_elem.style.color = "red";
            }
        }
        else
        {
            if (ave_gain[0] <= 80)
            {
                record_cnt++;

                if (record_cnt > 50)
                {
                    is_recording = false;
                    console.log("record finish");
                    status_elem.innerText = "音声認識できませんでした（待機中）";
                    status_elem.style.color = "black";

                    // 音声認識が終わったら、音声録音終了に切り替えたのでコメントアウト
                    /*
                    is_playing   = true;
                    is_recording = false;
                    status_elem.innerText = "待機中";
                    status_elem.style.color = "black";
                    console.log("record finish");
                    //console.debug('PlaySavedVoice', recentSavedVoice);
                    playVoice(recentSavedVoice);
                    */
                }
            }
            else
            {
                record_cnt = 0;
            }
        }

        requestAnimationFrame(animation);
    };

    function gotUserMedia(stream)
    {
        if (mode === 'test') console.log('gotUserMedia');

        // 音声処理ノード
        var javascriptnode = audioContext.createScriptProcessor(bufferSize, 1, 1); // メソッド名がcreateJavaScriptNodeから変更された

        animation();

        var mediastreamsource = audioContext.createMediaStreamSource(stream);
        mediastreamsource.connect(javascriptnode);
        mediastreamsource.connect(analyser[0]);
        javascriptnode.onaudioprocess = onAudioProcess;
        javascriptnode.connect(audioContext.destination);
    }

    // 音声処理開始
    function initialize()
    {
        if (mode === 'test') console.log('initialize');

        // audio:true で音声取得を有効にする
        getUserMedia({ "audio": true }, gotUserMedia, didntGetUserMedia);
    }

    // dataは再生する音声データ
    function playVoice(data)
    {
        if (mode === 'test') console.log('playVoice');

        if (data == null) return;

        var buf     = audioContext.createBuffer(1, data.length * bufferSize, sampleRate);
        var channel = buf.getChannelData(0);

        // 再生する音声データを書き込む
        for (var i = 0, ilen = data.length; i < ilen; i++)
        {
            for (var j = 0, jlen = bufferSize; j < jlen; j++)
            {
                channel[ i * bufferSize + j ] = data[i][j];
            }
        }

        src = audioContext.createBufferSource();
        src.onended = srcendedCallback;
        src.buffer = buf;
        src.playbackRate.value = 1.0; // 再生スピード
        src.connect(audioContext.destination);
        src.start(0); // 音声再生スタート

        // 音声再生が終了srcendedCallbackを呼び出す（src.onended 非対応用）
        //window.setTimeout(srcendedCallback, ((src.buffer.duration / src.playbackRate.value) * 1000));

        //console.log(channel);

        var savedVoice = [];

        for (var i = 0; i < data.length; i++)
        {
            savedVoice.push(data[i]);
        }

        savedVoiceList.push(savedVoice);

        // WAV形式に変換
        var dataview  = encodeWAV(mergeBuffers(data));
        var audioBlob = new Blob([ dataview ], { type: "audio/wav" });
        var url       = window.URL.createObjectURL(audioBlob);

        /*
        console.log(dataview);
        console.log(audioBlob);
        */

        //ws.send(audioBlob);

        $("#voice_list").show("normal");
        $("#rodoku_submit").show("normal");

        var now    = new Date();
        var year   = now.getFullYear();
        var month  = now.getMonth() + 1;
        var week   = now.getDay();
        var day    = now.getDate();
        var hour   = now.getHours();
        var minute = now.getMinutes();
        var second = now.getSeconds();

        var time = year + "年" + month + "月" + day + "日 " + hour + "時" + minute + "分" + second + "秒";

        $("#voice_list ol").append('<li><a href="' + url + '" target="_blank">' + time + ' に録音された音声</a>（' + Math.floor(audioBlob.size / 1024) +  'KB） [<span id="savedVoice-' + (savedVoiceList.length - 1) + '" class="savedVoice">削除</span>] <br><input type="text" value="' + spoken  + '" placeholder="メモを書けます。"></li>');
        $("#voice_list").scrollTop($("#voice_list")[0].scrollHeight);

        function srcendedCallback(event)
        {
            console.log('playVoice ended.');
        }
    }

    // https://github.com/mattdiamond/Recorderjs/blob/master/recorderWorker.js より
    function writeString(view, offset, string)
    {
        for (var i = 0; i < string.length; i++)
        {
            view.setUint8(offset + i, string.charCodeAt(i));
        }
    }

    // https://github.com/mattdiamond/Recorderjs/blob/master/recorderWorker.js より
    function floatTo16BitPCM(output, offset, input)
    {
        for (var i = 0; i < input.length; i++, offset += 2)
        {
            var s = Math.max(-1, Math.min(1, input[i]));
            output.setInt16(offset, s < 0 ? s * 0x8000 : s * 0x7FFF, true);
        }
    }

    // Ref. http://qiita.com/HirokiTanaka/items/56f80844f9a32020ee3b
    function mergeBuffers(audioData)
    {
        var sampleLength = 0;

        for (var i = 0; i < audioData.length; i++)
        {
            sampleLength += audioData[i].length;
        }

        var samples   = new Float32Array(sampleLength);
        var sampleIdx = 0;

        for (var i = 0; i < audioData.length; i++)
        {
            for (var j = 0; j < audioData[i].length; j++)
            {
                samples[sampleIdx] = audioData[i][j];
                sampleIdx++;
            }
        }

        return samples;
    }

    // https://github.com/mattdiamond/Recorderjs/blob/master/recorderWorker.js より
    // samples: Float32array
    function encodeWAV(samples)
    {
        /*
         * ArrayBuffer は任意のデータのかたまりを表すのに有用なオブジェクトです。
         * 多くの場合、そのようなデータはディスク装置やネットワークから読み込まれ、
         * また前に説明した Typed Array Views によって示される配置の制約に従っていません。
         * 加えてそのデータは大抵、実際のところ異種のデータで構成され、またバイト順が定義済みの状態にあります
         * DataView ビューは ArrayBuffer に対して、上記のようなデータを低レベルで読み出したり書き込んだりするためのインタフェースを提供します。
         *
         * https://developer.mozilla.org/ja/docs/Web/JavaScript/Typed_arrays/DataView より
         */

        /*
         * setUintew(unsigned long byteOffset, unsigned long value, optional boolean littleEndian);
         */

        //console.log(samples.length);

        var buffer = new ArrayBuffer(44 + samples.length * 2);
        var view   = new DataView(buffer);

        /* RIFF identifier */
        writeString(view, 0, 'RIFF');

        /* RIFF chunk length */
        view.setUint32(4, 32 + samples.length * 2, true);

        /* RIFF type */
        writeString(view, 8, 'WAVE');

        /* format chunk identifier */
        writeString(view, 12, 'fmt ');

        /* format chunk length */
        /* リニアPCMならば16   */
        view.setUint32(16, 16, true);

        /* sample format (raw) */
        /* リニアPCMならば1    */
        view.setUint16(20, 1, true);

        /* channel count                   */
        /* モノラルならば1 ステレオならば2 */
        view.setUint16(22, numChannels, true);

        /* sample rate */
        view.setUint32(24, sampleRate, true);

        /* byte rate (sample rate * block align) */
        view.setUint32(28, sampleRate * 2, true);

        /* block align (channel count * bytes per sample) */
        view.setUint16(32, numChannels * 2, true);

        /* bits per sample */
        view.setUint16(34, 16, true);

        /* data chunk identifier */
        writeString(view, 36, 'data');

        /* data chunk length */
        view.setUint32(40, samples.length * 2, true);

        floatTo16BitPCM(view, 44, samples);

        return view;
    }

    ws.onopen = function()
    {
        setInterval(function()
        {
            if (ws.readyState === 1) ws.send('keep-alive');
        }
        , keep_alive_interval);
    };

    ws.onclose = function()
    {
        status_elem.innerText   = "接続が切れました。ページを再度読み込んでみてください。";
        status_elem.style.color = "red";
        console.log('接続が切れました');
    };
    ws.onerror   = function(e) { console.log(e); };
    ws.onmessage = function(e)
    {
        if (e.data.constructor === String)
        {
            var data = JSON.parse(e.data);

            if (data.error)
            {
                if (data.type === 'text-select')
                {
                    console.log(data.error);
                    return;
                }
                else if (data.type === 'username-change')
                {
                    username_elem.val("nanashi");
                    alert(data.error);
                }
            }

                 if (data.type === 'text-select')        { load_text(data.text); load_rodoku_list(data.rodoku_list); }
            else if (data.type === 'rodoku_list_update') { load_rodoku_list(data.rodoku_list);                       }
        }
        else if (e.data.constructor === ArrayBuffer)
        {
            if (typeof src !== 'undefined') src.stop();

            console.log(e);

            audioContext.decodeAudioData(e.data, function (buf) {
                src = audioContext.createBufferSource();
                src.buffer = buf;
                src.playbackRate.value = 1.0; // 再生スピード
                src.connect(audioContext.destination);
                src.start(0); // 音声再生スタート
            });
        }
    };

    // オーディオバッファ初期化
    initAudioData();

    // 音声処理開始
    initialize();

    // 朗読するテキストの選択
    $("#rodoku_text").on("change", function()
    {
        var selected_text = $(this).val();
        ws.send( JSON.stringify({ "type": "text-select", "text-name": selected_text }) );
    });

    // 「朗読を投稿する」画像をクリック時の処理
    $("#rodoku_submit img").on("click", function()
    {
        var savedVoice = [];

        for (var i = 0; i < savedVoiceList.length; i++)
        {
            Array.prototype.push.apply(savedVoice, savedVoiceList[i]);
        }

        var dataview  = encodeWAV(mergeBuffers(savedVoice));
        var audioBlob = new Blob([ dataview ], { type: "audio/wav" });

        ws.send(audioBlob); // 音声データを結合して保存

        // 次の朗読に備えてクリア
        $("#voice_list ol").empty();
        $("#voice_list").hide("normal");
        $("#rodoku_submit").hide("normal");
        savedVoiceList = [ [] ];
    });

    $("#rodoku_submit img").on("mousedown", function()
    {
        $(this).attr("src", "/img/submit_pushed.gif");
    });

    $("#rodoku_submit img").on("mouseup mouseout", function()
    {
        $(this).attr("src", "/img/submit_normal.gif");
    });

    function load_text(text)
    {
        pe = Nehan.createPagedElement({ layout: { fontImgRoot:"//nehan.googlecode.com/hg/char-img", fontFamily:"'ヒラギノ明朝 Pro W3','Hiragino Mincho Pro','HiraMinProN-W3','ヒラギノ明朝 W3 JIS2004','IPAex明朝','IPAex Mincho','IPA明朝','IPA Mincho','Meiryo','メイリオ','ＭＳ 明朝','MS Mincho', monospace" } });

        page_list = [];

        pe.setStyle("body", {
               "flow": "tb-rl",
          "font-size": 16,
              "width": 646,
             "height": 256,
        });

        pe.setContent(text, {
            onProgress: function(tree) { page_max = tree.pageNo + 1; page_max_elem.text(page_max); },
            onComplete: function(time)
            {
                console.log(time + " ms");

                if (page_max != 0)
                {
                    page_no_elem.attr("max", page_max);
                    update_page_no();
                }
            }
        });

        page_list[1] = pe.getElement().innerHTML;
        rodoku_text_elem.html(page_list[1]);
    }

    function load_rodoku_list(rodoku_list)
    {
        if (typeof src !== 'undefined') src.stop();

        $("#rodoku_list").empty().append('<option value="" selected>選択してください</option>');

        for (var i = 0; i < rodoku_list.length; i++)
        {
            $("#rodoku_list").append('<option value="' + rodoku_list[i] + '">' + rodoku_list[i] + '</option>');
        }
    }

    document.getElementById("next").onclick  = function() { if (page_max !== 0) { pe.setNextPage();          update_page_no(); } };
    document.getElementById("prev").onclick  = function() { if (page_max !== 0) { pe.setPrevPage();          update_page_no(); } };
    document.getElementById("first").onclick = function() { if (page_max !== 0) { pe.setPage(0);             update_page_no(); } };
    document.getElementById("last").onclick  = function() { if (page_max !== 0) { pe.setPage(page_max - 1);  update_page_no(); } };

    page_no_elem.on("change", function()
    {
        var page_no = num_z2h( $(this).val() );

        try {
            pe.setPage(page_no - 1);
        }
        catch(e) {
            console.log("ページが見つかりませんでした");
            return;
        }

        update_page_no();
    });

    $("#rodoku_list").on("change", function()
    {
        var filename = $(this).val();
        ws.send( JSON.stringify({ "type": "rodoku-reproduction", "filename": filename }) );
    });

    // 朗読者の名前の更新処理
    username_elem.on("change", function()
    {
        var username = $(this).val();
        ws.send( JSON.stringify({ "type": "username-change", "username": username }) );
    });

    $("body").on("click", "span.savedVoice", function()
    {
        // 削除をクリックで連結対象の音声を削除する
        $(this).parent().remove();
        var savedVoiceIndex = $(this).attr("id").split("-")[1];
        savedVoiceList.splice(savedVoiceIndex, 1);

        // 連結対象の音声が０個になったら連結対象音声を隠す
        var numSavedVoice = $("#voice_list li").length;

        if (numSavedVoice === 0)
        {
            $("#voice_list").hide("normal");
            $("#rodoku_submit").hide("normal");
        }
    });

    function update_page_no()
    {
        var no = pe.pageNo + 1;

        if (page_list[no] == null) { var html = pe.getElement(); page_list[no] = html.innerHTML; } // page_list はIEでページを戻るときに内容が消えるバグを防ぐ用

        rodoku_text_elem.html(page_list[no]);

        page_no_elem.val(no);
    }

    function num_z2h(a)
    {
        return a.replace(/[０１２３４５６７８９]/g
            , function(a){
                var b = "０１２３４５６７８９".indexOf(a);
                return (b !== -1) ? b : a;
            }
        );
    }

    //recognition.onresult = function(event)
    //{
    //    var result = event.results[event.results.length - 1];

    //    if (result.isFinal)
    //    {
    //        if (recentSavedVoice !== null)
    //        {
    //            console.log("音声認識されました");
    //            spoken = result[0].transcript.trim();

    //            is_playing   = true;
    //            is_recording = false;
    //            status_elem.innerText = "待機中";
    //            status_elem.style.color = "black";
    //            console.log("record finish");
    //            playVoice(recentSavedVoice);

    //            console.log(spoken);
    //        }

    //        recentSavedVoice = null;
    //    }
    //};

    //recognition.onstart = function()
    //{
    //    console.log("音声認識スタート！");
    //};

    //recognition.onerror = function(event)
    //{
    //    console.log("音声認識エラー：" + event.error);
    //};

    //recognition.onend = function()
    //{
    //    console.log("音声認識を終了しました");
    //    recognition.start();
    //};
});
