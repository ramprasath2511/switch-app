import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

class PreviewVideo extends StatefulWidget {
  final String videourl;
  final String id;
  final double aspectratio;

  PreviewVideo({@required this.id, @required this.videourl, this.aspectratio});
  @override
  _PreviewVideoState createState() => _PreviewVideoState();
}

class _PreviewVideoState extends State<PreviewVideo> {
  VideoPlayerController _videoPlayerController1;
  VideoPlayerController _videoPlayerController2;
  ChewieController _chewieController;
  String videoUrl = '';
  bool isShowvideo = false;
  double thisaspectratio = 1.14;

  @override
  void initState() {
    setState(() {
      thisaspectratio = widget.aspectratio;
    });
    super.initState();

    _videoPlayerController1 = VideoPlayerController.network(
        // 'https://flutter.github.io/assets-for-api-docs/assets/videos/butterfly.mp4'
        widget.videourl);
    _videoPlayerController2 = VideoPlayerController.network(widget.videourl
        // 'https://www.radiantmediaplayer.com/media/bbb-360p.mp4'
        );
    _chewieController = ChewieController(
      videoPlayerController: _videoPlayerController1,
      allowFullScreen: true,
      showControlsOnInitialize: false,
      aspectRatio: thisaspectratio,
      autoPlay: true,
      looping: true,
    );
  }

  @override
  void dispose() {
    _videoPlayerController1.dispose();
    _videoPlayerController2.dispose();
    _chewieController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0.2,
        elevation: 0.4,
        iconTheme: IconThemeData(color: Colors.white),
        backgroundColor: Colors.black,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: <Widget>[
            Text(
              'Video Player',
              style: TextStyle(
                  fontSize: 18,
                  color: Colors.white,
                  fontWeight: FontWeight.bold),
            ),
            // Text(
            //   this.thisaspectratio > 1
            //       ? 'LANDSCAPE aspect ratio 16:9'
            //       : 'POTRAIT aspect ratio 2:3',
            //   style: TextStyle(
            //       height: 1.5,
            //       fontSize: 13,
            //       fontWeight: FontWeight.w300,
            //       color: Colors.white70),
            // ),
          ],
        ),
      ),
      backgroundColor: Colors.black,
      body: Center(
          child: Chewie(
        controller: _chewieController,
      )),
    );
  }
}
