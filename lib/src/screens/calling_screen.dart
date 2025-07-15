import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';

class CallingScreen extends StatefulWidget {
  final RTCVideoRenderer localRenderer;
  final RTCVideoRenderer remoteRenderer;
  final Future<void> Function()? onEndCall;
  final bool isAudioOnly;

  const CallingScreen({super.key, required this.localRenderer, required this.remoteRenderer, required this.onEndCall, required this.isAudioOnly});

  @override
  State<CallingScreen> createState() => _CallingScreenState();
}

class _CallingScreenState extends State<CallingScreen> {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Calling'),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded),
          onPressed: widget.onEndCall,
        ),
      ),
      body: widget.isAudioOnly ? _buildAudioCallView(context) : _buildVideoCallView(context),
    );
  }

  Widget _buildVideoCallView(BuildContext context) {
    return Stack(
      children: [
        // Remote Video Fullscreen
        if (widget.remoteRenderer.srcObject != null)
          RTCVideoView(widget.remoteRenderer, objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover)
        else
          const Center(child: CupertinoActivityIndicator()),

        // Local Video Small Box
        Positioned(
          right: 20,
          top: 20,
          width: 120,
          height: 160,
          child: Container(
            decoration: BoxDecoration(border: Border.all(color: Colors.white)),
            child: RTCVideoView(widget.localRenderer, mirror: true),
          ),
        ),

        // End Call Button
        Positioned(
          bottom: 50,
          left: 0,
          right: 0,
          child: Center(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              icon: const Icon(Icons.call_end),
              label: const Text('End Call'),
              onPressed: widget.onEndCall,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioCallView(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          const CircleAvatar(
            radius: 60,
            backgroundColor: Colors.grey,
            child: Icon(
              Icons.person,
              size: 60,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'In Audio Call...',
            style: TextStyle(color: Colors.white, fontSize: 20),
          ),
          const SizedBox(height: 40),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              IconButton(
                onPressed: () {
                  // TODO: Mute mic logic
                },
                icon: const Icon(Icons.mic_off, color: Colors.white),
              ),
              ElevatedButton(
                onPressed: widget.onEndCall,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: const CircleBorder(), padding: const EdgeInsets.all(20)),
                child: const Icon(Icons.call_end),
              ),
              IconButton(
                onPressed: () {
                  // TODO: Toggle speaker logic
                },
                icon: const Icon(Icons.volume_up, color: Colors.white),
              ),
            ],
          )
        ],
      ),
    );
  }
}
