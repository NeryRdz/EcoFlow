from flask import Flask, render_template, request, url_for, redirect, session, jsonify, flash
from email_validator import validate_email, EmailNotValidError
import re
import os
from werkzeug.utils import secure_filename
import mysql.connector

app = Flask(__name__)

# Configuración de clave secreta para sesiones seguras
app.config['SECRET_KEY'] = '7110c8ae51a4b5af97be6534caef90e4bb9bdcb3380af008f90b23a5d1616bf319bc298105da20fe'

# Configuración de las imagenes
app.config['UPLOAD_FOLDER'] = 'static/uploads'
app.config['MAX_CONTENT_LENGTH'] = 16 * 1024 * 1024  # Max 16MB
ALLOWED_EXTENSIONS = {'png', 'jpg', 'jpeg', 'gif'}

# Verificar extensiones permitidas
def allowed_file(filename):
    if not filename or '.' not in filename:
        return False
    extension = filename.rsplit('.', 1)[1].lower()
    return extension in ALLOWED_EXTENSIONS

# Configuración de la base de datos MySQL
DB_CONFIG = {
    'host': 'localhost',
    'user': 'root',       # Cambia por tu usuario de MySQL
    'password': '',       # Cambia por tu contraseña
    'database': 'pruebaxd'
}

# Función para obtener una conexión a la base de datos
def obtener_conexion():
    return mysql.connector.connect(**DB_CONFIG)

# Decorador personalizado para verificar permisos de administrador
def admin_required(f):
    def decorated_function(*args, **kwargs):
        if not session.get('es_admin'):
            flash('Acceso denegado. Se requieren privilegios de administrador.', 'error')
            return redirect(url_for('login'))
        return f(*args, **kwargs)
    decorated_function.__name__ = f.__name__
    return decorated_function

#Para validar campos
def validarCorreo(correo):
    # Paso 1: Validación de formato básico con regex
    patron_basico = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$'
    
    if not re.match(patron_basico, correo):
        flash('Formato de correo electrónico inválido', 'error')
        return False
    
    # Paso 2: Validación específica para Gmail
    dominio = correo.lower().split('@')[1]
    dominios_permitidos = ['gmail.com']
    
    if dominio not in dominios_permitidos:
        flash('Solo se permiten correos de Gmail (ejemplo@gmail.com)', 'error')
        return False
    
    try:
        validate_email(correo, check_deliverability=True)
        return True
    except EmailNotValidError:
        flash('Ingresa un correo válido', 'error')
        return False
    #Paso 3:
def validarNombre(nombre):
    regex = r'^[A-Za-zÁÉÍÓÚáéíóúÑñ\s]+$'
    if re.match(regex, nombre):
        return True
    else:
        flash('Ingresa tu nombre sin caracteres especiales o numeros','error')
        return False

def validarTelefono(telefono):
    if telefono.isdigit() and len(telefono) == 10:
        return True
    else:
        flash('Ingresa un telefono valido de 10 digitos','error')
        return False

def validarContra(password):
    if len(password) >= 8:
        return True
    else:
        flash('Ingrese una contraseña con minimo 8 caracteres','error')
        return False

# Ruta principal - Página de inicio
@app.route('/')
def index():
    return render_template("index.html")

# Ruta para los modelos educativos
@app.route('/ModelosEducativos')
def modelos_educativos():
    return render_template('ModelosEducativos.html')

# Ruta para la sección educativa sobre economía circular
@app.route('/aprender_mas')
def aprender_mas():
    return render_template('aprender_mas.html')

