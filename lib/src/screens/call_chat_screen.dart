import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../helpers/env.dart';
import 'calling_screen.dart';

class CallChatScreen extends StatefulWidget {
  const CallChatScreen({super.key});
  static const routeName = '/callChat';

  @override
  State<CallChatScreen> createState() => _CallChatScreenState();
}

class _CallChatScreenState extends State<CallChatScreen> {
  final String roomId = "room123";
  final FirebaseFirestore firestore = FirebaseFirestore.instance;

  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  late RTCPeerConnection _peerConnection;
  late MediaStream _localStream;
  late RTCVideoRenderer _localRenderer = RTCVideoRenderer();
  late RTCVideoRenderer _remoteRenderer = RTCVideoRenderer();
  late String _myUserId;

  bool _isCaller = false;
  bool _isAudioOnly = false;

  @override
  void initState() {
    super.initState();

    // Listen to call state changes
    _setupCallListener();

    _setupUserId();

  }

  @override
  void dispose() {
    // _localRenderer.dispose();
    // _remoteRenderer.dispose();
    // _peerConnection.close();
    super.dispose();
  }

  // Init local and remote renderer for video calling
  Future<void> _initRenderers() async {
    if(!_isAudioOnly){
      _localRenderer = RTCVideoRenderer();
      _remoteRenderer = RTCVideoRenderer();
      await _localRenderer.initialize();
      await _remoteRenderer.initialize();
    }
  }

