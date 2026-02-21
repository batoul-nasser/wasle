# WASLE – Smart Delivery Coordination Platform
WASLE is a last-mile delivery coordination platform that connects 
e-commerce stores, delivery companies, and customers in one system.

The platform allows merchants to assign delivery orders, delivery 
companies to manage drivers, and customers to track their orders 
securely via OTP authentication.


## 🛠 Tech Stack

- Flutter (Dart)
- Supabase (PostgreSQL, Auth, Realtime)
- Git & GitHub
- REST APIs


## 🚀 Features

- OTP Authentication
- Role-based accounts (Customer, Merchant, Driver)
- Order creation and assignment
- Real-time order tracking
- Secure database with Row Level Security (RLS)

## ⚙️ Setup Instructions

### 1. Clone the repository
git clone https://github.com/yourusername/wasle.git

### 2. Navigate to the project
cd wasle

### 3. Install dependencies
flutter pub get

### 4. Run the project
flutter run -d chrome

## 🔐 Environment Variables

Create a .env file in the root directory and add:

SUPABASE_URL=your_url
SUPABASE_ANON_KEY=your_key

## 📁 Project Structure

lib/
 ├── screens/
 ├── widgets/
 ├── services/
 └── main.dart

 ## 👩‍💻 Team


## 🌿 Git Workflow

- main → stable version
- develop → integration branch
- feature/* → new features
- bugfix/* → fixes