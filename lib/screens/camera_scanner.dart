import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:camera/camera.dart';
import 'package:forui/forui.dart';
import 'package:storehsk/widgets/item_form.dart';
import 'package:storehsk/models/stocks.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

class CameraScanner extends StatefulWidget {
  final Function(Stocks)? onItemDetected;

  const CameraScanner({super.key, this.onItemDetected});

  @override
  State<CameraScanner> createState() => _CameraScannerState();
}

class _CameraScannerState extends State<CameraScanner> {
  CameraController? _cameraController;
  bool _isProcessing = false;
  BarcodeScanner? _barcodeScanner;
  List<Barcode> _barcodes = [];
  String _statusMessage = 'Initializing barcode scanner...';
  DateTime _lastProcessedTime = DateTime.now();
  int processingIntervalMs = 500; // Process every 500ms
  bool _formOpened = false; // Track if form has been auto-opened
  String _lastScannedBarcode = ''; // To avoid duplicate scans

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Initialize barcode scanner
    _barcodeScanner = BarcodeScanner(formats: [
      BarcodeFormat.all, // Support all barcode formats
    ]);
    
    // Initialize camera
    await _initializeCamera();
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
        ResolutionPreset.high,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.nv21, // For ML Kit
      );

      await _cameraController!.initialize();

      if (!mounted) return;

      setState(() {
        _statusMessage = 'Ready to scan barcodes';
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

      if (!_isProcessing && timeSinceLastProcess >= processingIntervalMs) {
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
      if (_barcodeScanner == null) return;

      // Convert CameraImage to InputImage for ML Kit
      final WriteBuffer allBytes = WriteBuffer();
      for (final Plane plane in cameraImage.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize = Size(
        cameraImage.width.toDouble(),
        cameraImage.height.toDouble(),
      );

      final InputImageRotation imageRotation =
          InputImageRotation.rotation0deg;

      final InputImageFormat inputImageFormat =
          InputImageFormat.nv21;

      final planeData = cameraImage.planes.map(
        (Plane plane) {
          return InputImageMetadata(
            bytesPerRow: plane.bytesPerRow,
            size: Size(plane.width?.toDouble() ?? 0, plane.height?.toDouble() ?? 0),
            rotation: imageRotation,
            format: inputImageFormat,
          );
        },
      ).toList();

      final inputImage = InputImage.fromBytes(
        bytes: bytes,
        metadata: InputImageMetadata(
          size: imageSize,
          rotation: imageRotation,
          format: inputImageFormat,
          bytesPerRow: cameraImage.planes[0].bytesPerRow,
        ),
      );

      // Scan for barcodes
      final barcodes = await _barcodeScanner!.processImage(inputImage);

      if (mounted) {
        setState(() {
          _barcodes = barcodes;
          if (barcodes.isNotEmpty) {
            final String scannedValue = barcodes.first.rawValue ?? '';
            _statusMessage = 'Barcode detected: $scannedValue';
            
            // Auto-open form only if it's a new barcode
            if (!_formOpened && scannedValue.isNotEmpty && scannedValue != _lastScannedBarcode) {
              _formOpened = true;
              _lastScannedBarcode = scannedValue;
              Future.delayed(Duration.zero, () {
                _openFormWithDetectedBarcode(scannedValue);
              });
            }
          } else {
            _statusMessage = 'Scanning for barcodes...';
          }
        });
      }
    } catch (e) {
      debugPrint('Processing error: $e');
    }
  }

  void _showBarcodeDialog(Barcode barcode) {
    final String barcodeValue = barcode.rawValue ?? 'Unknown';
    final String barcodeType = barcode.format.name;

    showFDialog(
      context: context,
      builder: (context, style, animation) => FDialog(
        title: const Text('Barcode Detected'),
        body: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Value: $barcodeValue'),
            Text('Type: $barcodeType'),
            const SizedBox(height: 16),
            const Text('What would you like to do?'),
          ],
        ),
        actions: [
          FButton(
            onPress: () {
              Navigator.pop(context);
              _formOpened = false; // Allow scanning again
              _lastScannedBarcode = ''; // Reset
            },
            child: const Text('Continue Scanning'),
          ),
          FButton(
            onPress: () {
              Navigator.pop(context);
              Navigator.pop(context); // Close camera screen
            },
            child: const Text('Cancel'),
          ),
          FButton(
            onPress: () {
              Navigator.pop(context);
              _openFormWithDetectedBarcode(barcodeValue);
            },
            child: const Text('Add to Inventory'),
          ),
        ],
      ),
    );
  }

  void _openFormWithDetectedBarcode(String barcodeValue) {
    // Pause camera stream while showing form
    _cameraController?.stopImageStream();

    showItemFormSheet(
      context,
      itemName: barcodeValue,
      onItemSaved: (newItem) {
        widget.onItemDetected?.call(newItem);
        _formOpened = false; // Reset flag to allow another scan
        _lastScannedBarcode = ''; // Reset last scanned barcode
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
    _barcodeScanner?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Barcode Scanner'),
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

                // Scanning frame overlay
                Center(
                  child: Container(
                    width: 300,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: _barcodes.isNotEmpty ? Colors.green : Colors.white,
                        width: 3,
                      ),
                      borderRadius: BorderRadius.circular(12),
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
                        if (!_formOpened)
                          Text(
                            'Point camera at a barcode',
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
                if (_barcodes.isNotEmpty)
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
                        children: _barcodes.map((barcode) {
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
                                    '${barcode.format.name}: ${barcode.rawValue ?? "Unknown"}',
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
                if (_barcodes.isNotEmpty)
                  Positioned(
                    bottom: 100,
                    left: 20,
                    right: 20,
                    child: FButton(
                      onPress: () {
                        if (_barcodes.isNotEmpty) {
                          _showBarcodeDialog(_barcodes.first);
                        }
                      },
                      style: .delta(contentStyle: .delta(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12))),
                      prefix: const Icon(FIcons.check),
                      child: const Text('Add to Inventory'),
                    ),
                  ),
              ],
            ),
    );
  }
}


