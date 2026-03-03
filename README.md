# SignalR Event Processing Application

A Flutter application that connects to a SignalR hub to receive and process events, with local SQLite storage for events and payloads.

## Author

Sheshehang Limbu(HunterVinic)

## Table of Contents
- [Overview](#overview)
- [Architecture](#architecture)
- [Prerequisites](#prerequisites)
- [Installation](#installation)
- [Configuration](#configuration)
- [Database Structure](#database-structure)
- [Core Components](#core-components)
- [Usage](#usage)
- [Features](#features)
- [Performance Monitoring](#performance-monitoring)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)

## Overview

This application establishes a real-time connection to a SignalR hub to receive events, stores them locally in SQLite databases, and processes them based on event type. It includes comprehensive error handling, retry mechanisms, and performance monitoring capabilities.

## Architecture

The application follows a modular architecture with the following key components:

```
├── Main Application (ChatPage)
├── Database Helpers
│   ├── DatabaseHelper (Main events)
│   ├── PayloadDatabaseHelper (Normal updates)
│   └── CompanyDatabaseHelper (Company updates)
├── UI Pages
│   ├── DatabasePage (Event viewer)
│   ├── UpdatePage (Payload viewer)
│   └── CompanyPage (Company data viewer)
└── Isolate Management
    └── Background processing
```

## Prerequisites

- Flutter SDK (>=3.0.0)
- Dart SDK (>=3.0.0)
- Android Studio / VS Code
- iOS/Android device or emulator
- Internet connection for SignalR connectivity

## Installation

```bash
# Clone the repository
git clone <repository-url>
cd <project-directory>

# Install dependencies
flutter pub get

# Run the application
flutter run
```

## Configuration

### Dependencies

Add these to your `pubspec.yaml`:

```yaml
dependencies:
  flutter:
    sdk: flutter
  sqflite: ^2.3.0
  path: ^1.8.3
  signalr_netcore: ^1.3.4
  connectivity_plus: ^5.0.1
  http: ^1.1.0
```

### SignalR Hub Connection

The application connects to:
- Hub URL: `https://rt-signalr.ihusaan.dev/authhub`
- Token endpoint: `https://rt-signalr.ihusaan.dev/connect/token`
- Event body endpoint: `https://rt-signalr.ihusaan.dev/Events/getbody`

## Database Structure

### Main Events Database (`events.db`)

```sql
CREATE TABLE events (
  id INTEGER PRIMARY KEY,
  eventId INTEGER,
  eventType TEXT,
  createdAt TEXT,
  correlationId TEXT,
  containsBody INTEGER,
  payload TEXT,
  status TEXT,
  UNIQUE (eventId, eventType, createdAt, correlationId, payload, status)
);

CREATE INDEX idx_status ON events (status);
CREATE INDEX idx_eventId ON events (eventId);
CREATE INDEX idx_eventType ON events (eventType);
```

### Payload Database (`payload.db`)

```sql
CREATE TABLE payload (
  id INTEGER PRIMARY KEY,
  Code TEXT,
  Name TEXT,
  Description TEXT,
  Brand TEXT,
  MerchandisingCategory INTEGER,
  Image TEXT,
  BasePrice TEXT,
  BaseUom TEXT,
  IsBatchItem TEXT,
  TaxId TEXT
);
```

### Company Database (`company.db`)

Same structure as payload database.

## Core Components

### DatabaseHelper

Manages the main events database with features:
- Event insertion with duplicate detection
- Duplicate removal utility
- Status-based queries
- Bulk status updates

### PayloadDatabaseHelper & CompanyDatabaseHelper

Handle specific event type payloads with identical structures for:
- Normal updates (payload.db)
- Company updates (company.db)

### ChatPage

Main SignalR hub connection manager with:
- Automatic reconnection
- Network connectivity monitoring
- Event receiving and processing
- Performance timing

### DatabasePage

UI for viewing and managing events with:
- Event list display
- Manual event sending
- Status tracking
- Event deletion

## Usage

### Starting the Application

1. Launch the app
2. Automatic authentication occurs using client credentials
3. SignalR connection establishes automatically
4. Pending events are requested upon connection

### Event Flow

1. **Event Reception**: Events received via SignalR hub
2. **Storage**: Events stored in SQLite database with PENDING status
3. **Processing**: Background timer processes pending events every second
4. **Payload Handling**: 
   - If containsBody = false, fetches payload from endpoint
   - Routes to appropriate database based on eventType
5. **Status Updates**: Sends status updates back to server

### Navigation

- **Main Screen**: Chat interface with connection status
- **Events Page** (➕ icon): View and manage events
- **Payloads Page** (🌳 icon): View normal update payloads
- **Company Page** (🏢 icon): View company update payloads

## Features

### Real-time Communication
- SignalR hub connection with automatic reconnect
- Connection state monitoring
- Ping mechanism for connection verification

### Database Operations
- ACID-compliant SQLite storage
- Indexed queries for performance
- Duplicate detection and removal
- Batch operations support

### Error Handling
- Comprehensive try-catch blocks
- Retry mechanism (3 attempts)
- Status tracking (PENDING, COMPLETED, FAULTED, etc.)
- Error logging and display

### Performance Monitoring
- Real-time FPS counter
- Elapsed time tracking
- Operation timing metrics
- Isolate-based connection checking

### UI Features
- Responsive data tables
- Horizontal scrolling for wide datasets
- Delete operations with UI refresh
- Connection status indicators

## Performance Monitoring

The app includes built-in performance monitoring:

```dart
// Timer for operation duration
final startTime = DateTime.now();
// ... operation ...
final endTime = DateTime.now();
final elapsedTime = endTime.difference(startTime);
print('Operation took: ${elapsedTime.inMilliseconds} ms');

// FPS counter
var fps = 1000.0 / elapsedMilliseconds;
fpsController.add(fps);
```

## Troubleshooting

### Common Issues

1. **Connection Failures**
   - Check internet connectivity
   - Verify access token validity
   - Check if hub URL is accessible

2. **Database Errors**
   - Ensure database initialization completes
   - Check for constraint violations
   - Verify index creation

3. **Performance Issues**
   - Monitor FPS counter
   - Check for database locks
   - Verify isolate operations

### Debug Logging

The application includes extensive logging:
- Connection state changes
- Event reception/processing
- Database operations
- Error conditions
- Performance metrics

## Contributing

1. Fork the repository
2. Create feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit changes (`git commit -m 'Add AmazingFeature'`)
4. Push to branch (`git push origin feature/AmazingFeature`)
5. Open Pull Request

### Coding Standards

- Follow Dart style guide
- Add comments for complex logic
- Include error handling
- Write descriptive commit messages

## 📜 License

Copyright (c) 2026 Sheshehang Limbu(HunterVinic)

All rights reserved.

This project may not be copied, modified, or distributed
without explicit permission from the author.
