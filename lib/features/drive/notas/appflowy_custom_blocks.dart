import 'dart:io';

import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

class CustomBlockData {
  const CustomBlockData({
    required this.type,
    this.language,
    this.content,
    this.url,
    this.title,
    this.thumbnailUrl,
  });

  final String type;
  final String? language;
  final String? content;
  final String? url;
  final String? title;
  final String? thumbnailUrl;

  Map<String, Object> toAttributes() {
    final attributes = <String, Object>{};
    if (language != null) attributes['language'] = language!;
    if (content != null) attributes['content'] = content!;
    if (url != null) attributes['url'] = url!;
    if (title != null) attributes['title'] = title!;
    if (thumbnailUrl != null) attributes['thumbnail_url'] = thumbnailUrl!;
    return attributes;
  }
}

Document buildCustomBlockDocument({List<CustomBlockData> blocks = const []}) {
  final children = blocks
      .map((block) => Node(type: block.type, attributes: block.toAttributes()))
      .toList();
  final root = pageNode(children: children);

  return Document(root: root);
}

final Map<String, BlockComponentBuilder> _customBlockBuilders = {
  'code_block': CodeBlockBlockComponentBuilder(),
  'video_block': VideoBlockBlockComponentBuilder(),
  'link_preview': LinkPreviewBlockComponentBuilder(),
};

Map<String, BlockComponentBuilder> get customBlockBuilders =>
    _customBlockBuilders;

class CodeBlockBlockComponentBuilder extends BlockComponentBuilder {
  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return CodeBlockBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) =>
          actionTrailingBuilder(blockComponentContext, state),
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.type == 'code_block';
}

class VideoBlockBlockComponentBuilder extends BlockComponentBuilder {
  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return VideoBlockBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) =>
          actionTrailingBuilder(blockComponentContext, state),
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.type == 'video_block';
}

class LinkPreviewBlockComponentBuilder extends BlockComponentBuilder {
  @override
  BlockComponentWidget build(BlockComponentContext blockComponentContext) {
    final node = blockComponentContext.node;
    return LinkPreviewBlockComponentWidget(
      key: node.key,
      node: node,
      configuration: configuration,
      showActions: showActions(node),
      actionBuilder: (context, state) =>
          actionBuilder(blockComponentContext, state),
      actionTrailingBuilder: (context, state) =>
          actionTrailingBuilder(blockComponentContext, state),
    );
  }

  @override
  BlockComponentValidate get validate =>
      (node) => node.type == 'link_preview';
}

class CodeBlockBlockComponentWidget extends BlockComponentStatefulWidget {
  const CodeBlockBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<CodeBlockBlockComponentWidget> createState() =>
      _CodeBlockBlockComponentWidgetState();
}

