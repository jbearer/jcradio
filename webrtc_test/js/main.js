/*
 *  Copyright (c) 2015 The WebRTC project authors. All Rights Reserved.
 *
 *  Use of this source code is governed by a BSD-style license
 *  that can be found in the LICENSE file in the root of the source
 *  tree.
 */
/* global TimelineDataSeries, TimelineGraphView */

'use strict';

const audio2 = document.querySelector('audio#audio2');
const callButton = document.querySelector('button#callButton');
const hangupButton = document.querySelector('button#hangupButton');
hangupButton.disabled = true;
callButton.onclick = call;
hangupButton.onclick = hangup;

var config = {"iceServers": [{"urls": ["stun:stun.l.google.com:19302"]}]};
var options = {optional: []};

var pc;
var ws;


var iceCandidates;
var hasRemoteDesc;


function call() {
    callButton.disabled = true;
    console.log('Starting call');
    // Get the address to open WebSocket
    var address = document.getElementById('address').value;
    var protocol = location.protocol === "https:" ? "wss:" : "ws:";
    var wsurl = protocol + '//' + address;


    console.log("opening web socket: " + wsurl);
    ws = new WebSocket(wsurl);
    iceCandidates = [];
    hasRemoteDesc = false;


    function addIceCandidates() {
        if (hasRemoteDesc) {
            iceCandidates.forEach(function (candidate) {
                pc.addIceCandidate(candidate,
                    function () {
                        console.log("IceCandidate added: " + JSON.stringify(candidate));
                    },
                    function (error) {
                        console.error("addIceCandidate error: " + error);
                    }
                );
            });
            iceCandidates = [];
        }
    };

    ws.onopen = function () {
        // Reset everything on WebSocket open
        pc = new RTCPeerConnection(config, options);
        iceCandidates = [];
        hasRemoteDesc = false;

        pc.onicecandidate = function (event) {
            if (event.candidate) {
                var candidate = {
                    sdpMLineIndex: event.candidate.sdpMLineIndex,
                    sdpMid: event.candidate.sdpMid,
                    candidate: event.candidate.candidate
                };
                var request = {
                    what: "addIceCandidate",
                    data: JSON.stringify(candidate)
                };
                ws.send(JSON.stringify(request));
            } else {
                console.log("end of candidates.");
            }
        };

        // Do some track
        console.log("Set PC ontrack");
        pc.ontrack = function (event) {
            console.log("HERE: ontrack");
            if (audio2.srcObject !== event.streams[0]) {
                audio2.srcObject = event.streams[0];
                hangupButton.disabled = false;

                console.log('Received remote stream');
            }
        };

        pc.onremovestream = function (event) {
            console.log("the stream has been removed: do your stuff now");
        };

        pc.ondatachannel = function (event) {
            console.log("a data channel is available: do your stuff with it");
            // For an example, see https://www.linux-projects.org/uv4l/tutorials/webrtc-data-channels/
        };


        /* kindly signal the remote peer that we would like to initiate a call */
        var request = {
            what: "call",
            options: {
                // If forced, the hardware codec depends on the arch.
                // (e.g. it's H264 on the Raspberry Pi)
                // Make sure the browser supports the codec too.
                force_hw_vcodec: true,
                vformat: 30, /* 30=640x480, 30 fps */
                trickle_ice: true
            }
        };
        console.log("send message " + JSON.stringify(request));
        ws.send(JSON.stringify(request));
    };


    ws.onmessage = function (evt) {
        var msg = JSON.parse(evt.data);
        var what = msg.what;
        var data = msg.data;

        console.log("received message " + JSON.stringify(msg));

        switch (what) {
            case "offer":
                var mediaConstraints = {
                    optional: [],
                    mandatory: {
                        OfferToReceiveAudio: true,
                        OfferToReceiveVideo: false
                    }
                };
                pc.setRemoteDescription(new RTCSessionDescription(JSON.parse(data)),
                        function onRemoteSdpSuccess() {
                            hasRemoteDesc = true;
                            addIceCandidates();
                            pc.createAnswer(function (sessionDescription) {
                                pc.setLocalDescription(sessionDescription);
                                var request = {
                                    what: "answer",
                                    data: JSON.stringify(sessionDescription)
                                };
                                ws.send(JSON.stringify(request));
                            }, function (error) {
                                alert("failed to create answer: " + error);
                            }, mediaConstraints);
                        },
                        function onRemoteSdpError(event) {
                            alert('failed to set the remote description: ' + event);
                            ws.close();
                        }
                );

                break;

            case "answer":
                break;

            case "message":
                alert(msg.data);
                break;

            case "iceCandidate": // received when trickle ice is used (see the "call" request)
                if (!msg.data) {
                    console.log("Ice Gathering Complete");
                    break;
                }
                var elt = JSON.parse(msg.data);
                let candidate = new RTCIceCandidate({sdpMLineIndex: elt.sdpMLineIndex, candidate: elt.candidate});
                iceCandidates.push(candidate);
                addIceCandidates(); // it internally checks if the remote description has been set
                break;

            case "iceCandidates": // received when trickle ice is NOT used (see the "call" request)
                var candidates = JSON.parse(msg.data);
                for (var i = 0; candidates && i < candidates.length; i++) {
                    var elt = candidates[i];
                    let candidate = new RTCIceCandidate({sdpMLineIndex: elt.sdpMLineIndex, candidate: elt.candidate});
                    iceCandidates.push(candidate);
                }
                addIceCandidates();
                break;
        }
    };

    ws.onclose = function (event) {
        console.log('socket closed with code: ' + event.code);
        if (pc) {
            pc.close();
            pc = null;
            ws = null;
        }
        audio2.srcObject = null;
    };

    ws.onerror = function (event) {
        alert("An error has occurred on the websocket (make sure the address is correct)!");
    };
}



