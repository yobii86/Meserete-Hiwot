import 'dart:io' as io;

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../network/file_upload_helper.dart';

/// Result details of receipt image compression.
class CompressionResult {
  const CompressionResult({
    required this.path,
    required this.name,
    required this.originalSizeBytes,
    required this.compressedSizeBytes,
    required this.wasCompressed,
    this.originalWidth,
    this.originalHeight,
    this.compressedWidth,
    this.compressedHeight,
  });

  final String path;
  final String name;
  final int originalSizeBytes;
  final int compressedSizeBytes;
  final bool wasCompressed;
  final int? originalWidth;
  final int? originalHeight;
  final int? compressedWidth;
  final int? compressedHeight;

  double get ratio => originalSizeBytes > 0 ? compressedSizeBytes / originalSizeBytes : 1.0;

  String formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
  }

  String get originalSizeFormatted => formatSize(originalSizeBytes);
  String get compressedSizeFormatted => formatSize(compressedSizeBytes);

  String get summaryText {
    if (!wasCompressed) return originalSizeFormatted;
    final pct = ((1.0 - ratio) * 100).round();
    return '$originalSizeFormatted → $compressedSizeFormatted (-$pct%)';
  }
}

/// Reliable receipt image compressor.
/// Resizes excessively large receipt photos (e.g., 2MB - 20MB) preserving crystal-clear readability
/// for transactions, dates, reference numbers, and stamps.
final class ImageCompressor {
  const ImageCompressor._();

  static const int maxDimension = 1920;
  static const int defaultQuality = 82;

  /// Determines if a file path is a PDF.
  static bool isPdf(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.pdf');
  }

  /// Determines if a file path is a compressable image.
  static bool isImage(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.jpg') ||
        lower.endsWith('.jpeg') ||
        lower.endsWith('.png') ||
        lower.endsWith('.webp') ||
        lower.endsWith('.bmp') ||
        lower.endsWith('.heic') ||
        lower.endsWith('.heif');
  }

  /// Compresses a receipt image or passes through a PDF safely.
  /// Minimum requirement: Handles images >= 2MB gracefully.
  static Future<CompressionResult> compressReceipt({
    required String path,
    required String name,
    int maxEdge = maxDimension,
    int quality = defaultQuality,
  }) async {
    // 1. Read input bytes
    Uint8List? rawBytes = getUploadBytes(path);
    if (rawBytes == null) {
      if (!kIsWeb) {
        final f = io.File(path);
        if (await f.exists()) {
          rawBytes = await f.readAsBytes();
        }
      }
    }

    if (rawBytes == null || rawBytes.isEmpty) {
      // Cannot read or empty: return original pointer safely
      return CompressionResult(
        path: path,
        name: name,
        originalSizeBytes: 0,
        compressedSizeBytes: 0,
        wasCompressed: false,
      );
    }

    final originalSize = rawBytes.length;

    // 2. If it's a PDF, do not attempt image compression
    if (isPdf(name) || isPdf(path)) {
      return CompressionResult(
        path: path,
        name: name,
        originalSizeBytes: originalSize,
        compressedSizeBytes: originalSize,
        wasCompressed: false,
      );
    }

    // 3. For small images (< 250KB), compression is usually unnecessary unless resized
    try {
      // Decode with full format support (JPEG, PNG, WebP, BMP, TIFF, GIF, etc.)
      final decoded = img.decodeImage(rawBytes);
      if (decoded == null) {
        // Fallback: return original if format cannot be decoded
        return CompressionResult(
          path: path,
          name: name,
          originalSizeBytes: originalSize,
          compressedSizeBytes: originalSize,
          wasCompressed: false,
        );
      }

      final origW = decoded.width;
      final origH = decoded.height;

      // Correct camera EXIF orientation
      final oriented = img.bakeOrientation(decoded);

      // Downscale if either dimension exceeds maxEdge, keeping aspect ratio
      img.Image processed = oriented;
      if (oriented.width > maxEdge || oriented.height > maxEdge) {
        final isLandscape = oriented.width >= oriented.height;
        final targetW = isLandscape ? maxEdge : (oriented.width * maxEdge / oriented.height).round();
        final targetH = isLandscape ? (oriented.height * maxEdge / oriented.width).round() : maxEdge;

        processed = img.copyResize(
          oriented,
          width: targetW,
          height: targetH,
          interpolation: img.Interpolation.linear,
        );
      }

      // Encode as clean high-quality JPEG
      final compressedBytes = Uint8List.fromList(img.encodeJpg(processed, quality: quality));

      // Check if compression achieved size reduction or resolution improvement
      if (compressedBytes.length < originalSize || processed.width != origW || processed.height != origH) {
        final outName = '${name.replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')}.jpg';

        if (kIsWeb) {
          final outPath = 'compressed_${DateTime.now().millisecondsSinceEpoch}_$outName';
          registerUploadBytes(outPath, compressedBytes);
          return CompressionResult(
            path: outPath,
            name: outName,
            originalSizeBytes: originalSize,
            compressedSizeBytes: compressedBytes.length,
            wasCompressed: true,
            originalWidth: origW,
            originalHeight: origH,
            compressedWidth: processed.width,
            compressedHeight: processed.height,
          );
        } else {
          // Native platform: save to temp directory
          final tempDir = await getTemporaryDirectory();
          final outPath = '${tempDir.path}/mz_receipt_${DateTime.now().millisecondsSinceEpoch}.jpg';
          final outFile = io.File(outPath);
          await outFile.writeAsBytes(compressedBytes, flush: true);
          registerUploadBytes(outPath, compressedBytes);

          return CompressionResult(
            path: outPath,
            name: outName,
            originalSizeBytes: originalSize,
            compressedSizeBytes: compressedBytes.length,
            wasCompressed: true,
            originalWidth: origW,
            originalHeight: origH,
            compressedWidth: processed.width,
            compressedHeight: processed.height,
          );
        }
      }

      // If compressed size is larger (rare), keep original bytes
      return CompressionResult(
        path: path,
        name: name,
        originalSizeBytes: originalSize,
        compressedSizeBytes: originalSize,
        wasCompressed: false,
        originalWidth: origW,
        originalHeight: origH,
        compressedWidth: origW,
        compressedHeight: origH,
      );
    } catch (e) {
      debugPrint('Receipt image compression failed, falling back to original: $e');
      return CompressionResult(
        path: path,
        name: name,
        originalSizeBytes: originalSize,
        compressedSizeBytes: originalSize,
        wasCompressed: false,
      );
    }
  }
}
