# HomeCrew

HomeCrew is an iOS application built with SwiftUI for managing household staff and associated documentation. The app provides a comprehensive solution for tracking staff members, their employment details, and related documents across multiple households.

## Features

### Household Management
- Create and manage multiple households
- Store household name, address, and notes
- View all households in a list with navigation to associated staff
- Delete households with confirmation

### Staff Management
- Add staff members to households with comprehensive details:
  - Full legal name and commonly known name
  - Employment dates (start and optional end date)
  - Monthly salary with currency support
  - Allocated leave days
  - Agreed duties description
  - Active/inactive status
- View staff members organized by household
- Edit staff member details
- Filter active/inactive staff members
- Track employment duration automatically

### Document Management
- View PDF documents
- View image documents (JPEG, PNG, HEIC)
- Document picker integration
- Support for multiple document types

### Authentication & Data Sync
- iCloud account required for data synchronization
- CloudKit integration for seamless data sync across devices
- Secure keychain storage for user credentials
- Apple Sign In support

## Requirements

- iOS 14.0 or later
- Xcode 14.0 or later
- Active iCloud account
- Apple Developer account (for CloudKit configuration)

## Architecture

### Technology Stack
- **SwiftUI**: Modern declarative UI framework
- **CloudKit**: Cloud database and synchronization
- **Core Data**: Local data persistence with CloudKit integration
- **AuthenticationServices**: Apple Sign In integration
- **UniformTypeIdentifiers**: Document type handling

### Project Structure

```
HomeCrew/
├── HomeCrewApp.swift          # App entry point
├── ContentView.swift           # Main content view
├── MainTabView.swift           # Tab navigation structure
├── AuthManager.swift           # Authentication management
├── SignInView.swift            # Sign in interface
├── Persistence.swift           # Core Data persistence controller
├── HouseHold/                  # Household management
│   ├── HouseHoldView.swift
│   └── HouseHoldProfileView.swift
├── Staff/                      # Staff management
│   ├── Staff.swift             # Staff data model
│   ├── StaffListView.swift
│   ├── StaffView.swift
│   ├── StaffDetailView.swift
│   ├── AddStaffView.swift
│   ├── EditStaffView.swift
│   ├── StaffDocument.swift
│   └── StaffDocumentManager.swift
└── Documents/                  # Document handling
    ├── DocumentItem.swift
    ├── DocumentPicker.swift
    ├── DocumentSelectionView.swift
    ├── DocumentViewerView.swift
    └── PDFViewerView.swift
```

### Data Models

#### HouseHold
- `id`: CloudKit record ID
- `name`: Household name
- `address`: Physical address
- `notes`: Optional notes

#### Staff
- `id`: CloudKit record ID
- `householdReference`: Reference to parent household
- `fullLegalName`: Full legal name
- `commonlyKnownAs`: Optional preferred name
- `startingDate`: Employment start date
- `leavingDate`: Optional employment end date
- `leavesAllocated`: Annual leave allocation
- `monthlySalary`: Monthly salary amount
- `currencyCode`: Currency identifier (e.g., "USD", "EUR")
- `agreedDuties`: Job duties description
- `isActive`: Employment status

## CloudKit Configuration

The app uses CloudKit for data synchronization. The CloudKit container identifier is:
- `iCloud.com.eisenvault.HomeCrew`

### Required CloudKit Schema

The app expects the following record types in CloudKit:

1. **HouseHold**
   - `name` (String)
   - `address` (String)
   - `notes` (String, optional)

2. **Staff**
   - `householdID` (Reference to HouseHold)
   - `fullLegalName` (String)
   - `commonlyKnownAs` (String, optional)
   - `startingDate` (Date)
   - `leavingDate` (Date, optional)
   - `leavesAllocated` (Int64)
   - `monthlySalary` (Double)
   - `currencyCode` (String)
   - `agreedDuties` (String)
   - `isActive` (Int64/Boolean)

Configure these record types in the CloudKit Dashboard before deploying the app.

## Setup Instructions

### Prerequisites
1. Clone the repository
2. Open `HomeCrew.xcodeproj` in Xcode
3. Ensure your Apple Developer account is configured in Xcode

### CloudKit Setup
1. In Xcode, select the project target
2. Go to "Signing & Capabilities"
3. Verify CloudKit capability is enabled
4. Ensure the container identifier matches: `iCloud.com.eisenvault.HomeCrew`
5. Configure CloudKit schema in CloudKit Dashboard:
   - Create the `HouseHold` and `Staff` record types
   - Set appropriate field types and indexes
   - Configure security roles if needed

### Build and Run
1. Select a simulator or connected iOS device
2. Build and run the project (⌘R)
3. Sign in with your iCloud account when prompted

## Usage

### First Launch
1. The app will check for iCloud account availability
2. If not signed in, you'll be prompted to sign in via Settings
3. Once signed in, you'll see the main households view

### Adding a Household
1. Tap the "+" button in the households view
2. Enter household name and address
3. Tap "Save Household"

### Adding Staff
1. Select a household from the list
2. Tap "Add Staff" button
3. Fill in staff details:
   - Full legal name (required)
   - Commonly known name (optional)
   - Starting date (required)
   - Monthly salary and currency
   - Leave allocation
   - Agreed duties
4. Tap "Save"

### Managing Staff
- Tap any staff member to view details
- Edit information from the detail view
- Swipe to delete (if implemented)
- Toggle active/inactive status

### Viewing Documents
- Navigate to staff detail view
- Access document viewer for associated documents
- View PDFs and images in-app

## Error Handling

The app includes comprehensive error handling for:
- Network connectivity issues
- iCloud service unavailability
- CloudKit authentication errors
- Storage quota exceeded
- Invalid data operations

Error messages are displayed to users with actionable guidance.

## Security & Privacy

- User data is stored in iCloud private database
- Authentication credentials stored securely in iOS Keychain
- Document access respects iOS sandboxing
- No data is transmitted to third-party services

## Development Notes

### Logging
The app uses `os.log` for structured logging:
- Authentication: `com.homecrew.auth`
- Household operations: `com.homecrew.household`
- Document operations: `com.homecrew.documents`
- Core Data: `com.homecrew.persistence`

### Testing
- Unit tests are located in `HomeCrewTests/`
- UI tests are located in `HomeCrewUITests/`

## License

Copyright © 2025. All rights reserved.

## Support

For issues, questions, or contributions, please refer to the project repository.