# Ruta de registro de nuevos usuarios
@app.route("/registro", methods=["GET", "POST"])
def registro():
    if request.method == "POST":
        try:
            # Obtener datos del formulario
            correo = request.form.get("CorreoElectronico")
            nombre = request.form.get("NombreCompleto")
            telefono = request.form.get("Telefono")
            password = request.form.get("Contra")
            rol = 'usuario'  # Por defecto todos son usuarios normales

            # Conexión a la base de datos
            conexion = obtener_conexion()
            cursor = conexion.cursor()

            #Validacion
            if not validarCorreo(correo) or not validarNombre(nombre) or not validarTelefono(telefono) or not validarContra(password):
                return redirect(url_for('registro'))

            # Insertar nuevo usuario en la base de datos
            cursor.execute('INSERT INTO usuarios (correo_electronico, nombre_completo, telefono, contrasena, rol) VALUES (%s, %s, %s, %s, %s)',
                         (correo, nombre, telefono, password, rol))
            conexion.commit()

            flash('Registro exitoso. Ahora puedes iniciar sesión.', 'success')
            return redirect(url_for('login'))

        except Exception as ex:
            conexion.rollback()
            flash('Error en el registro: ' + str(ex), 'error')

        finally:
            # Cerrar conexión siempre
            cursor.close()
            conexion.close()

    return render_template("registro.html")

# Ruta de inicio de sesión
@app.route("/login", methods=["GET", "POST"])
def login():
    if request.method == "POST":
        try:
            # Obtener credenciales del formulario
            correo = request.form.get("CorreoElectronico")
            password = request.form.get("Contra")

            conexion = obtener_conexion()
            cursor = conexion.cursor(dictionary=True)

            # Buscar usuario en la base de datos
            cursor.execute('SELECT iduser, correo_electronico, nombre_completo, rol FROM usuarios WHERE correo_electronico=%s AND contrasena=%s',
                         (correo, password))
            usuario = cursor.fetchone()

            if usuario:
                # Configurar sesión de usuario
                session['usuario_id'] = usuario['iduser']
                session['correo'] = usuario['correo_electronico']
                session['nombre'] = usuario['nombre_completo']
                session['loggedIn'] = True
                session['es_admin'] = (usuario['rol'] == 'admin')

                # Redirigir según el rol
                if session['es_admin']:
                    flash('¡Bienvenido Administrador!', 'success')
                    return redirect(url_for('admin'))
                else:
                    flash('¡Inicio de sesión exitoso!', 'success')
                    return redirect(url_for('index'))
            else:
                flash('Credenciales incorrectas. Intenta nuevamente.', 'error')

        except Exception as ex:
            flash('Error en el inicio de sesión: ' + str(ex), 'error')

        finally:
            cursor.close()
            conexion.close()

    return render_template("login.html")

