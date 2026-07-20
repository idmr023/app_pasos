import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../config/theme.dart';
import '../models/exercise.dart';
import '../services/giphy_service.dart';

class ExerciseImage extends StatefulWidget {
  final Exercise exercise;
  final double? width;
  final double? height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData fallbackIcon;
  final Color fallbackColor;

  const ExerciseImage({
    super.key,
    required this.exercise,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.fallbackIcon = Icons.fitness_center,
    this.fallbackColor = AppTheme.secondary,
  });

  @override
  State<ExerciseImage> createState() => _ExerciseImageState();
}

class _ExerciseImageState extends State<ExerciseImage> {
  String? _giphyUrl;
  bool _isLoadingGiphy = false;

  @override
  void initState() {
    super.initState();
    _loadGiphyIfNeeded();
  }

  @override
  void didUpdateWidget(ExerciseImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.exercise.id != widget.exercise.id) {
      _giphyUrl = null;
      _loadGiphyIfNeeded();
    }
  }

  Future<void> _loadGiphyIfNeeded() async {
    if (widget.exercise.imageUrl.isNotEmpty) return;
    if (!GiphyService.hasApiKey) return;
    if (_giphyUrl != null) return;

    setState(() => _isLoadingGiphy = true);
    final url = await GiphyService.getCachedOrSearch(
      widget.exercise.id,
      widget.exercise.displayName,
    );
    if (mounted) {
      setState(() {
        _giphyUrl = url;
        _isLoadingGiphy = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ex = widget.exercise;
    final primaryUrl = ex.imageUrl;
    final secondaryUrl = _giphyUrl;

    Widget image;
    if (primaryUrl.isNotEmpty) {
      image = CachedNetworkImage(
        imageUrl: primaryUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholder: (_, __) => _buildLoading(),
        errorWidget: (_, __, ___) => _buildSecondary(secondaryUrl),
      );
    } else if (secondaryUrl != null && secondaryUrl.isNotEmpty) {
      image = CachedNetworkImage(
        imageUrl: secondaryUrl,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholder: (_, __) => _buildLoading(),
        errorWidget: (_, __, ___) => _buildPlaceholder(),
      );
    } else if (_isLoadingGiphy) {
      image = _buildLoading();
    } else {
      image = _buildPlaceholder();
    }

    if (widget.borderRadius != null) {
      return ClipRRect(
        borderRadius: widget.borderRadius!,
        child: image,
      );
    }
    return image;
  }

  Widget _buildSecondary(String? url) {
    if (url != null && url.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: url,
        width: widget.width,
        height: widget.height,
        fit: widget.fit,
        placeholder: (_, __) => _buildLoading(),
        errorWidget: (_, __, ___) => _buildPlaceholder(),
      );
    }
    return _buildPlaceholder();
  }

  Widget _buildLoading() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.fallbackColor.withValues(alpha: 0.1),
      child: Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: widget.fallbackColor.withValues(alpha: 0.5),
          ),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: widget.width,
      height: widget.height,
      color: widget.fallbackColor.withValues(alpha: 0.1),
      child: Center(
        child: Icon(widget.fallbackIcon, size: 48, color: widget.fallbackColor.withValues(alpha: 0.5)),
      ),
    );
  }
}