function hangup() {
    console.log('Ending call');

    if (ws) {
        var request = {
            what: "hangup"
        };
        console.log("send message " + JSON.stringify(request));
        ws.send(JSON.stringify(request));
    }

    pc.close();
    pc = null;
    hangupButton.disabled = true;
    callButton.disabled = false;
}


// function call() {
//     callButton.disabled = true;
//     console.log('Starting call');

//     // const servers = null;
//     // pc1 = new RTCPeerConnection(servers);
//     // console.log('Created local peer connection object pc1');
//     // pc1.onicecandidate = e => onIceCandidate(pc1, e);
//     // pc2 = new RTCPeerConnection(servers);
//     // console.log('Created remote peer connection object pc2');
//     pc2.onicecandidate = e => onIceCandidate(pc2, e);
//     pc2.ontrack = gotRemoteStream;
//     console.log('Requesting local stream');
//     navigator.mediaDevices
//             .getUserMedia({
//                 audio: true,
//                 video: false
//             })
//             .then(gotStream)
//             .catch(e => {
//                 alert(`getUserMedia() error: ${e.name}`);
//             });
// }

// function gotRemoteStream(e) {
//     if (audio2.srcObject !== e.streams[0]) {
//         audio2.srcObject = e.streams[0];
//         console.log('Received remote stream');
//     }
// }

// function gotStream(stream) {
//     hangupButton.disabled = false;
//     console.log('Received local stream');
//     localStream = stream;
//     const audioTracks = localStream.getAudioTracks();
//     if (audioTracks.length > 0) {
//         console.log(`Using Audio device: ${audioTracks[0].label}`);
//     }
//     localStream.getTracks().forEach(track => pc1.addTrack(track, localStream));
//     console.log('Adding Local Stream to peer connection');

//     pc1.createOffer(offerOptions)
//             .then(gotDescription1, onCreateSessionDescriptionError);

// }

// function getOtherPc(pc) {
//     return (pc === pc1) ? pc2 : pc1;
// }

// function getName(pc) {
//     return (pc === pc1) ? 'pc1' : 'pc2';
// }

// function onIceCandidate(pc, event) {
//     getOtherPc(pc).addIceCandidate(event.candidate)
//             .then(
//                     () => onAddIceCandidateSuccess(pc),
//                     err => onAddIceCandidateError(pc, err)
//             );
//     console.log(`${getName(pc)} ICE candidate:\n${event.candidate ? event.candidate.candidate : '(null)'}`);
// }

// function onAddIceCandidateSuccess() {
//     console.log('AddIceCandidate success.');
// }

// function onAddIceCandidateError(error) {
//     console.log(`Failed to add ICE Candidate: ${error.toString()}`);
// }

// function onSetSessionDescriptionError(error) {
//     console.log(`Failed to set session description: ${error.toString()}`);
// }

// function onCreateSessionDescriptionError(error) {
//     console.log(`Failed to create session description: ${error.toString()}`);
// }

// function gotDescription1(desc) {
//     console.log(`Offer from pc1\n${desc.sdp}`);
//     pc1.setLocalDescription(desc)
//             .then(() => {
//                 pc2.setRemoteDescription(desc).then(() => {
//                     return pc2.createAnswer().then(gotDescription2, onCreateSessionDescriptionError);
//                 }, onSetSessionDescriptionError);
//             }, onSetSessionDescriptionError);
// }

// function gotDescription2(desc) {
//     console.log(`Answer from pc2\n${desc.sdp}`);
//     pc2.setLocalDescription(desc).then(() => {
//         pc1.setRemoteDescription(desc).then(() => {}, onSetSessionDescriptionError);
//     }, onSetSessionDescriptionError);
// }