# Ruta para añadir ubicaciones/marcadores
@app.route('/anadirubicacion', methods=["GET", "POST"])
def anadirubicacion():
    # Verificar que el usuario esté logueado
    if not session.get('loggedIn'):
        flash('Debes iniciar sesión para añadir ubicaciones.', 'error')
        return redirect(url_for('login'))

    if request.method == "POST":
        try:
            # Obtener datos del formulario de ubicación
            NombreNegocio = request.form.get("NombreNegocio")
            imagen = request.files.get ("imagenNegocio")
            DescripcionBreve = request.form.get("DescripcionBreve")
            MaterialesReciclables = request.form.get("MaterialesReciclables")
            Tipo = request.form.get("Tipo")
            x = request.form.get("x")
            y = request.form.get("y")
            iduser = session['usuario_id']

            ## DEPURACIÓN SEGURA
            #print(f"=== DEPURACIÓN DE IMAGEN ===")
            #print(f"Objeto imagen: {imagen}")
            #if imagen and imagen.filename != '':
            #    print(f"Nombre archivo: {imagen.filename}")
            #    print(f"Tipo contenido: {imagen.content_type}")
            #    print(f"Allowed file: {allowed_file(imagen.filename)}")
            #
            #else:
            #    print("No se recibió objeto imagen o nombre vacío")
            #print("=============================")

            conexion = obtener_conexion()
            cursor = conexion.cursor()

            ruta_imagen = ""
            if imagen and imagen.filename != '' and allowed_file(imagen.filename):
                filename = secure_filename(imagen.filename)
                import uuid
                unique_filename = f"{uuid.uuid4().hex}_{filename}"

                # Ruta completa para guardar
                filepath = os.path.join(app.root_path, 'static', 'uploads', unique_filename)

                # Verificar que el directorio existe
                os.makedirs(os.path.dirname(filepath), exist_ok=True)

                # Guardar la imagen
                imagen.save(filepath)

                # Verificar que el archivo se guardó correctamente
                if os.path.exists(filepath):
                    file_size = os.path.getsize(filepath)
                    #print(f"✓ Imagen guardada en: {filepath}")
                    #print(f"✓ Tamaño real del archivo: {file_size} bytes")

                    if file_size > 0:
                        ruta_imagen = f"uploads/{unique_filename}"
                        #print(f"✓ Ruta en BD: {ruta_imagen}")
                    else:
                        #print("✗ Archivo guardado con 0 bytes - posible error")
                        ruta_imagen = ""
                else:
                    #print("✗ Error: Archivo no se guardo correctamente")
                    ruta_imagen = ""
            else:
                ruta_imagen = ""
                #print("No se procesó imagen por validación fallida")

            conexion = obtener_conexion()
            cursor = conexion.cursor()

            # Insertar nuevo marcador en la base de datos
            cursor.execute('INSERT INTO marcadores (nombreNegocio, descripcionBreve, materialesReciclables, tipo, x, y, usuarios_iduser, imagenNegocio) VALUES (%s, %s, %s, %s, %s, %s, %s, %s)',
                         (NombreNegocio, DescripcionBreve, MaterialesReciclables, Tipo, x, y, iduser, ruta_imagen))
            conexion.commit()

            flash('Ubicación añadida correctamente.', 'success')
            return redirect(url_for('index'))

        except Exception as ex:
            conexion.rollback()
            flash('Error al añadir ubicación: ' + str(ex), 'error')

        finally:
            cursor.close()
            conexion.close()

    return render_template("anadirubicacion.html")

# API para obtener todos los marcadores (usado por el mapa)
@app.route('/marcadores')
def marcadores():
    marcador = []
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)

    # Consulta para obtener todos los marcadores con información de usuario
    cursor.execute("""SELECT m.nombreNegocio, m.descripcionBreve, m.materialesReciclables, m.tipo, m.x, m.y, m.imagenNegocio,
                   u.correo_electronico, u.nombre_completo, u.telefono
                   FROM marcadores m
                   INNER JOIN usuarios u ON m.usuarios_iduser = u.iduser""")
    datos = cursor.fetchall()

    # Formatear datos para JSON
    for dato in datos:
        marcador.append({
            "nombre": dato['nombreNegocio'],
            "imagen": dato['imagenNegocio'],
            "desc": dato['descripcionBreve'],
            "materiales": dato['materialesReciclables'],
            "tipo": dato['tipo'],
            "x": dato['x'],
            "y": dato['y'],
            "correo": dato['correo_electronico'],
            "usuario": dato['nombre_completo'],
            "tel": dato['telefono']
        })

    cursor.close()
    conexion.close()
    return jsonify(marcador)

# Ruta para mostrar marcadores del usuario actual
@app.route('/MostrarMarcador')
def MostrarMarcador():
    # Verificar que el usuario esté logueado
    if not session.get('loggedIn'):
        flash('Debes iniciar sesión para ver tus marcadores.', 'error')
        return redirect(url_for('login'))

    iduser = session['usuario_id']
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)

    # Consulta para obtener marcadores del usuario actual
    cursor.execute("""SELECT  m.*, u.correo_electronico, u.nombre_completo, u.telefono
                   FROM usuarios u
                   INNER JOIN marcadores m ON u.iduser = m.usuarios_iduser
                   WHERE u.iduser = %s""", (iduser,))
    MarcadoresObtenidos = cursor.fetchall()

    cursor.close()
    conexion.close()
    return render_template("MostrarMarcador.html", MarcadoresObtenidos = MarcadoresObtenidos)

