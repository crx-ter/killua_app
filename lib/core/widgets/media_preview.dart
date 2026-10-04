import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';

const mediaPreviewWidth = 300.0;
const mediaPreviewHeight = 200.0;

class MediaPreviewScreen extends StatefulWidget {
  final ImageProvider image;
  final double initialRotation;

  const MediaPreviewScreen({
    super.key,
    required this.image,
    this.initialRotation = 0,
  });

  @override
  State<MediaPreviewScreen> createState() => _MediaPreviewScreenState();
}

class _MediaPreviewScreenState extends State<MediaPreviewScreen> {
  late double _rotation;
  final PhotoViewController _photoController = PhotoViewController();

  @override
  void initState() {
    super.initState();
    _rotation = widget.initialRotation;
  }

  @override
  void dispose() {
    _photoController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Girar imagen',
            icon: const Icon(Icons.rotate_right_rounded),
            onPressed: () => setState(() => _rotation += math.pi / 2),
          ),
          IconButton(
            tooltip: 'Restablecer zoom',
            icon: const Icon(Icons.fit_screen_rounded),
            onPressed: () {
              setState(() => _rotation = widget.initialRotation);
              _photoController
                ..scale = null
                ..position = Offset.zero;
            },
          ),
        ],
      ),
      body: Center(
        child: Transform.rotate(
          angle: _rotation,
          child: PhotoView(
            imageProvider: widget.image,
            controller: _photoController,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
            minScale: PhotoViewComputedScale.contained * 0.8,
            maxScale: PhotoViewComputedScale.covered * 4,
            initialScale: PhotoViewComputedScale.contained,
            errorBuilder: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: Colors.white54,
              size: 48,
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showMediaPreview(
  BuildContext context, {
  required ImageProvider image,
  double rotation = 0,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) =>
          MediaPreviewScreen(image: image, initialRotation: rotation),
    ),
  );
}