class _CodeBlockBlockComponentWidgetState
    extends State<CodeBlockBlockComponentWidget>
    with SelectableMixin, BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) {
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox) return Rect.zero;
    return Offset.zero & renderBox.size;
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) =>
      Selection.single(path: widget.node.path, startOffset: 0, endOffset: 1);

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox) return const [];
    return [Offset.zero & renderBox.size];
  }

  @override
  Position getPositionInOffset(Offset start) =>
      Position(path: widget.node.path, offset: 0);

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) {
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox) return offset;
    return renderBox.localToGlobal(offset);
  }

  @override
  Position start() => Position(path: widget.node.path, offset: 0);

  @override
  Position end() => Position(path: widget.node.path, offset: 1);

  @override
  Widget build(BuildContext context) {
    final content = widget.node.attributes['content'] as String? ?? '';
    final language = widget.node.attributes['language'] as String? ?? 'text';

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              language,
              style: const TextStyle(
                fontSize: 11,
                letterSpacing: 0.4,
                color: Colors.white70,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            SelectableText(
              content,
              style: const TextStyle(
                fontFamily: 'monospace',
                fontSize: 13,
                color: Colors.white,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class VideoBlockBlockComponentWidget extends BlockComponentStatefulWidget {
  const VideoBlockBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<VideoBlockBlockComponentWidget> createState() =>
      _VideoBlockBlockComponentWidgetState();
}

class _VideoBlockBlockComponentWidgetState
    extends State<VideoBlockBlockComponentWidget>
    with SelectableMixin, BlockComponentConfigurable {
  VideoPlayerController? _videoController;
  bool _loading = true;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateWidget(covariant VideoBlockBlockComponentWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldUrl = oldWidget.node.attributes['url'] as String? ?? '';
    final newUrl = widget.node.attributes['url'] as String? ?? '';
    if (oldUrl != newUrl) {
      _videoController?.dispose();
      _videoController = null;
      _loading = false;
      _failed = false;
    }
  }

  Future<void> _startVideo() async {
    if (_loading) return;
    final controller = _videoController;
    if (controller != null) {
      await controller.play();
      return;
    }

    setState(() => _loading = true);
    await _initializeVideo();
    if (mounted && _videoController != null && !_failed) {
      await _videoController!.play();
    }
  }

  Future<void> _initializeVideo() async {
    final url = widget.node.attributes['url'] as String? ?? '';
    final uri = Uri.tryParse(url);
    if (url.isEmpty || uri == null) {
      _loading = false;
      _failed = true;
      return;
    }

    final controller = uri.scheme == 'http' || uri.scheme == 'https'
        ? VideoPlayerController.networkUrl(uri)
        : VideoPlayerController.file(
            uri.scheme == 'file' ? File.fromUri(uri) : File(url),
          );
    _videoController = controller;
    try {
      await controller.initialize();
      if (mounted) {
        setState(() => _loading = false);
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _failed = true;
        });
      }
    }
  }

  @override
  void dispose() {
    _videoController?.dispose();
    super.dispose();
  }

  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) {
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox) return Rect.zero;
    return Offset.zero & renderBox.size;
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) =>
      Selection.single(path: widget.node.path, startOffset: 0, endOffset: 1);

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox) return const [];
    return [Offset.zero & renderBox.size];
  }

  @override
  Position getPositionInOffset(Offset start) =>
      Position(path: widget.node.path, offset: 0);

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) {
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox) return offset;
    return renderBox.localToGlobal(offset);
  }

  @override
  Position start() => Position(path: widget.node.path, offset: 0);

  @override
  Position end() => Position(path: widget.node.path, offset: 1);

  @override
  Widget build(BuildContext context) {
    final url = widget.node.attributes['url'] as String? ?? '';
    final title = widget.node.attributes['title'] as String? ?? 'Video';
    final thumbnail = widget.node.attributes['thumbnail_url'] as String?;
    final controller = _videoController;

    return RepaintBoundary(
      child: Container(
        width: double.infinity,
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: AspectRatio(
                aspectRatio: controller?.value.aspectRatio ?? 16 / 9,
                child: _loading
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          if (thumbnail != null && thumbnail.isNotEmpty)
                            Image.network(
                              thumbnail,
                              fit: BoxFit.cover,
                              cacheWidth: 800,
                            ),
                          const Center(child: CircularProgressIndicator()),
                        ],
                      )
                    : _failed || controller == null
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          if (thumbnail != null && thumbnail.isNotEmpty)
                            Image.network(
                              thumbnail,
                              fit: BoxFit.cover,
                              cacheWidth: 800,
                            )
                          else
                            Container(color: Colors.black12),
                          Center(
                            child: IconButton.filledTonal(
                              tooltip: 'Reproducir video',
                              onPressed: _startVideo,
                              icon: Icon(
                                _failed
                                    ? Icons.refresh
                                    : Icons.play_arrow_rounded,
                                size: 36,
                              ),
                            ),
                          ),
                        ],
                      )
                    : ValueListenableBuilder<VideoPlayerValue>(
                        valueListenable: controller,
                        builder: (context, value, child) => Stack(
                          alignment: Alignment.center,
                          children: [
                            VideoPlayer(controller),
                            IconButton.filledTonal(
                              tooltip: value.isPlaying
                                  ? 'Pausar video'
                                  : 'Reproducir video',
                              onPressed: value.isPlaying
                                  ? controller.pause
                                  : _startVideo,
                              icon: Icon(
                                value.isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 4),
            Text(
              url,
              style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

class LinkPreviewBlockComponentWidget extends BlockComponentStatefulWidget {
  const LinkPreviewBlockComponentWidget({
    super.key,
    required super.node,
    super.showActions,
    super.actionBuilder,
    super.actionTrailingBuilder,
    super.configuration = const BlockComponentConfiguration(),
  });

  @override
  State<LinkPreviewBlockComponentWidget> createState() =>
      _LinkPreviewBlockComponentWidgetState();
}

class _LinkPreviewBlockComponentWidgetState
    extends State<LinkPreviewBlockComponentWidget>
    with SelectableMixin, BlockComponentConfigurable {
  @override
  BlockComponentConfiguration get configuration => widget.configuration;

  @override
  Node get node => widget.node;

  @override
  Rect getBlockRect({bool shiftWithBaseOffset = false}) {
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox) return Rect.zero;
    return Offset.zero & renderBox.size;
  }

  @override
  Selection getSelectionInRange(Offset start, Offset end) =>
      Selection.single(path: widget.node.path, startOffset: 0, endOffset: 1);

  @override
  List<Rect> getRectsInSelection(
    Selection selection, {
    bool shiftWithBaseOffset = false,
  }) {
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox) return const [];
    return [Offset.zero & renderBox.size];
  }

  @override
  Position getPositionInOffset(Offset start) =>
      Position(path: widget.node.path, offset: 0);

  @override
  Offset localToGlobal(Offset offset, {bool shiftWithBaseOffset = false}) {
    final renderBox = context.findRenderObject();
    if (renderBox is! RenderBox) return offset;
    return renderBox.localToGlobal(offset);
  }

  @override
  Position start() => Position(path: widget.node.path, offset: 0);

  @override
  Position end() => Position(path: widget.node.path, offset: 1);

  @override
  Widget build(BuildContext context) {
    final title = widget.node.attributes['title'] as String? ?? 'Enlace';
    final url = widget.node.attributes['url'] as String? ?? '';

    return RepaintBoundary(
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            final uri = Uri.tryParse(url);
            if (uri != null &&
                (uri.scheme == 'https' || uri.scheme == 'http')) {
              launchUrl(uri, mode: LaunchMode.externalApplication);
            }
          },
          child: Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(vertical: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade300),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.link, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  url,
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade700),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