# Ruta para mostrar marcadores del usuario actual
@app.route('/TodosMarcadores')
def TodosMarcadores():
    # Verificar que el usuario esté logueado
    if not session.get('loggedIn'):
        flash('Debes iniciar sesión para ver tus marcadores.', 'error')
        return redirect(url_for('login'))
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)
    
    # Consulta para obtener marcadores del usuario actual
    cursor.execute("""SELECT  m.*, u.correo_electronico, u.nombre_completo, u.telefono
                   FROM usuarios u
                   INNER JOIN marcadores m ON u.iduser = m.usuarios_iduser
                  """)
    MarcadoresObtenidos = cursor.fetchall()

    cursor.close()
    conexion.close()
    return render_template("TodosMarcadores.html", MarcadoresObtenidos = MarcadoresObtenidos)

@app.route('/_ResultadoTodosMarcadores', methods=['POST'])
def _ResultadoTodosMarcadores():
    dato = request.json.get('buscar')
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)

    cursor.execute("""SELECT  m.*, u.correo_electronico, u.nombre_completo, u.telefono
                   FROM usuarios u
                   INNER JOIN marcadores m ON u.iduser = m.usuarios_iduser
                   WHERE m.nombreNegocio LIKE %s OR
                   u.nombre_completo LIKE %s OR
                   u.telefono LIKE %s
                   """, (f'%{dato}%',f'%{dato}%',f'%{dato}%'))
    resultadoMarcadores = cursor.fetchall()

    cursor.close()
    conexion.close()

    return render_template("_ResultadoTodosMarcadores.html", resultadoMarcadores=resultadoMarcadores)

# ==============================================
# RUTAS DE ADMINISTRADOR (PROTEGIDAS)
# ==============================================

# Panel principal de administración
@app.route("/admin")
@admin_required
def admin():
    return render_template("admin.html")

# Gestión de marcadores (vista de administrador)
@app.route("/tablaMarcadores")
@admin_required
def tablaMarcadores():
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)

    # Consulta para obtener todos los marcadores con información de usuario
    cursor.execute("SELECT m.*, u.nombre_completo, u.correo_electronico, u.iduser FROM marcadores m INNER JOIN usuarios u ON m.usuarios_iduser = u.iduser ORDER BY m.idmarker ASC")
    tablaMarcadores = cursor.fetchall()

    cursor.close()
    conexion.close()
    return render_template("tablaMarcadores.html", tablaMarcadores=tablaMarcadores)

# Ruta para ADMINISTRADOR
@app.route("/eliminar_marcador/<int:id>")
@admin_required
def eliminar_marcador(id):
    conexion = obtener_conexion()
    cursor = conexion.cursor()
    cursor.execute("DELETE FROM marcadores WHERE idmarker = %s", (id,))
    conexion.commit()
    cursor.close()
    conexion.close()
    flash('Marcador eliminado por administrador.', 'success')
    return redirect(url_for('tablaMarcadores'))  # Redirige a la tabla de admin

# Ruta para USUARIO NORMAL
@app.route("/eliminar_marcador_usuario/<int:id>")
def eliminar_marcador_usuario(id):
    if not session.get('loggedIn'):
        flash('Debes iniciar sesión para realizar esta acción.', 'error')
        return redirect(url_for('login'))

    iduser = session['usuario_id']

    conexion = obtener_conexion()
    cursor = conexion.cursor()

    # Verifica que el marcador pertenece al usuario actual
    cursor.execute("SELECT * FROM marcadores WHERE idmarker = %s AND usuarios_iduser = %s", (id, iduser))
    marcador = cursor.fetchone()

    if marcador:
        cursor.execute("DELETE FROM marcadores WHERE idmarker = %s", (id,))
        conexion.commit()
        flash('Marcador eliminado correctamente.', 'success')
    else:
        flash('No tienes permiso para eliminar este marcador.', 'error')

    cursor.close()
    conexion.close()
    return redirect(url_for('MostrarMarcador'))



