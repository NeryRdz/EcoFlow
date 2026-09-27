CREATE DATABASE IF NOT EXISTS `pruebaxd`;
USE `pruebaxd`;

CREATE TABLE usuarios (
    iduser INT AUTO_INCREMENT PRIMARY KEY,
    correo_electronico VARCHAR(255) NOT NULL UNIQUE,
    nombre_completo VARCHAR(255) NOT NULL,
    telefono VARCHAR(15) NOT NULL,
    contrasena VARCHAR(255) NOT NULL
);

CREATE TABLE marcadores(
    idmarker INT AUTO_INCREMENT,
    nombreNegocio VARCHAR(50) NOT NULL,
    descripcionBreve VARCHAR(200) NOT NULL,
    materialesReciclables VARCHAR(200) NOT NULL,
    tipo VARCHAR(50) NOT NULL,
    x FLOAT(10) NOT NULL,
    y FLOAT(10) NOT NULL,
    usuarios_iduser INT NOT NULL,
    PRIMARY KEY (`idmarker`),
    INDEX `fk_marcadores_usuarios_idx` (`usuarios_iduser` ASC),
    CONSTRAINT `fk_marcadores_usuarios`
        FOREIGN KEY (`usuarios_iduser`)
        REFERENCES `usuarios` (`iduser`)
        ON DELETE CASCADE
        ON UPDATE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8;




-- correr estop
use pruebaxd;
ALTER TABLE usuarios ADD COLUMN rol ENUM('usuario', 'admin') DEFAULT 'usuario';

ALTER TABLE marcadores ADD COLUMN imagenNegocio VARCHAR(200) NULL;

-- Crear usuario admin por defecto
INSERT INTO usuarios (correo_electronico, nombre_completo, telefono, contrasena, rol) 
VALUES ('admin@gmail.com', 'Administrador Principal', '0000000000', 'admin123', 'admin');