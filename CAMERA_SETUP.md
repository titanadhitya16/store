# Camera Scanner Setup Guide

## Overview
The camera scanner feature allows you to scan items using your device's camera and the Edge Impulse trained model to automatically detect and add items to your inventory.

## How It Works
1. Click the floating action button (+) in the app
2. Choose "Scan with Camera" from the dialog
3. Position the item in the camera view
4. Tap "Capture & Analyze" to detect the item
5. Review the detected item and choose to add it to inventory or scan again

## Customizing Model Class Names

The camera scanner uses the Edge Impulse TFLite model located at:
```
luqman_dev-project-1-cpp-android-v2/tflite-model/tflite_learn_874838_10.tflite
```

### Update Class Labels
To match your model's actual output classes, edit the `classNames` array in [lib/screens/camera_scanner.dart](lib/screens/camera_scanner.dart#L142):

```dart
// Map index to class name (replace with your actual class names)
final classNames = [
  'Item 1', 'Item 2', 'Item 3', 'Item 4', 'Item 5',
  'Item 6', 'Item 7', 'Item 8', 'Item 9', 'Item 10'
];
```

Replace these with your actual item names from your Edge Impulse project. For example:
```dart
final classNames = [
  'Apple',
  'Banana',
  'Orange',
  'Bread',
  'Milk',
  // ... add all your trained classes
];
```

### Adjust Model Input Size
If your Edge Impulse model uses a different input size than 96x96, update line 110 in [lib/screens/camera_scanner.dart](lib/screens/camera_scanner.dart#L110):

```dart
final resizedImage = img.copyResize(image, width: 96, height: 96);
```

Change the `width` and `height` to match your model's expected input dimensions.

### Update Output Tensor Size
If your model has a different number of output classes, update line 117 in [lib/screens/camera_scanner.dart](lib/screens/camera_scanner.dart#L117):

```dart
var output = List.filled(1 * 10, 0.0).reshape([1, 10]); // Adjust based on model output
```

Change both instances of `10` to match your number of classes.

## Finding Your Edge Impulse Model Details

1. Log into your Edge Impulse project
2. Go to **Dashboard** → **Model information**
3. Note the following:
   - **Input shape**: e.g., 96x96x3 (RGB image)
   - **Output shape**: e.g., 1x10 (10 classes)
   - **Class labels**: The list of items your model can detect

## Testing the Camera Scanner

1. Run your app: `flutter run`
2. Tap the floating (+) button
3. Select "Scan with Camera"
4. Grant camera permissions when prompted
5. Point camera at one of your trained items
6. Tap "Capture & Analyze"
7. Verify the detection result matches your expectations

## Permissions

Camera permissions are automatically requested on first use. They're already configured in:
- Android: [android/app/src/main/AndroidManifest.xml](android/app/src/main/AndroidManifest.xml)
- iOS: Update `ios/Runner/Info.plist` to add camera permission description

## Troubleshooting

### "Model not loaded" error
- Ensure the model file path in pubspec.yaml assets matches the actual file location
- Run `flutter clean && flutter pub get` to refresh assets

### Low detection confidence
- Ensure good lighting conditions
- Hold camera steady
- Train more samples in Edge Impulse for better accuracy

### Wrong item detected
- Update class names array to match your model's output
- Verify model output size matches the number of classes
- Retrain model with more diverse samples

## Alternative: Manual Entry
Users can still manually add items by choosing "Manual Entry" from the dialog instead of using the camera scanner.
