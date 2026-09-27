# 🌐 EcoFlow — Web Version | Versión Web

<div align="center">

[🇺🇸 English](#-english) &nbsp;|&nbsp; [🇲🇽 Español](#-español)

</div>

---

## 🇺🇸 English

> Interactive web platform built with HTML, CSS, JavaScript, Python (Flask) and MySQL, hosted on PythonAnywhere.

### 🛠️ Tech Stack

![HTML5](https://img.shields.io/badge/HTML5-E34F26?style=for-the-badge&logo=html5&logoColor=white)
![CSS3](https://img.shields.io/badge/CSS3-1572B6?style=for-the-badge&logo=css3&logoColor=white)
![JavaScript](https://img.shields.io/badge/JavaScript-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![Leaflet](https://img.shields.io/badge/Leaflet.js-199900?style=for-the-badge&logo=leaflet&logoColor=white)

### ✨ Features

- 🗺️ Interactive map powered by **OpenStreetMap + Leaflet.js**
- 📍 Custom markers showing material exchange points
- 🪟 Pop-up windows with material info and contact details
- 🔐 User registration and login system
- 🎨 Markers color-coded by logged-in user
- ✏️ Users can add, edit and delete their own listings
- 📚 FAQ and educational section about circular economy
- 📱 Fully responsive design (mobile-friendly)

### 📁 Project Structure

```
web/
├── index.html          ← Landing page
├── map.html            ← Interactive map
├── login.html          ← Login page
├── register.html       ← User registration
├── faq.html            ← Educational section
├── css/
│   └── styles.css
├── js/
│   └── map.js          ← Leaflet.js map logic
├── app.py              ← Flask backend
└── requirements.txt
```

### ⚙️ Requirements

```txt
flask
flask-mysqldb
flask-login
mysqlclient
```

> Hosted on **PythonAnywhere** (Beginner plan — free tier).  
> Database: **MySQL** included in the hosting plan.

### 🚀 Local Setup

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/EcoFlow.git
cd EcoFlow/web

# 2. Create a virtual environment
python -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate

# 3. Install dependencies
pip install -r requirements.txt

# 4. Configure your database in app.py
# Set your MySQL host, user, password and db name

# 5. Run the app
python app.py
```

### 🗺️ Map Setup

The map uses [Leaflet.js](https://leafletjs.com/) with tiles from OpenStreetMap. No API key required.

```javascript
// Basic map initialization example
const map = L.map('map').setView([21.8818, -102.2916], 13); // Aguascalientes
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);
```

### 📊 Sprint Plan (Scrum)

| Sprint | Goal | Status |
|---|---|---|
| Sprint 1 | Landing page + base map with Leaflet.js | ✅ Done |
| Sprint 2 | User registration & login + persistent markers | ✅ Done |
| Sprint 3 | Listing management + visual marker distinction | ✅ Done |
| Sprint 4 | Educational content + usability testing | ✅ Done |

© 2025 EcoFlow. All rights reserved.

---

## 🇲🇽 Español

> Plataforma web interactiva construida con HTML, CSS, JavaScript, Python (Flask) y MySQL, alojada en PythonAnywhere.

### 🛠️ Stack Tecnológico

![HTML5](https://img.shields.io/badge/HTML5-E34F26?style=for-the-badge&logo=html5&logoColor=white)
![CSS3](https://img.shields.io/badge/CSS3-1572B6?style=for-the-badge&logo=css3&logoColor=white)
![JavaScript](https://img.shields.io/badge/JavaScript-F7DF1E?style=for-the-badge&logo=javascript&logoColor=black)
![Python](https://img.shields.io/badge/Python-3776AB?style=for-the-badge&logo=python&logoColor=white)
![MySQL](https://img.shields.io/badge/MySQL-4479A1?style=for-the-badge&logo=mysql&logoColor=white)
![Leaflet](https://img.shields.io/badge/Leaflet.js-199900?style=for-the-badge&logo=leaflet&logoColor=white)

### ✨ Funcionalidades

- 🗺️ Mapa interactivo con **OpenStreetMap + Leaflet.js**
- 📍 Marcadores personalizados con puntos de intercambio de materiales
- 🪟 Ventanas emergentes con información del material y datos de contacto
- 🔐 Sistema de registro e inicio de sesión de usuarios
- 🎨 Marcadores diferenciados por color según el usuario activo
- ✏️ Los usuarios pueden agregar, editar y eliminar sus propias publicaciones
- 📚 Sección de preguntas frecuentes y contenido educativo sobre economía circular
- 📱 Diseño responsivo adaptado a dispositivos móviles

### 📁 Estructura del Proyecto

```
web/
├── index.html          ← Página de inicio (Landing page)
├── map.html            ← Mapa interactivo
├── login.html          ← Inicio de sesión
├── register.html       ← Registro de usuarios
├── faq.html            ← Sección educativa
├── css/
│   └── styles.css
├── js/
│   └── map.js          ← Lógica del mapa con Leaflet.js
├── app.py              ← Backend con Flask
└── requirements.txt
```

### ⚙️ Requisitos

```txt
flask
flask-mysqldb
flask-login
mysqlclient
```

> Alojado en **PythonAnywhere** (plan Principiante — capa gratuita).  
> Base de datos: **MySQL** incluida en el plan de hosting.

### 🚀 Instalación Local

```bash
# 1. Clonar el repositorio
git clone https://github.com/TU_USUARIO/EcoFlow.git
cd EcoFlow/web

# 2. Crear un entorno virtual
python -m venv venv
source venv/bin/activate  # En Windows: venv\Scripts\activate

# 3. Instalar dependencias
pip install -r requirements.txt

# 4. Configurar la base de datos en app.py
# Ingresa tu host, usuario, contraseña y nombre de base de datos MySQL

# 5. Ejecutar la aplicación
python app.py
```

### 🗺️ Configuración del Mapa

El mapa utiliza [Leaflet.js](https://leafletjs.com/) con tiles de OpenStreetMap. No se requiere ninguna API key.

```javascript
// Ejemplo básico de inicialización del mapa
const map = L.map('map').setView([21.8818, -102.2916], 13); // Aguascalientes
L.tileLayer('https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png').addTo(map);
```

### 📊 Plan de Sprints (Scrum)

| Sprint | Objetivo | Estado |
|---|---|---|
| Sprint 1 | Landing page + mapa base con Leaflet.js | ✅ Completado |
| Sprint 2 | Registro e inicio de sesión + marcadores persistentes | ✅ Completado |
| Sprint 3 | Gestión de publicaciones + distinción visual de marcadores | ✅ Completado |
| Sprint 4 | Contenido educativo + pruebas de usabilidad | ✅ Completado |

© 2025 EcoFlow. Todos los derechos reservados.
