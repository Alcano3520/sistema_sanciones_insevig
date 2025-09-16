# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview
This is a Flutter application for managing employee sanctions at INSEVIG (Instituto Nacional de Seguros y Finanzas). It's a dual-architecture system that works both online (web) and offline (mobile) with Supabase as the backend.

## Development Commands

### Build and Run
- `flutter pub get` - Install dependencies
- `flutter run` - Run app in debug mode
- `flutter run --release` - Run in release mode
- `flutter run -d chrome` - Run on web browser
- `flutter run -d android` - Run on Android device/emulator

### Code Quality
- `flutter analyze` - Run static analysis (uses `analysis_options.yaml`)
- `flutter test` - Run tests
- `flutter pub deps` - Show dependency tree
- `flutter clean` - Clean build artifacts
- `flutter pub get` - Get dependencies after clean

### Build Artifacts
- `flutter build apk` - Build Android APK
- `flutter build appbundle` - Build Android App Bundle
- `flutter build web` - Build web version

### Code Generation (for Hive models)
- `flutter packages pub run build_runner build` - Generate Hive type adapters
- `flutter packages pub run build_runner build --delete-conflicting-outputs` - Force rebuild adapters

## Architecture

### Dual Architecture Design
The app uses a dual-architecture pattern:
- **Online mode (Web)**: Direct Supabase API calls, no offline capabilities
- **Offline mode (Mobile)**: Hive local storage + Supabase sync when connected

### Core Directory Structure
- `lib/core/config/` - Supabase configuration with dual client setup
- `lib/core/models/` - Data models (EmpleadoModel, SancionModel, UserModel)
- `lib/core/offline/` - Offline functionality (OfflineManager, repositories, Hive database)
- `lib/core/providers/` - Provider pattern state management
- `lib/core/services/` - Business logic services
- `lib/ui/screens/` - Application screens
- `lib/ui/widgets/` - Reusable UI components

### Key Components

#### Supabase Configuration
- **Dual client setup**: Separate clients for employees (`empleados-insevig`) and sanctions (`sistema-sanciones-insevig`) projects
- **Authentication**: Handled through the main sanctions project
- Located in `lib/core/config/supabase_config.dart`

#### Offline System (Mobile only)
- **OfflineManager**: Coordinates sync, connectivity detection, fallbacks
- **OfflineDatabase**: Hive-based local storage
- **Repositories**: EmpleadoRepository, SancionRepository for data access abstraction
- **ConnectivityService**: Network status monitoring

#### State Management
- Uses Provider pattern for state management
- AuthProvider handles authentication state
- Located in `lib/core/providers/`

### Data Models
- **EmpleadoModel**: Employee data from separate Supabase project
- **SancionModel**: Sanctions with signatures, images, approvals
- **UserModel**: Authentication and user management

### Key Features
- Employee search and management
- Sanction creation with digital signatures and photo capture
- PDF generation and sharing
- Image compression
- Offline/online synchronization
- Management approval workflows

## Database Setup
The app connects to two Supabase projects:
1. **empleados-insevig**: Employee data (read-only)
2. **sistema-sanciones-insevig**: Sanctions data (read-write with auth)

## Platform-Specific Notes
- **Web**: Online-only, no Hive initialization, direct Supabase calls
- **Mobile**: Full offline capabilities with Hive local storage
- Check `kIsWeb` flag for platform-specific code paths

## Testing
- Basic test setup in `test/widget_test.dart`
- Run tests with `flutter test`
- Add integration tests as needed for offline/online scenarios

## Dependencies
Key dependencies include:
- `supabase_flutter`: Backend API and auth
- `hive` + `hive_flutter`: Local storage (mobile only)
- `provider`: State management
- `connectivity_plus`: Network status
- `image_picker`, `signature`: Media capture
- `pdf`, `printing`: Document generation
- `image`: Image processing and compression