  Future<void> _setupCallListener() async {
    try {
      firestore.collection('calls').doc(roomId).snapshots().listen((snapshot) {
        final data = snapshot.data();
        final callState = data?['callState'];
        final isAudio = data?['callType'] == 'audio';

        if (snapshot.exists && callState == 'calling' && data?['offer'] != null && !_isCaller) {
          if(mounted){
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                title: Text(isAudio ? "🔊 Incoming Audio Call" : "📹 Incoming Video Call"),
                content: Text(
                  isAudio
                      ? "You have an incoming audio call"
                      : "You have an incoming video call",
                ),
                actions: [
                  TextButton(
                    onPressed: () async {
                      _isAudioOnly = isAudio;
                      Navigator.pop(context);
                      await _answerCall();
                    },
                    child: const Text("Accept"),
                  ),
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context);
                      await _rejectCall();
                    },
                    child: const Text("Reject"),
                  ),
                ],
              ),
            );
          }
        }
      });
    } catch (e) {
      logger.i('Call listener error > $e');
    }
  }

  Future<void> _startCall() async {
    try {
      _isCaller = true;

      await _initRenderers();  // 🔁 Reinitialize renderers
      await _createPeerConnection();

      //Caller set offer
      final offer = await _peerConnection.createOffer();
      await _peerConnection.setLocalDescription(offer);
      await firestore.collection('calls').doc(roomId).set({
        'offer': {
          'type': offer.type,
          'sdp': offer.sdp,
        },
        'callType': _isAudioOnly ? 'audio' : 'video',
        'callState': 'calling',
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Waiting dialog for answer
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (_) => AlertDialog(
            title: const Text("Calling..."),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SpinKitWave(color: Colors.grey[400],type: SpinKitWaveType.start,size: 30.0,itemCount: 5,),
                const SizedBox(height: 16),
                const Text("Waiting for answer..."),
              ],
            ),
          ),
        );
      }

      // Wait for answer
      firestore.collection('calls').doc(roomId).snapshots().listen((snapshot) async {
        final answer = snapshot.data()?['answer'];
        if (answer != null) {
          await _peerConnection.setRemoteDescription(
            RTCSessionDescription(answer['sdp'], answer['type']),
          );

          if(mounted){
            Navigator.pop(context); // ✅ Close "Calling..." dialog

            showGeneralDialog(
              context: context,
              barrierDismissible: false,
              barrierColor: Colors.black.withOpacity(0.6),
              transitionDuration: const Duration(milliseconds: 300),
              pageBuilder: (_, __, ___) => CallingScreen(
                localRenderer: _localRenderer,
                remoteRenderer: _remoteRenderer,
                onEndCall: _endCall,
                isAudioOnly: _isAudioOnly,
              ),
            );
          }
        }
      });

      // Listen for callee ICE
      firestore.collection('calls').doc(roomId).collection('calleeCandidates').snapshots().listen((snapshot) {
        for (var doc in snapshot.docChanges) {
          if (doc.type == DocumentChangeType.added) {
            final data = doc.doc.data();
            _peerConnection.addCandidate(RTCIceCandidate(
              data?['candidate'],
              data?['sdpMid'],
              data?['sdpMLineIndex'],
            ));
          }
        }
      });
    } catch (e) {
      logger.w('Start Call error >> $e');
    }
  }

  Future<void> _answerCall() async {
    try {
      await _initRenderers();  // 🔁 Reinitialize renderers
      await _createPeerConnection();

      final callDoc = await firestore.collection('calls').doc(roomId).get();
      final offer = callDoc.data()?['offer'];
      if (offer == null) return;

      await _peerConnection.setRemoteDescription(
        RTCSessionDescription(offer['sdp'], offer['type']),
      );

      final answer = await _peerConnection.createAnswer();
      await _peerConnection.setLocalDescription(answer);

      await firestore.collection('calls').doc(roomId).update({
        'answer': {
          'type': answer.type,
          'sdp': answer.sdp,
        },
        'callState': 'answered',
      });

      // Listen for caller ICE
      firestore.collection('calls').doc(roomId).collection('callerCandidates').snapshots().listen((snapshot) {
        for (var doc in snapshot.docChanges) {
          if (doc.type == DocumentChangeType.added) {
            final data = doc.doc.data();
            _peerConnection.addCandidate(
              RTCIceCandidate(data?['candidate'], data?['sdpMid'], data?['sdpMLineIndex']),
            );
          }
        }
      });

      if(mounted){
        showDialog(
          context: context,
          barrierDismissible: false, // prevent dismissing by tap outside
          builder: (_) => Dialog(
            insetPadding: EdgeInsets.zero, // make full screen
            backgroundColor: Colors.black,
            child: CallingScreen(
              localRenderer: _localRenderer,
              remoteRenderer: _remoteRenderer,
              onEndCall: _endCall,
              isAudioOnly: _isAudioOnly,
            ),
          ),
        );
      }
    } catch (e) {
      logger.w('Answer Call error >> $e');
    }
  }

  Future<void> _rejectCall() async {
    try {
      await firestore.collection('calls').doc(roomId).update({
        'callState': 'rejected',
        'offer': FieldValue.delete(),
      });
    } catch (e) {
      logger.w("Reject Call error >> $e");
    }
  }

  Future<void> _endCall() async {
    try {

      if(!_isAudioOnly){
        // 1. Stop local tracks
        _localRenderer.srcObject?.getTracks().forEach((track) => track.stop());
        _remoteRenderer.srcObject?.getTracks().forEach((track) => track.stop());
        //_localStream.getTracks().forEach((track) => track.stop());

        // 4. Dispose renderers
        await _localRenderer.dispose();
        await _remoteRenderer.dispose();
      }

      // 2. Close peer connection
      await _peerConnection.close();

      // 3. Remove room document (optional)
      await firestore.collection('calls').doc(roomId).delete();

      if(mounted) Navigator.pop(context); // ✅ Close Calling Screen
      _isCaller = false;
      // 5. Navigate back or show dialog
      // if (mounted) {
      //   Navigator.pop(context);
      // }
    } catch (e) {
      logger.w('❌ Error ending call: $e');
    }
  }

  // Create renderer connection
  Future<void> _createPeerConnection() async {
    try {
      // 1. Permissions
      await requestCameraAndMicPermissions();

      // 2. ICE config
      final config = {
        'iceServers': [
          {'urls': 'stun:stun.l.google.com:19302'},
        ],
      };

      // 3. Create connection
      _peerConnection = await createPeerConnection(config);
      logger.i("🎬 PeerConnection created");

      // 4. Get user media (compatible with Android 9+)
      _localStream = await navigator.mediaDevices.getUserMedia({
        'audio': true,
        'video': _isAudioOnly ? false : true,
        // 'video': {
        //   'facingMode': 'user',
        //   'width': {'ideal': 640},
        //   'height': {'ideal': 480},
        //   'frameRate': {'ideal': 14, 'max': 15},
        // },
      });

      logger.i("📷 Got local stream: ${_localStream.id}");

      // 5. Assign local stream to renderer and rebuild UI
      if (!_isAudioOnly) {
        _localRenderer.srcObject = _localStream;
        setState(() {}); // 🔄 Ensure UI updates
      }

      // 6. Add tracks to connection
      for (final track in _localStream.getTracks()) {
        await _peerConnection.addTrack(track, _localStream);
      }

      // 7. Handle incoming remote video streams tracks
      _peerConnection.onTrack = (event) {
        logger.i("🎥 onTrack: ${event.track.kind}, streams: ${event.streams.length}");
        if (!_isAudioOnly && event.streams.isNotEmpty) {
          _remoteRenderer.srcObject = event.streams[0];
          setState(() {}); // 🔄 Update remote video view
          logger.i("🎥 Remote stream set");
        }
      };

      // 8. Handle ICE candidates
      _peerConnection.onIceCandidate = (candidate) {
        final candidateMap = {
          'candidate': candidate.candidate,
          'sdpMid': candidate.sdpMid,
          'sdpMLineIndex': candidate.sdpMLineIndex,
        };

        firestore
            .collection('calls')
            .doc(roomId)
            .collection(_isCaller ? 'callerCandidates' : 'calleeCandidates')
            .add(candidateMap);

        logger.i("📡 Sending ICE as: ${_isCaller ? 'Caller' : 'Callee'}");
      };
    } catch (e, stackTrace) {
      logger.w("❌ createPeerConnection() error: $e", error: e, stackTrace: stackTrace);
    }
  }

  Future<void> requestCameraAndMicPermissions() async {
    try {
      final status = await [
        Permission.camera,
        Permission.microphone,
      ].request();

      if (!status[Permission.camera]!.isGranted || !status[Permission.microphone]!.isGranted) {
        logger.i("❌ Camera and Mic Permissions not granted!");
        return;
      }
    } catch (e) {
      logger.i('Call Permission error > $e');
    }
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    await FirebaseFirestore.instance
        .collection('chats')
        .doc(roomId)
        .collection('messages')
        .add({
      'text': text,
      'senderId': _myUserId,
      'timestamp': FieldValue.serverTimestamp(),
    });

    _messageController.clear();

    await Future.delayed(const Duration(milliseconds: 100));
    _scrollController.animateTo(
      _scrollController.position.maxScrollExtent,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOut,
    );
  }

  Future<String> getOrCreateUserId() async {
    final prefs = await SharedPreferences.getInstance();
    String? userId = prefs.getString('userId');

    if (userId == null) {
      userId = const Uuid().v4(); // generate random UUID
      await prefs.setString('userId', userId);
    }

    return userId;
  }

  Future<void> _setupUserId() async {
    _myUserId = await getOrCreateUserId();
  }

  @override
  Widget build(BuildContext context) {
    final messageStream = FirebaseFirestore.instance
        .collection('chats')
        .doc(roomId)
        .collection('messages')
        .orderBy('timestamp')
        .snapshots();

    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus(); // Hide keyboard
      },
      child: Scaffold(
        appBar: AppBar(
          elevation: 2,
          title: const Text('Call And Chat'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.call),
              onPressed: () {
                // Audio Call
                _isAudioOnly = true;
                _startCall();
              },
            ),
            IconButton(
              icon: const Icon(Icons.video_call_outlined),
              onPressed: () {
                // Video Call
                _isAudioOnly = false;
                _startCall();
              },
            ),
          ],
        ),
        body: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            const SizedBox(height: 20,),

            // 🔄 Message list
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: messageStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    controller: _scrollController,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final data = docs[index].data() as Map<String, dynamic>;
                      return _buildMessageItem(data);
                    },
                  );
                },
              ),
            ),

            // 📨 Message Input
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              color: Colors.transparent,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey[700],
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: const [
                          BoxShadow(
                            color: Colors.black12,
                            blurRadius: 2,
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: const InputDecoration(
                          hintText: "Type a message...",
                          border: InputBorder.none,
                        ),
                        minLines: 1,
                        maxLines: 5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _sendMessage(_messageController.text),
                    child: const CircleAvatar(
                      radius: 22,
                      backgroundColor: Colors.blueAccent,
                      child: Icon(Icons.send, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
            // Padding(
            //   padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
            //   child: Row(
            //     children: [
            //       Expanded(
            //         child: TextField(
            //           controller: _messageController,
            //           decoration: const InputDecoration(
            //             hintText: "Type a message...",
            //             border: InputBorder.none,
            //           ),
            //         ),
            //       ),
            //       IconButton(
            //         icon: const Icon(Icons.send),
            //         onPressed: () => _sendMessage(_messageController.text),
            //       ),
            //     ],
            //   ),
            // ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageItem(Map<String, dynamic> data) {
    final String senderId = data['senderId'];
    final bool isSender = senderId == _myUserId;

    return Align(
      alignment: isSender ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: isSender ? Colors.blueAccent : Colors.grey[700],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          data['text'] ?? '',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }

}
