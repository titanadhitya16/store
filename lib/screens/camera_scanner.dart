import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:storehsk/widgets/item_form.dart';
import 'package:storehsk/models/stocks.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart' as img;
import 'package:flutter/services.dart' show rootBundle;

// Class to hold classification results
class Detection {
  final double confidence;
  final String label;

  Detection({
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
  OrtSession? _session;
  List<Detection> _detections = [];
  bool _isModelLoaded = false;
  String _statusMessage = 'Initializing spark plug scanner...';
  DateTime _lastProcessedTime = DateTime.now();
  int processingIntervalMs = 200; // Start with 200ms, will adapt
  bool _formOpened = false; // Track if form has been auto-opened
  int _slowFrameCount = 0;
  
  // Real-time classification scores for debugging
  double _currentClass0Score = 0.0;
  double _currentClass1Score = 0.0;
  String _currentPrediction = 'none';

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Load model FIRST before starting camera
    await _loadModel();
    
    // Only start camera if model loaded successfully
    if (_isModelLoaded) {
      await _initializeCamera();
    }
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
        ResolutionPreset.medium, // Medium for better quality, we'll downsample
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      // Only update status if model is loaded
      if (_isModelLoaded) {
        setState(() {
          _statusMessage = 'Camera ready. Warming up... (5s)';
        });

        // Wait 5 seconds for camera to stabilize before starting inference
        await Future.delayed(const Duration(seconds: 5));
        
        if (!mounted) return;
        
        setState(() {
          _statusMessage = 'Ready to scan spark plugs';
        });

        // Start streaming only if model is ready
        _startImageStream();
      }
    } catch (e) {
      debugPrint('Camera initialization error: $e');
      setState(() {
        _statusMessage = 'Camera error: $e';
      });
    }
  }

