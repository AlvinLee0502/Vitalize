# Vitalize

Vitalize is a Flutter-based health and fitness mobile application designed to help users track their daily activity, connect with health professionals, and participate in a supportive fitness community.

---

## Features

### For Users
- **Personal Dashboard**: Steps, calories burnt, heart rate, water reminders, achievements, and meal plans.
- **Bluetooth Smartwatch Integration**: Connect via Bluetooth (using `flutter_blue`) to track heart rate, steps, and calories.
- **Meal Plans**: Subscribe to professional meal plans or use default ones.
- **Workout Plans**: Choose categorized workouts (beginner, intermediate, advanced).
- **Community**: Post, interact with others, and view admin announcements.
- **Goals**: Accept challenges set by admins to earn points and compete with others.
- **Food Selection**: Search, select, and save food items by meal type and date.

### For Health Professionals
- **Profile Management**: Create and edit professional profiles (bio, specializations, etc.).
- **Monetized Content**: Upload paid workout or meal plans for subscribers.
- **Revenue Dashboard**: Track total revenue earned from subscribers.

### For Admins
- **Community Announcements**: Post global updates.
- **Goals Management**: Create, update, or delete challenges for users.
- **Role Management**: Approve or reject health professional applications.
- **Profile Editing**: Update admin profile details.

---

## Tech Stack

- **Framework**: Flutter (Dart)
- **Backend**: Firebase
  - Firebase Authentication
  - Cloud Firestore
  - Firebase Core
- **State Management**: Provider
- **Charts**: charts_flutter
- **Bluetooth**: flutter_blue
- **Video Compression**: light_compressor_ohos

---

## Installation

1. Clone the repository:
  git clone https://github.com/AlvinLee0502/Vitalize.git
2. Navigate into the project folder:
  cd Vitalize
3. Install dependencies:
  flutter pub get
4. Run the app:
  flutter run


---

## Project Structure (simplified)

- `lib/`
- `signin_screen.dart` – User login
- `dashboard/` – Main user dashboard & modules
- `bluetooth_scan_screen.dart` – Smartwatch connection
- `meal_plans/` – Meal plan selection & subscriptions
- `workouts/` – Workout plans by category
- `community/` – Community feed, posts, announcements
- `admin/` – Admin tools (profile, goals, approvals)
- `health_professionals/` – Professional dashboards, content upload
- `user_meals/` – User food logging

---

## Getting Started (First-Time Users)

- The app starts with `first_time_user_screen.dart` so new users can choose how to get started.
- Authentication is handled via Firebase Auth.
- Users can apply to become health professionals; applications are reviewed by admins.
- Admin privileges are only granted by the super admin.

---

## Future Enhancements

- Improved Bluetooth scanning and device management.
- Gamified achievements and leaderboard.
- Expanded food database and nutrition tracking.
- Push notifications for water reminders and community updates.

---

## License

This project is for educational and personal use. All rights reserved.
