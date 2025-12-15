# ML Model Setup for Flutter

This folder should contain the trained ML model files for on-device BP risk prediction.

## Required Files

Copy these files from your training computer:

| File | Description | Location |
|------|-------------|----------|
| `bp_predictor.tflite` | TensorFlow Lite model | `ml_pipeline/models/` |
| `model_metadata.json` | Feature config & scaling | `ml_pipeline/models/` |

## Setup Steps

### 1. Create the assets folder in your Flutter project

```bash
mkdir -p assets/models
```

### 2. Copy model files

Transfer from your training computer via:
- **AirDrop** (Mac-to-Mac)
- **USB drive**
- **Cloud storage** (Google Drive, Dropbox)
- **scp** command:
  ```bash
  scp user@training-computer:~/ml_pipeline/models/bp_predictor.tflite ./assets/models/
  scp user@training-computer:~/ml_pipeline/models/model_metadata.json ./assets/models/
  ```

### 3. Update `pubspec.yaml`

Add these dependencies and assets:

```yaml
dependencies:
  flutter:
    sdk: flutter
  # ... other deps
  tflite_flutter: ^0.10.4

flutter:
  assets:
    - assets/models/bp_predictor.tflite
    - assets/models/model_metadata.json
```

### 4. Install TFLite Flutter plugin

```bash
flutter pub get
```

### 5. Platform-specific setup

#### iOS
Add to `ios/Podfile`:
```ruby
pod 'TensorFlowLiteSwift'
```

Then run:
```bash
cd ios && pod install && cd ..
```

#### Android
No additional setup required.

## Model Metadata Format

The `model_metadata.json` should contain:

```json
{
  "feature_names": ["age", "gender", "avg_systolic", ...],
  "feature_means": [45.2, 0.5, 128.5, ...],
  "feature_stds": [15.3, 0.5, 18.2, ...],
  "model_accuracy": 0.82,
  "training_date": "2024-12-10"
}
```

## Testing

After setup, the What-If screen should load successfully:

```dart
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => WhatIfScreen(userProfile: userProfile),
  ),
);
```

## Troubleshooting

| Issue | Solution |
|-------|----------|
| "Model not found" | Check asset paths in pubspec.yaml |
| "Asset file not loading" | Run `flutter clean && flutter pub get` |
| iOS build fails | Run `pod install` in ios folder |