  Future<void> _loadModel() async {
    try {
      // Release existing session if any
      _session?.release();
      
      // Load model from assets (using IR version 9 compatible model)
      final modelData = await rootBundle.load('model/object_detection.onnx');
      final modelBytes = modelData.buffer.asUint8List();
      
      // Create ONNX Runtime session with optimizations
      final sessionOptions = OrtSessionOptions()
        ..setInterOpNumThreads(2)
        ..setIntraOpNumThreads(2)
        ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
      
      _session = OrtSession.fromBuffer(modelBytes, sessionOptions);
      
      if (mounted) {
        setState(() {
          _isModelLoaded = true;
          _statusMessage = 'Model loaded successfully';
        });
      }
      debugPrint('ONNX model loaded successfully with 2 threads');
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
        final processingStartTime = DateTime.now();
        _lastProcessedTime = now;
        _processCameraImage(cameraImage).then((_) {
          _isProcessing = false;
          
          // Adaptive throttling - adjust interval based on processing time
          final processingTime = DateTime.now().difference(processingStartTime).inMilliseconds;
          if (processingTime > processingIntervalMs) {
            _slowFrameCount++;
            if (_slowFrameCount > 3) {
              processingIntervalMs = min(500, processingIntervalMs + 50);
              debugPrint('Increasing interval to ${processingIntervalMs}ms due to slow processing');
              _slowFrameCount = 0;
            }
          } else if (processingTime < processingIntervalMs / 2 && processingIntervalMs > 200) {
            processingIntervalMs = max(200, processingIntervalMs - 50);
            debugPrint('Decreasing interval to ${processingIntervalMs}ms');
          }
        });
      }
    });
  }

  Future<void> _processCameraImage(CameraImage cameraImage) async {
    img.Image? image;
    img.Image? resizedImage;
    
    try {
      // Don't reload model anymore - it causes instability
      // Original issue was stuck predictions, but model reload is too aggressive
      
      // Convert CameraImage to img.Image (downsampled)
      image = _convertCameraImageOptimized(cameraImage);
      if (image == null) return;

      // Resize for model input (640x640 for YOLO model)
      resizedImage = img.copyResize(image, width: 640, height: 640, interpolation: img.Interpolation.linear);

      // Run inference
      final detections = await _runInference(resizedImage);

      if (mounted) {
        setState(() {
          _detections = detections;
          if (detections.isNotEmpty) {
            _statusMessage = 'Spark plug detected! Opening form...';
          } else {
            _statusMessage = 'Scanning...';
          }
        });
      }
    } catch (e) {
      debugPrint('Processing error: $e');
    } finally {
      // Clear references to allow garbage collection
      image = null;
      resizedImage = null;
    }
  }

  img.Image? _convertCameraImageOptimized(CameraImage cameraImage) {
    try {
      // Downsample by 2x during conversion to reduce memory and processing time
      final int origWidth = cameraImage.width;
      final int origHeight = cameraImage.height;
      final int width = origWidth ~/ 2;
      final int height = origHeight ~/ 2;
      final int uvRowStride = cameraImage.planes[1].bytesPerRow;
      final int uvPixelStride = cameraImage.planes[1].bytesPerPixel ?? 1;

      final img.Image image = img.Image(width: width, height: height);
      final yPlane = cameraImage.planes[0].bytes;
      final uPlane = cameraImage.planes[1].bytes;
      final vPlane = cameraImage.planes[2].bytes;

      // Process every other pixel to downsample
      for (int h = 0; h < height; h++) {
        final int origH = h * 2;
        final int uvRow = (origH ~/ 2) * uvRowStride;
        for (int w = 0; w < width; w++) {
          final int origW = w * 2;
          final int uvIndex = (origW ~/ 2) * uvPixelStride + uvRow;
          final int yIndex = origH * origWidth + origW;

          final int y = yPlane[yIndex];
          final int u = uPlane[uvIndex];
          final int v = vPlane[uvIndex];

          // Fast YUV to RGB conversion with integer math
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

  Future<List<Detection>> _runInference(img.Image resizedImage) async {
    Float32List? inputBuffer;
    
    try {
      if (_session == null) {
        return [];
      }

      // Convert to Float32 input tensor format (channels-first for YOLO)
      inputBuffer = _imageToFloat32ListOptimized(resizedImage);

      // Create ONNX Runtime input tensor [1, 3, 640, 640] (NCHW format)
      final inputOrt = OrtValueTensor.createTensorWithDataList(
        inputBuffer,
        [1, 3, 640, 640],
      );
      
      // Get input name from session
      final inputNames = _session!.inputNames;
      final runOptions = OrtRunOptions();

      // Run inference
      final outputs = _session!.run(
        runOptions,
        {inputNames.first: inputOrt},
      );
      
      // Get output tensor - output shape is [1, 5, 8400] for YOLO
      final outputValue = outputs.first;
      if (outputValue == null) {
        debugPrint('No output from model');
        inputOrt.release();
        runOptions.release();
        for (var o in outputs) {
          o?.release();
        }
        return [];
      }
      
      // Output shape: [1, 5, 8400]
      // Each of 8400 predictions has 5 values: [x, y, w, h, confidence]
      final outputData = outputValue.value as List<List<List<double>>>;
      
      // Process object detection output
      List<Detection> detections = [];
      const threshold = 0.90; // 90% confidence threshold for auto-opening form

      // Parse detections from [1, 5, 8400] format
      final predictions = outputData[0]; // Shape: [5, 8400]
      
      double maxConfidence = 0.0;
      int bestDetectionIdx = -1;
      
      // Find the detection with highest confidence
      for (int i = 0; i < 8400; i++) {
        double confidence = predictions[4][i]; // 5th value is confidence
        
        if (confidence > maxConfidence) {
          maxConfidence = confidence;
          bestDetectionIdx = i;
        }
      }
      
      // Update current scores for UI display
      if (mounted) {
        setState(() {
          _currentClass0Score = 1.0 - maxConfidence; // Background score
          _currentClass1Score = maxConfidence; // Spark plug score
          _currentPrediction = maxConfidence > 0.5 ? 'spark plug' : 'background';
        });
      }

      debugPrint('Best detection confidence: ${(maxConfidence * 100).toStringAsFixed(2)}%');

      // If detection confidence >= threshold
      if (maxConfidence >= threshold && bestDetectionIdx >= 0) {
        detections.add(
          Detection(
            confidence: maxConfidence,
            label: 'spark plug',
          ),
        );

        // Automatically open the form (only once per scan session)
        if (mounted && !_formOpened) {
          _formOpened = true; // Prevent multiple triggers
          Future.delayed(Duration.zero, () {
            _openFormWithDetectedItem('spark plug');
          });
        }
      }

      // Clean up
      inputOrt.release();
      runOptions.release();
      for (var o in outputs) {
        o?.release();
      }

      return detections;
    } catch (e, stackTrace) {
      debugPrint('Inference error: $e');
      debugPrint('Stack trace: $stackTrace');
      return [];
    } finally {
      // Clear input buffer
      inputBuffer = null;
    }
  }

  Float32List _imageToFloat32ListOptimized(img.Image image) {
    // Input shape: [1, 3, 640, 640] in NCHW format (channels-first)
    final int inputSize = 3 * 640 * 640;
    final Float32List buffer = Float32List(inputSize);
    
    // Fill in channels-first order: all R values, then all G values, then all B values
    final int channelSize = 640 * 640;
    
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        final int pixelIndex = y * image.width + x;
        
        // Normalize from [0, 255] to [0.0, 1.0]
        buffer[pixelIndex] = pixel.r / 255.0;                    // R channel
        buffer[channelSize + pixelIndex] = pixel.g / 255.0;      // G channel
        buffer[2 * channelSize + pixelIndex] = pixel.b / 255.0;  // B channel
      }
    }
    
    return buffer;
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
        _formOpened = false; // Reset flag to allow another auto-detection
        // Restart camera stream
        if (_cameraController != null &&
            _cameraController!.value.isInitialized) {
          _startImageStream();
        }
      }
    );
  }

  @override
  void dispose() {
    _cameraController?.stopImageStream().then((_) {
      _cameraController?.dispose();
    });
    _session?.release();
    _session = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Spark Plug Scanner'),
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
                        if (!_formOpened)
                          Text(
                            'Point camera at spark plug (90% confidence required)',
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.9),
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 8),
                        // Real-time classification scores
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Live Scores:',
                                style: TextStyle(
                                  color: Colors.yellow,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Background: ${(_currentClass0Score * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                ),
                              ),
                              Text(
                                'Spark Plug: ${(_currentClass1Score * 100).toStringAsFixed(1)}%',
                                style: TextStyle(
                                  color: _currentClass1Score > 0.5 ? Colors.green : Colors.white,
                                  fontSize: 11,
                                  fontWeight: _currentClass1Score > 0.5 ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                              Text(
                                'Prediction: $_currentPrediction',
                                style: TextStyle(
                                  color: Colors.cyan,
                                  fontSize: 11,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
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
