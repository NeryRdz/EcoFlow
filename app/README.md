# 📱 EcoFlow — Mobile App | App Móvil

<div align="center">

[🇺🇸 English](#-english) &nbsp;|&nbsp; [🇲🇽 Español](#-español)

</div>

---

## 🇺🇸 English

> Cross-platform mobile application built with Flutter and Firebase, featuring an interactive map, user authentication, material exchange listings, and a gamified achievement system.

### 🛠️ Tech Stack

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Firestore](https://img.shields.io/badge/Firestore-FF6F00?style=for-the-badge&logo=firebase&logoColor=white)
![OpenStreetMap](https://img.shields.io/badge/OpenStreetMap-7EBC6F?style=for-the-badge&logo=openstreetmap&logoColor=white)

### ✨ Features

#### 👤 Authentication
- Email & password login via **Firebase Auth**
- Auto-login on app start using `authStateChanges` stream
- Full user profile: name, phone, email, profile photo (Base64)

#### 🗺️ Interactive Map
- Map powered by **flutter_map** + **OpenStreetMap** tiles
- Real-time GPS location via **geolocator**
- Clickable markers with material pop-up details
- Color-coded markers: green for own listings

#### 📦 Material Exchange
- Post materials with title, description, quantity, category, and contact
- Upload photos via **image_picker**
- Edit and delete own listings
- Real-time updates via **Cloud Firestore** streams

#### 🏆 Achievement System (Gamification)
- Progress bar with 4 levels based on completed exchanges:
  - 🌱 **New** (0–5 exchanges)
  - 🥉 **Advanced** (5–10 exchanges)
  - 🥈 **Expert** (10–20 exchanges)
  - 🥇 **Master** (20+ exchanges)

#### 🔔 Notifications
- In-app notifications stored in Firestore (`notificaciones` collection)
- Mark as read, view history

#### 🛡️ Admin Panel
- Create, view, update and delete users
- Manage all listings on the platform
- Reputation and exchange tracking per user

### 📦 Dependencies (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: latest
  firebase_auth: latest
  cloud_firestore: latest
  flutter_map: latest
  latlong2: latest
  geolocator: latest
  image_picker: latest
  permission_handler: latest
```

### ⚙️ Requirements

- Flutter SDK `>=3.0.0`
- Dart SDK `>=3.0.0`
- Firebase project with **Authentication** and **Firestore** enabled
- `firebase_options.dart` generated via `flutterfire configure`
- Android: `minSdkVersion 21` | iOS: `iOS 12+`

### 🚀 Setup & Run

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/EcoFlow.git
cd EcoFlow/app

# 2. Install Flutter dependencies
flutter pub get

# 3. Connect your Firebase project
# Make sure firebase_options.dart exists in lib/
# If not, run:
flutterfire configure

# 4. Run the app
flutter run
```

> ⚠️ You need a `firebase_options.dart` file connected to your own Firebase project.  
> The one used in development is excluded from this repo for security reasons.

### 🏗️ Architecture Overview

```
main.dart
│
├── MyApp               ← Root widget, listens to auth state
├── LoginPage           ← Email/password authentication
├── RegisterPage        ← New user registration
├── HomePage            ← Main map + marker display
│   ├── MapView         ← flutter_map integration
│   ├── MarkerPopup     ← Material detail pop-up
│   └── AddListingPage  ← Create/edit material listing
│
├── ProfilePage         ← User info + achievement progress bar
├── NotificationsPage   ← In-app notification center
│
└── AdminPanel          ← (Admin role only)
    ├── CreateUserPage
    ├── ViewUsersPage
    ├── UpdateUserPage
    └── DeleteUserPage
```

### 🔐 Firestore Collections

| Collection | Description |
|---|---|
| `usuarios` | User profiles: name, email, phone, role, reputation, photo |
| `publicaciones` | Material listings: title, description, location, contact |
| `notificaciones` | In-app notifications per user |

© 2025 EcoFlow. All rights reserved.

---

## 🇲🇽 Español

> Aplicación móvil multiplataforma desarrollada con Flutter y Firebase, con mapa interactivo, autenticación de usuarios, publicaciones de intercambio de materiales y un sistema gamificado de logros.

### 🛠️ Stack Tecnológico

![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)
![Dart](https://img.shields.io/badge/Dart-0175C2?style=for-the-badge&logo=dart&logoColor=white)
![Firebase](https://img.shields.io/badge/Firebase-FFCA28?style=for-the-badge&logo=firebase&logoColor=black)
![Firestore](https://img.shields.io/badge/Firestore-FF6F00?style=for-the-badge&logo=firebase&logoColor=white)
![OpenStreetMap](https://img.shields.io/badge/OpenStreetMap-7EBC6F?style=for-the-badge&logo=openstreetmap&logoColor=white)

### ✨ Funcionalidades

#### 👤 Autenticación
- Inicio de sesión con correo y contraseña mediante **Firebase Auth**
- Auto-inicio de sesión al abrir la app con el stream `authStateChanges`
- Perfil completo: nombre, teléfono, correo y foto de perfil (Base64)

#### 🗺️ Mapa Interactivo
- Mapa con **flutter_map** y tiles de **OpenStreetMap**
- Ubicación en tiempo real mediante **geolocator**
- Marcadores clicables con detalles del material en ventana emergente
- Marcadores diferenciados: verde para las publicaciones propias del usuario

#### 📦 Intercambio de Materiales
- Publicar materiales con título, descripción, cantidad, categoría y contacto
- Subir fotos desde la galería o cámara con **image_picker**
- Editar y eliminar publicaciones propias
- Actualizaciones en tiempo real mediante streams de **Cloud Firestore**

#### 🏆 Sistema de Logros (Gamificación)
- Barra de progreso con 4 niveles basados en intercambios completados:
  - 🌱 **Nuevo** (0–5 intercambios)
  - 🥉 **Avanzado** (5–10 intercambios)
  - 🥈 **Experto** (10–20 intercambios)
  - 🥇 **Maestro** (20+ intercambios)

#### 🔔 Notificaciones
- Notificaciones dentro de la app almacenadas en Firestore (colección `notificaciones`)
- Marcar como leídas y ver el historial

#### 🛡️ Panel de Administración
- Crear, ver, actualizar y eliminar usuarios
- Gestionar todas las publicaciones de la plataforma
- Seguimiento de reputación e intercambios por usuario

### 📦 Dependencias (`pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter
  firebase_core: latest
  firebase_auth: latest
  cloud_firestore: latest
  flutter_map: latest
  latlong2: latest
  geolocator: latest
  image_picker: latest
  permission_handler: latest
```

### ⚙️ Requisitos

- Flutter SDK `>=3.0.0`
- Dart SDK `>=3.0.0`
- Proyecto de Firebase con **Authentication** y **Firestore** habilitados
- `firebase_options.dart` generado con `flutterfire configure`
- Android: `minSdkVersion 21` | iOS: `iOS 12+`

### 🚀 Instalación y Ejecución

```bash
# 1. Clonar el repositorio
git clone https://github.com/TU_USUARIO/EcoFlow.git
cd EcoFlow/app

# 2. Instalar dependencias de Flutter
flutter pub get

# 3. Conectar tu proyecto de Firebase
# Asegúrate de que firebase_options.dart exista en lib/
# Si no existe, ejecuta:
flutterfire configure

# 4. Ejecutar la app
flutter run
```

> ⚠️ Necesitas un archivo `firebase_options.dart` conectado a tu propio proyecto de Firebase.  
> El utilizado en desarrollo está excluido del repositorio por razones de seguridad.

### 🏗️ Arquitectura General

```
main.dart
│
├── MyApp               ← Widget raíz, escucha el estado de autenticación
├── LoginPage           ← Autenticación con correo y contraseña
├── RegisterPage        ← Registro de nuevos usuarios
├── HomePage            ← Mapa principal + visualización de marcadores
│   ├── MapView         ← Integración de flutter_map
│   ├── MarkerPopup     ← Ventana emergente con detalles del material
│   └── AddListingPage  ← Crear/editar publicación de material
│
├── ProfilePage         ← Información del usuario + barra de progreso de logros
├── NotificationsPage   ← Centro de notificaciones dentro de la app
│
└── AdminPanel          ← (Solo para rol Administrador)
    ├── CrearUsuarioPage
    ├── VerUsuariosPage
    ├── ActualizarUsuarioPage
    └── BorrarUsuarioPage
```

### 🔐 Colecciones en Firestore

| Colección | Descripción |
|---|---|
| `usuarios` | Perfiles de usuario: nombre, correo, teléfono, rol, reputación, foto |
| `publicaciones` | Publicaciones de materiales: título, descripción, ubicación, contacto |
| `notificaciones` | Notificaciones dentro de la app por usuario |

© 2025 EcoFlow. Todos los derechos reservados.