# Editar marcador existente
@app.route("/editar_marcador/<int:id>", methods=["GET", "POST"])
@admin_required
def editar_marcador(id):
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)

    if request.method == "POST":
        # Obtener datos actualizados del formulario
        nombre = request.form.get("nombreNegocio")
        imagen = request.files.get('imagenNegocio')
        desc = request.form.get("desc")
        materiales = request.form.get("materiales")
        tipo = request.form.get("tipo")

        ruta_imagen = ""
        if imagen and imagen.filename != '' and allowed_file(imagen.filename):
            filename = secure_filename(imagen.filename)
            import uuid
            unique_filename = f"{uuid.uuid4().hex}_{filename}"

            # Ruta completa para guardar
            filepath = os.path.join(app.root_path, 'static', 'uploads', unique_filename)

            # Verificar que el directorio existe
            os.makedirs(os.path.dirname(filepath), exist_ok=True)

            # Guardar la imagen
            imagen.save(filepath)

            # Verificar que el archivo se guardó correctamente
            if os.path.exists(filepath):
                file_size = os.path.getsize(filepath)
                #print(f"✓ Imagen guardada en: {filepath}")
                #print(f"✓ Tamaño real del archivo: {file_size} bytes")

                if file_size > 0:
                    ruta_imagen = f"uploads/{unique_filename}"
                    #print(f"✓ Ruta en BD: {ruta_imagen}")
                else:
                    #print("✗ Archivo guardado con 0 bytes - posible error")
                    ruta_imagen = ""
            else:
                #print("✗ Error: Archivo no se guardó correctamente")
                ruta_imagen = ""
        else:
            ruta_imagen = ""
            #print("No se procesó imagen por validación fallida")

        # Actualizar marcador en la base de datos
        cursor.execute("""
            UPDATE marcadores SET nombreNegocio=%s, descripcionBreve=%s, materialesReciclables=%s, tipo=%s, imagenNegocio=%s WHERE idmarker=%s
        """, (nombre, desc, materiales, tipo, ruta_imagen, id))
        conexion.commit()

        cursor.close()
        conexion.close()
        flash('Marcador actualizado correctamente.', 'success')
        return redirect(url_for('tablaMarcadores'))

    # Obtener datos actuales del marcador para el formulario
    cursor.execute("SELECT * FROM marcadores WHERE idmarker = %s", (id,))
    marcador = cursor.fetchone()

    cursor.close()
    conexion.close()
    return render_template("editar_Marcador.html", marcador=marcador)

