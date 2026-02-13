import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:storehsk/component/itemForm.dart';
import 'package:storehsk/models/stocks.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

// Class to hold detection results with centroid info
class Detection {
  final Offset centroid;
  final double confidence;
  final String label;

  Detection({
    required this.centroid,
    required this.confidence,
    required this.label,
  });
}

class CameraScanner extends StatefulWidget {
  final Function(Stocks)? onItemDetected;

  const CameraScanner({super.key, this.onItemDetected});

  @override
  State<CameraScanner> createState() => _CameraScannerState();
}

class _CameraScannerState extends State<CameraScanner> {
  CameraController? _cameraController;
  bool _isProcessing = false;
  Interpreter? _interpreter;
  List<Detection> _detections = [];
  bool _isModelLoaded = false;
  String _statusMessage = 'Initializing...';
  DateTime _lastProcessedTime = DateTime.now();
  static const int processingIntervalMs = 300; // Process every 300ms

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModel();
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() {
          _statusMessage = 'No cameras available';
        });
        return;
      }

      _cameraController = CameraController(
        cameras[0],
        ResolutionPreset.low, // Use low resolution for better performance
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() {
        _statusMessage = 'Camera ready';
      });

      // Start streaming
      _startImageStream();
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      setState(() {
        _statusMessage = 'Camera error: $e';
      });
    }
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset(
        'luqman_dev-project-1-cpp-android-v2/tflite-model/tflite_learn_874838_10.tflite',
      );
      setState(() {
        _isModelLoaded = true;
        _statusMessage = 'Model loaded';
      });
      debugPrint('Model loaded successfully');
    } catch (e) {
      debugPrint('Error loading model: $e');
      setState(() {
        _statusMessage = 'Error loading model: $e';
      });
    }
  }

  void _startImageStream() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _cameraController!.startImageStream((CameraImage cameraImage) {
      // Throttle processing - only process every N milliseconds
      final now = DateTime.now();
      final timeSinceLastProcess = now
          .difference(_lastProcessedTime)
          .inMilliseconds;

      if (!_isProcessing &&
          _isModelLoaded &&
          timeSinceLastProcess >= processingIntervalMs) {
        _isProcessing = true;
        _lastProcessedTime = now;
        _processCameraImage(cameraImage).then((_) {
          _isProcessing = false;
        });
      }
    });
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    try {
      // Convert CameraImage to img.Image
      final img.Image? image = _convertCameraImage(cameraImage);
      if (image == null) return;

      // Run inference
      final detections = await _runInference(image);

      if (mounted) {
        setState(() {
          _detections = detections;
          if (detections.isNotEmpty) {
            _statusMessage = '${detections.length} object(s) detected';
          } else {
            _statusMessage = 'No objects detected';
          }
        });
      }
    } catch (e) {
      debugPrint('Processing error: $e');
    }
  }

  img.Image? _convertCameraImage(CameraImage cameraImage) {
    try {
      // Optimized YUV420 to RGB conversion
      final int width = cameraImage.width;
      final int height = cameraImage.height;
      final int uvRowStride = cameraImage.planes[1].bytesPerRow;
      final int uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;

      final img.Image image = img.Image(width: width, height: height);
      final yPlane = cameraImage.planes[0].bytes;
      final uPlane = cameraImage.planes[1].bytes;
      final vPlane = cameraImage.planes[2].bytes;

      // Optimized loop with pre-calculated values
      for (int h = 0; h < height; h++) {
        final int uvRow = (h ~/ 2) * uvRowStride;
        for (int w = 0; w < width; w++) {
          final int uvIndex = (w ~/ 2) * uvPixelStride + uvRow;
          final int yIndex = h * width + w;

          final int y = yPlane[yIndex];
          final int u = uPlane[uvIndex];
          final int v = vPlane[uvIndex];

          // Fast YUV to RGB conversion
          final int r = (y + 1.402 * (v - 128)).toInt().clamp(0, 255);
          final int g = (y - 0.344136 * (u - 128) - 0.714136 * (v - 128))
              .toInt()
              .clamp(0, 255);
          final int b = (y + 1.772 * (u - 128)).toInt().clamp(0, 255);

          image.setPixelRgb(w, h, r, g, b);
        }
      }

      return image;
    } catch (e) {
      debugPrint('Image conversion error: $e');
      return null;
    }
  }

  Future<List<Detection>> _runInference(img.Image image) async {
    try {
      if (_interpreter == null) {
        return [];
      }

      // Save original dimensions for bounding box calculation
      final originalWidth = image.width;
      final originalHeight = image.height;

      // Resize image to model input size (96x96 for FOMO model)
      final resizedImage = img.copyResize(image, width: 96, height: 96);

      // Convert to INT8 input tensor format
      var input = _imageToByteListInt8(resizedImage);

      // Prepare output tensor [1, 12, 12, 2] for FOMO object detection
      var output = List.generate(
        1,
        (_) => List.generate(
          12,
          (_) => List.generate(12, (_) => List.filled(2, 0)),
        ),
      );

      // Run inference
      _interpreter!.run(input, output);

      // Process FOMO output and create centroids
      List<Detection> detections = [];
      const threshold = 0.5; // 50% confidence threshold
      const gridSize = 12;

      // Each grid cell represents a region in the original image
      final cellWidth = originalWidth / gridSize;
      final cellHeight = originalHeight / gridSize;

      for (int y = 0; y < gridSize; y++) {
        for (int x = 0; x < gridSize; x++) {
          // Convert INT8 output to probability (dequantize)
          // FOMO output: index 0 = background, index 1 = object class
          int rawValue = output[0][y][x][1];
          double confidence = (rawValue + 128) / 255.0; // INT8 to [0,1]

          if (confidence > threshold) {
            // Calculate centroid (center of the grid cell)
            final centerX = (x + 0.5) * cellWidth;
            final centerY = (y + 0.5) * cellHeight;

            detections.add(
              Detection(
                centroid: Offset(centerX, centerY),
                confidence: confidence,
                label: 'saklar rumah',
              ),
            );
          }
        }
      }

      return detections;
    } catch (e, stackTrace) {
      debugPrint('Inference error: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    }
  }

  List<List<List<List<int>>>> _imageToByteListInt8(img.Image image) {
    // Convert image to INT8 format for FOMO model
    // Input shape: [1, 96, 96, 3] with INT8 values [-128, 127]
    return List.generate(
      1,
      (_) => List.generate(
        image.height,
        (y) => List.generate(image.width, (x) {
          var pixel = image.getPixel(x, y);
          // Convert from [0, 255] to [-128, 127]
          return [
            (pixel.r.toInt() - 128),
            (pixel.g.toInt() - 128),
            (pixel.b.toInt() - 128),
          ];
        }),
      ),
    );
  }

  void _showDetectionDialog(Detection detection) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Item Detected'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Detected: ${detection.label}'),
            Text(
              'Confidence: ${(detection.confidence * 100).toStringAsFixed(1)}%',
            ),
            const SizedBox(height: 16),
            const Text('What would you like to do?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Continue Scanning'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context); // Close camera screen
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              _openFormWithDetectedItem(detection.label);
            },
            child: const Text('Add to Inventory'),
          ),
        ],
      ),
    );
  }

  void _openFormWithDetectedItem(String detectedItem) {
    // Pause camera stream while showing form
    _cameraController?.stopImageStream();

    showItemFormSheet(
      context,
      itemName: detectedItem,
      onItemSaved: (newItem) {
        widget.onItemDetected?.call(newItem);
        // Restart camera stream
        if (_cameraController != null &&
            _cameraController!.value.isInitialized) {
          _startImageStream();
        }
      },
    );
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Real-time Scanner'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _cameraController == null || !_cameraController!.value.isInitialized
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 16),
                  Text(_statusMessage),
                ],
              ),
            )
          : Stack(
              fit: StackFit.expand,
              children: [
                // Camera Preview
                CameraPreview(_cameraController!),

                // Centroids overlay
                if (_detections.isNotEmpty)
                  CustomPaint(
                    painter: CentroidPainter(
                      detections: _detections,
                      imageSize: Size(
                        _cameraController!.value.previewSize!.height,
                        _cameraController!.value.previewSize!.width,
                      ),
                    ),
                  ),

                // Status overlay
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.7),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _statusMessage,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_detections.isNotEmpty)
                          Text(
                            'Tap on a detection to add to inventory',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                // Detection info overlay (bottom)
                if (_detections.isNotEmpty)
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: _detections.map((detection) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    '${detection.label}: ${(detection.confidence * 100).toStringAsFixed(1)}%',
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ),

                // Add to inventory button
                if (_detections.isNotEmpty)
                  Positioned(
                    bottom: 100,
                    left: 20,
                    right: 20,
                    child: FilledButton.icon(
                      onPressed: () {
                        if (_detections.isNotEmpty) {
                          _showDetectionDialog(_detections.first);
                        }
                      },
                      icon: const Icon(Icons.add_shopping_cart),
                      label: const Text('Add to Inventory'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.all(16),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}

// Custom painter to draw centroids with probabilities
class CentroidPainter extends CustomPainter {
  final List<Detection> detections;
  final Size imageSize;

  CentroidPainter({required this.detections, required this.imageSize});

  @override
  void paint(Canvas canvas, Size size) {
    // Calculate scale factor for image to screen
    final double scaleX = size.width / imageSize.width;
    final double scaleY = size.height / imageSize.height;
    final double scale = scaleX < scaleY ? scaleX : scaleY;

    // Calculate offset to center the image
    final double offsetX = (size.width - imageSize.width * scale) / 2;
    final double offsetY = (size.height - imageSize.height * scale) / 2;

    for (var detection in detections) {
      // Scale and position centroid
      final double centroidX = detection.centroid.dx * scale + offsetX;
      final double centroidY = detection.centroid.dy * scale + offsetY;
      final Offset scaledCentroid = Offset(centroidX, centroidY);

      // Draw outer circle (glow effect)
      final Paint glowPaint = Paint()
        ..color = Colors.green.withOpacity(0.3)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(scaledCentroid, 20, glowPaint);

      // Draw middle circle
      final Paint circlePaint = Paint()
        ..color = Colors.green
        ..style = PaintingStyle.fill;
      canvas.drawCircle(scaledCentroid, 8, circlePaint);

      // Draw center dot
      final Paint centerPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.fill;
      canvas.drawCircle(scaledCentroid, 3, centerPaint);

      // Draw probability label
      final String labelText =
          '${(detection.confidence * 100).toStringAsFixed(0)}%';

      final TextSpan span = TextSpan(
        text: labelText,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
      );

      final TextPainter textPainter = TextPainter(
        text: span,
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();

      // Draw label below the centroid
      final double labelX = centroidX - textPainter.width / 2;
      final double labelY = centroidY + 25;

      // Draw background for label
      final Rect labelBg = Rect.fromLTWH(
        labelX - 4,
        labelY - 2,
        textPainter.width + 8,
        textPainter.height + 4,
      );

      canvas.drawRRect(
        RRect.fromRectAndRadius(labelBg, const Radius.circular(4)),
        Paint()..color = Colors.green.withOpacity(0.9),
      );

      // Draw text
      textPainter.paint(canvas, Offset(labelX, labelY));
    }
  }

  @override
  bool shouldRepaint(covariant CentroidPainter oldDelegate) {
    return oldDelegate.detections != detections;
  }
}
