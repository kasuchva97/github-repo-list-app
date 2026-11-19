import 'package:material_ui/material_ui.dart';

/// Circular owner avatar loaded with [Image.network].
///
/// Shows a person icon while loading and if the image fails (offline, 404),
/// and requests a size-appropriate image from GitHub's avatar CDN.
class OwnerAvatar extends StatelessWidget {
  const OwnerAvatar({
    super.key,
    required this.url,
    this.size = 40,
    this.heroTag,
  });

  final String url;
  final double size;

  /// When set, the avatar animates between screens (list → detail).
  final Object? heroTag;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final placeholder = ColoredBox(
      color: colors.surfaceContainerHighest,
      child: Icon(
        Icons.person,
        size: size * 0.6,
        color: colors.onSurfaceVariant,
      ),
    );
    final pixelSize = (size * MediaQuery.devicePixelRatioOf(context))
        .round()
        .clamp(1, 460);

    final avatar = ExcludeSemantics(
      child: ClipOval(
        child: SizedBox.square(
          dimension: size,
          child: url.isEmpty
              ? placeholder
              : Image.network(
                  sizedAvatarUrl(url, pixelSize),
                  fit: BoxFit.cover,
                  // Decode at display size to keep memory low in long lists.
                  cacheWidth: pixelSize,
                  gaplessPlayback: true,
                  loadingBuilder: (context, child, progress) =>
                      progress == null ? child : placeholder,
                  errorBuilder: (context, error, stackTrace) => placeholder,
                ),
        ),
      ),
    );
    final tag = heroTag;
    return tag == null ? avatar : Hero(tag: tag, child: avatar);
  }
}

/// Adds GitHub's `s` (size) query parameter to an avatar URL so the CDN
/// returns a small image instead of the full-size original.
@visibleForTesting
String sizedAvatarUrl(String url, int pixelSize) {
  final uri = Uri.tryParse(url);
  if (uri == null || !uri.host.endsWith('githubusercontent.com')) return url;
  return uri
      .replace(queryParameters: {...uri.queryParameters, 's': '$pixelSize'})
      .toString();
}
