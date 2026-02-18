import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:storehsk/component/itemForm.dart';
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
  int _frameCount = 0;
  int _slowFrameCount = 0;
  DateTime? _modelLoadTime;
  
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
      
      // Load model from assets
      final modelData = await rootBundle.load('model/object_detection.onnx');
      final modelBytes = modelData.buffer.asUint8List();
      
      // Create ONNX Runtime session with optimizations
      final sessionOptions = OrtSessionOptions()
        ..setInterOpNumThreads(2)
        ..setIntraOpNumThreads(2)
        ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
      
      _session = OrtSession.fromBuffer(modelBytes, sessionOptions);
      _modelLoadTime = DateTime.now();
      
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
      _frameCount++;
      
      // Don't reload model anymore - it causes instability
      // Original issue was stuck predictions, but model reload is too aggressive
      
      // Convert CameraImage to img.Image (downsampled)
      image = _convertCameraImageOptimized(cameraImage);
      if (image == null) return;

      // Resize for model input (use bilinear interpolation like cv2.resize)
      resizedImage = img.copyResize(image, width: 224, height: 224, interpolation: img.Interpolation.linear);

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

      // Convert to Float32 input tensor format (optimized)
      inputBuffer = _imageToFloat32ListOptimized(resizedImage);

      // Create ONNX Runtime input tensor [1, 224, 224, 3]
      final inputOrt = OrtValueTensor.createTensorWithDataList(
        inputBuffer,
        [1, 224, 224, 3],
      );
      
      // Get input name from session
      final inputNames = _session!.inputNames;
      final runOptions = OrtRunOptions();

      // Run inference
      final outputs = _session!.run(
        runOptions,
        {inputNames.first: inputOrt},
      );
      
      // Get output tensor - assuming output shape is [1, 2]
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
      
      final outputData = outputValue.value as List<List<double>>;
      
      // Process classification output
      List<Detection> detections = [];
      const threshold = 0.90; // 90% confidence threshold for auto-opening form

      // Get output values
      // Class 0 = background, Class 1 = spark plug
      double scoreClass0 = outputData[0][0];
      double scoreClass1 = outputData[0][1];
      
      // Validate outputs are not NaN or infinite
      if (scoreClass0.isNaN || scoreClass0.isInfinite || 
          scoreClass1.isNaN || scoreClass1.isInfinite) {
        debugPrint('Invalid model output detected, skipping frame');
        inputOrt.release();
        runOptions.release();
        for (var o in outputs) {
          o?.release();
        }
        return [];
      }
      
      debugPrint('Raw scores - Class 0 (Background): $scoreClass0, Class 1 (Spark Plug): $scoreClass1');
      
      double confidenceClass0;
      double confidenceClass1;
      
      // Only apply softmax if values are logits (matching Python ModelTest.py behavior)
      if (scoreClass0.abs() > 10 || scoreClass1.abs() > 10) {
        // Values are logits — apply softmax to convert to probabilities
        double maxScore = scoreClass0 > scoreClass1 ? scoreClass0 : scoreClass1;
        double expClass0 = exp(scoreClass0 - maxScore);
        double expClass1 = exp(scoreClass1 - maxScore);
        double sumExp = expClass0 + expClass1;
        confidenceClass0 = expClass0 / sumExp;
        confidenceClass1 = expClass1 / sumExp;
      } else {
        // Values are already probabilities — use directly
        confidenceClass0 = scoreClass0;
        confidenceClass1 = scoreClass1;
        
        // Sanity check: probabilities should be between 0 and 1
        if (confidenceClass0 < 0 || confidenceClass0 > 1 || 
            confidenceClass1 < 0 || confidenceClass1 > 1) {
          debugPrint('Invalid probability values detected, skipping frame');
          return [];
        }
      }
      
      debugPrint('Probabilities - Background: ${(confidenceClass0 * 100).toStringAsFixed(2)}%, Spark Plug: ${(confidenceClass1 * 100).toStringAsFixed(2)}%');

      // Update current scores for UI display
      if (mounted) {
        setState(() {
          _currentClass0Score = confidenceClass0;
          _currentClass1Score = confidenceClass1;
          _currentPrediction = confidenceClass1 > confidenceClass0 ? 'spark plug' : 'background';
        });
      }

      // Determine predicted class
      int predictedClass = confidenceClass1 > confidenceClass0 ? 1 : 0;

      // If class 1 (spark plug) detected with confidence >= threshold
      if (predictedClass == 1 && confidenceClass1 >= threshold) {
        detections.add(
          Detection(
            confidence: confidenceClass1,
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
    // Optimized: Use Float32List directly instead of nested lists
    // Input shape: [1, 224, 224, 3] = 150528 floats
    final int inputSize = 224 * 224 * 3;
    final Float32List buffer = Float32List(inputSize);
    
    int bufferIndex = 0;
    // Process in row-major order (height, width, channels)
    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        final pixel = image.getPixel(x, y);
        // Normalize from [0, 255] to [0.0, 1.0]
        buffer[bufferIndex++] = pixel.r / 255.0;
        buffer[bufferIndex++] = pixel.g / 255.0;
        buffer[bufferIndex++] = pixel.b / 255.0;
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