# Editar marcador existente (Usuario)
@app.route("/editar_marcador_usuario/<int:id>", methods=["GET", "POST"])
def editar_marcador_usuario(id):
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)

    if request.method == "POST":
        # Obtener datos actualizados del formulario
        nombre = request.form.get("nombreNegocio")
        imagen = request.files.get('imagenNegocio')
        desc = request.form.get("desc")
        materiales = request.form.get("materiales")
        tipo = request.form.get("tipo")

        ruta_imagen = ""
        if imagen and imagen.filename != '' and allowed_file(imagen.filename):
            filename = secure_filename(imagen.filename)
            import uuid
            unique_filename = f"{uuid.uuid4().hex}_{filename}"

            # Ruta completa para guardar
            filepath = os.path.join(app.root_path, 'static', 'uploads', unique_filename)

            # Verificar que el directorio existe
            os.makedirs(os.path.dirname(filepath), exist_ok=True)

            # Guardar la imagen
            imagen.save(filepath)

            # Verificar que el archivo se guardó correctamente
            if os.path.exists(filepath):
                file_size = os.path.getsize(filepath)
               # print(f"✓ Imagen guardada en: {filepath}")
               # print(f"✓ Tamaño real del archivo: {file_size} bytes")

                if file_size > 0:
                    ruta_imagen = f"uploads/{unique_filename}"
                    #print(f"✓ Ruta en BD: {ruta_imagen}")
                else:
                    #print("✗ Archivo guardado con 0 bytes - posible error")
                    ruta_imagen = ""
            else:
                #print("✗ Error: Archivo no se guardó correctamente")
                ruta_imagen = ""
        else:
            ruta_imagen = ""
            #print("No se procesó imagen por validación fallida")

        # Actualizar marcador en la base de datos
        cursor.execute("""
            UPDATE marcadores SET nombreNegocio=%s, descripcionBreve=%s, materialesReciclables=%s, tipo=%s, imagenNegocio=%s WHERE idmarker=%s
        """, (nombre, desc, materiales, tipo, ruta_imagen, id))
        conexion.commit()

        cursor.close()
        conexion.close()
        flash('Marcador actualizado correctamente.', 'success')
        return redirect(url_for('MostrarMarcador'))

    # Obtener datos actuales del marcador para el formulario
    cursor.execute("SELECT * FROM marcadores WHERE idmarker = %s", (id,))
    marcador = cursor.fetchone()

    cursor.close()
    conexion.close()
    return render_template("editar_Marcador.html", marcador=marcador)

# Gestión de usuarios (vista de administrador)
@app.route("/usuarios")
@admin_required
def usuarios():
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)

    # Consulta para obtener todos los usuarios
    cursor.execute("SELECT * FROM usuarios")
    usuarios = cursor.fetchall()

    cursor.close()
    conexion.close()
    return render_template("usuarios.html", usuarios=usuarios)

# NUEVA FUNCIÓN: Agregar usuario desde el panel de administración
@app.route("/agregar_usuario", methods=["POST"])
@admin_required
def agregar_usuario():
    if request.method == "POST":
        try:
            # Obtener datos del formulario de nuevo usuario
            correo = request.form.get("correo")
            nombre = request.form.get("nombre")
            telefono = request.form.get("telefono")
            contrasena = request.form.get("contrasena")
            rol = request.form.get("rol")

            conexion = obtener_conexion()
            cursor = conexion.cursor()

            #Validacion
            if not validarCorreo(correo) or not validarNombre(nombre) or not validarTelefono(telefono) or not validarContra(contrasena):
                return redirect(url_for('usuarios'))

            # Insertar nuevo usuario en la base de datos
            cursor.execute('INSERT INTO usuarios (correo_electronico, nombre_completo, telefono, contrasena, rol) VALUES (%s, %s, %s, %s, %s)',
                         (correo, nombre, telefono, contrasena, rol))
            conexion.commit()

            flash('Usuario agregado correctamente.', 'success')

        except Exception as ex:
            conexion.rollback()
            flash('Error al agregar usuario: ' + str(ex), 'error')

        finally:
            cursor.close()
            conexion.close()

    return redirect(url_for('usuarios'))

# Eliminar usuario (solo administradores)
@app.route("/eliminar_usuario/<int:id>")
@admin_required
def eliminar_usuario(id):
    conexion = obtener_conexion()
    cursor = conexion.cursor()

    # Eliminar usuario por ID
    cursor.execute("DELETE FROM usuarios WHERE iduser = %s", (id,))
    conexion.commit()

    cursor.close()
    conexion.close()
    flash('Usuario eliminado correctamente.', 'success')
    return redirect(url_for('usuarios'))

