# 🔨 Build Instructions - AI Assistant Pro Android

## 📋 Prerequisites

### Required Software
- **Android Studio** Arctic Fox (2020.3.1) or later
- **Java Development Kit (JDK)** 11 or higher
- **Android SDK** with API level 26+ (Android 8.0)
- **Git** for version control

### System Requirements
- **Operating System**: Windows 10+, macOS 10.14+, or Linux
- **RAM**: 8GB minimum, 16GB recommended
- **Storage**: 4GB free space for Android Studio + SDK
- **Internet**: Required for dependency downloads

## 🚀 Quick Build

### Option 1: Using Build Script (Recommended)
```bash
# Clone the repository
git clone https://github.com/your-username/ai-assistant-pro-android.git
cd ai-assistant-pro-android

# Make build script executable (Linux/macOS)
chmod +x build_and_install.sh

# Run the build script
./build_and_install.sh
```

### Option 2: Manual Build
```bash
# Clean previous builds
./gradlew clean

# Build debug APK
./gradlew assembleDebug

# Build release APK (requires signing)
./gradlew assembleRelease
```

## 🏗️ Detailed Build Process

### Step 1: Environment Setup

#### Install Android Studio
1. Download from [developer.android.com](https://developer.android.com/studio)
2. Install with default settings
3. Launch and complete setup wizard
4. Install Android SDK Platform 26+ via SDK Manager

#### Configure SDK Path
```bash
# Add to ~/.bashrc or ~/.zshrc (Linux/macOS)
export ANDROID_HOME=$HOME/Android/Sdk
export PATH=$PATH:$ANDROID_HOME/tools
export PATH=$PATH:$ANDROID_HOME/platform-tools

# Windows (add to System Environment Variables)
ANDROID_HOME=C:\Users\%USERNAME%\AppData\Local\Android\Sdk
PATH=%PATH%;%ANDROID_HOME%\tools;%ANDROID_HOME%\platform-tools
```

### Step 2: Project Setup

#### Clone Repository
```bash
git clone https://github.com/your-username/ai-assistant-pro-android.git
cd ai-assistant-pro-android
```

#### Open in Android Studio
1. Launch Android Studio
2. Select "Open an Existing Project"
3. Navigate to cloned directory
4. Click "OK" to open project
5. Wait for Gradle sync to complete

### Step 3: Build Configuration

#### Debug Build
```bash
# Generate debug APK
./gradlew assembleDebug

# Output location
app/build/outputs/apk/debug/app-debug.apk
```

#### Release Build
```bash
# Generate release APK (unsigned)
./gradlew assembleRelease

# Output location
app/build/outputs/apk/release/app-release-unsigned.apk
```

#### Signed Release Build
1. **Create Keystore** (first time only):
```bash
keytool -genkey -v -keystore ai-assistant-release.keystore \
        -alias ai-assistant -keyalg RSA -keysize 2048 -validity 10000
```

2. **Configure Signing** in `app/build.gradle`:
```gradle
android {
    signingConfigs {
        release {
            storeFile file('ai-assistant-release.keystore')
            storePassword 'your-store-password'
            keyAlias 'ai-assistant'
            keyPassword 'your-key-password'
        }
    }
    buildTypes {
        release {
            signingConfig signingConfigs.release
            minifyEnabled false
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt'), 'proguard-rules.pro'
        }
    }
}
```

3. **Build Signed APK**:
```bash
./gradlew assembleRelease
```

## 🧪 Testing

### Unit Tests
```bash
# Run unit tests
./gradlew test

# Run with coverage
./gradlew testDebugUnitTestCoverage
```

### Instrumentation Tests
```bash
# Run on connected device/emulator
./gradlew connectedAndroidTest
```

### Manual Testing
1. Install APK on device: `adb install app-debug.apk`
2. Test core functionality:
   - Home screen navigation
   - AI service switching
   - Settings configuration
   - Floating window (requires overlay permission)
   - Share functionality

## 📱 Installation

### Install on Device
```bash
# Install debug build
adb install app/build/outputs/apk/debug/app-debug.apk

# Install release build
adb install app/build/outputs/apk/release/app-release.apk

# Install with replacement
adb install -r app-debug.apk
```

### Install on Emulator
1. Launch Android emulator
2. Drag APK file onto emulator window
3. Follow installation prompts

## 🔧 Troubleshooting

### Common Build Issues

#### Gradle Sync Failed
```bash
# Clean and rebuild
./gradlew clean
./gradlew build --refresh-dependencies
```

#### SDK Not Found
1. Open SDK Manager in Android Studio
2. Install missing SDK platforms/tools
3. Update `local.properties` with correct SDK path

#### Memory Issues
```bash
# Increase Gradle memory in gradle.properties
org.gradle.jvmargs=-Xmx4g -XX:MaxPermSize=512m
```

#### Dependency Conflicts
```bash
# View dependency tree
./gradlew app:dependencies

# Force dependency versions in app/build.gradle
configurations.all {
    resolutionStrategy.force 'dependency:version'
}
```

### Runtime Issues

#### App Crashes on Launch
1. Check device logs: `adb logcat`
2. Verify minimum API level (26+)
3. Ensure all permissions granted

#### WebView Issues
1. Update Android System WebView
2. Clear app data and cache
3. Check internet connectivity

#### Floating Window Not Working
1. Grant overlay permission manually
2. Check Android version (8.0+)
3. Disable battery optimization for app

## 📊 Build Optimization

### Reduce APK Size
```gradle
android {
    buildTypes {
        release {
            minifyEnabled true
            shrinkResources true
            proguardFiles getDefaultProguardFile('proguard-android-optimize.txt')
        }
    }
}
```

### Enable R8 Optimization
```gradle
android {
    buildTypes {
        release {
            minifyEnabled true
            useProguard false
        }
    }
}
```

### Split APKs by Architecture
```gradle
android {
    splits {
        abi {
            enable true
            reset()
            include 'arm64-v8a', 'armeabi-v7a', 'x86', 'x86_64'
            universalApk false
        }
    }
}
```

## 🚀 Continuous Integration

### GitHub Actions Example
```yaml
name: Build APK
on: [push, pull_request]
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v2
    - name: Set up JDK 11
      uses: actions/setup-java@v2
      with:
        java-version: '11'
        distribution: 'adopt'
    - name: Build with Gradle
      run: ./gradlew assembleDebug
    - name: Upload APK
      uses: actions/upload-artifact@v2
      with:
        name: app-debug
        path: app/build/outputs/apk/debug/app-debug.apk
```

## 📝 Build Variants

### Debug
- Debuggable: Yes
- Minification: Disabled
- Logging: Enabled
- Performance: Not optimized

### Release
- Debuggable: No
- Minification: Enabled
- Logging: Disabled
- Performance: Optimized

### Custom Variants
```gradle
android {
    flavorDimensions "version"
    productFlavors {
        free {
            dimension "version"
            applicationIdSuffix ".free"
            versionNameSuffix "-free"
        }
        pro {
            dimension "version"
            applicationIdSuffix ".pro"
            versionNameSuffix "-pro"
        }
    }
}
```

---

**Happy Building! 🎉**

For additional support, please check our [GitHub Issues](https://github.com/your-username/ai-assistant-pro-android/issues) or refer to the [Android Developer Documentation](https://developer.android.com/docs).