# Editar usuario existente
@app.route("/editar_usuario/<int:id>", methods=["GET", "POST"])
@admin_required
def editar_usuario(id):
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)

    if request.method == "POST":
        # Obtener datos actualizados del formulario
        correo = request.form.get("Correo")
        nombre = request.form.get("nombre")
        telefono = request.form.get("telefono")
        contrasena = request.form.get("Contrasena")
        rol = request.form.get("rol")

        #Validacion
        if not validarCorreo(correo) or not validarNombre(nombre) or not validarTelefono(telefono) or not validarContra(contrasena):
            return redirect(url_for('editar_usuario',id=id))

        # Actualizar usuario en la base de datos
        cursor.execute("""
            UPDATE usuarios SET correo_electronico=%s, nombre_completo=%s, telefono=%s, contrasena=%s, rol=%s WHERE iduser=%s
        """, (correo, nombre, telefono, contrasena, rol, id))
        conexion.commit()

        cursor.close()
        conexion.close()
        flash('Usuario actualizado correctamente.', 'success')
        return redirect(url_for('usuarios'))

    # Obtener datos actuales del usuario para el formulario
    cursor.execute("SELECT * FROM usuarios WHERE iduser = %s", (id,))
    usuario = cursor.fetchone()

    cursor.close()
    conexion.close()
    return render_template("editar_usuario.html", usuario=usuario)


@app.route('/BuscarMarcadores', methods=['POST'])
def BuscarMarcadores():
    dato = request.json.get('buscar')
    print(f"Buscando: {dato}")
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)

    cursor.execute("SELECT m.*, u.nombre_completo, u.correo_electronico, u.iduser FROM marcadores m INNER JOIN usuarios u ON m.usuarios_iduser = u.iduser WHERE m.nombreNegocio LIKE %s OR u.correo_electronico LIKE %s OR u.nombre_completo LIKE %s ORDER BY m.idmarker ASC",(f'%{dato}%',f'%{dato}%',f'%{dato}%'))
    resultadosMarcadores = cursor.fetchall()

    cursor.close()
    conexion.close()

    return render_template("_MarcadoresResultados.html", resultadosMarcadores=resultadosMarcadores)

@app.route('/BuscarUsuarios', methods=['POST'])
def BuscarUsuarios():
    dato = request.json.get('buscar')
    print(f"Buscando: {dato}")
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)

    cursor.execute("SELECT u.* FROM usuarios u WHERE u.correo_electronico LIKE %s OR u.nombre_completo LIKE %s OR u.telefono LIKE %s OR u.rol LIKE %s ORDER BY u.iduser ASC",(f'%{dato}%',f'%{dato}%',f'%{dato}%',f'%{dato}%'))
    resultadosUsuarios = cursor.fetchall()

    cursor.close()
    conexion.close()

    return render_template("_UsuariosResultados.html", resultadosUsuarios=resultadosUsuarios)

@app.route('/_MarcadorResultadoUsuario', methods=['POST'])
def _MarcadorResultadoUsuario():
    dato = request.json.get('buscar')
    print(f"Buscando: {dato}")
    conexion = obtener_conexion()
    cursor = conexion.cursor(dictionary=True)
    iduser = session['usuario_id']

    cursor.execute("""SELECT  m.*, u.correo_electronico, u.nombre_completo, u.telefono
                   FROM usuarios u
                   INNER JOIN marcadores m ON u.iduser = m.usuarios_iduser
                   WHERE u.iduser = %s AND
                   (m.nombreNegocio LIKE %s OR
                   u.nombre_completo LIKE %s OR
                   u.telefono LIKE %s)
                   """, (iduser,f'%{dato}%',f'%{dato}%',f'%{dato}%'))
    resultadoMarcadores = cursor.fetchall()

    cursor.close()
    conexion.close()

    return render_template("_MarcadorResultadoUsuario.html", resultadoMarcadores=resultadoMarcadores)

# ==============================================
# RUTAS GENERALES
# ==============================================

# Cerrar sesión
@app.route('/logout')
def logout():
    # Limpiar toda la sesión
    session.clear()
    flash('Sesión cerrada correctamente.', 'info')
    return redirect(url_for('index'))

# Punto de entrada de la aplicación
if __name__ == "__main__":
    debug_mode = os.getenv("FLASK_DEBUG", "0").lower() in ("1", "true", "yes", "on")
    app.run(debug=debug_mode)
