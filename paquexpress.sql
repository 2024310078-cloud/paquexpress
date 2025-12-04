CREATE DATABASE IF NOT EXISTS paquexpress;
USE paquexpress;

CREATE TABLE agentes (
  id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL,
  email VARCHAR(100) NOT NULL UNIQUE,
  password_hash VARCHAR(255) NOT NULL,
  creado_en DATETIME DEFAULT CURRENT_TIMESTAMP
);

CREATE TABLE paquetes (
  id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  descripcion VARCHAR(255) NOT NULL,
  direccion VARCHAR(255) NOT NULL,
  latitud DECIMAL(10,8),
  longitud DECIMAL(11,8),
  estatus VARCHAR(20) DEFAULT 'pendiente',
  id_agente INT(11),
  foto_url VARCHAR(255),
  gps_lat DECIMAL(10,8),
  gps_lng DECIMAL(11,8),
  fecha_entrega DATETIME,
  CONSTRAINT fk_paquetes_agente
    FOREIGN KEY (id_agente) REFERENCES agentes(id)
);

CREATE TABLE auditoria_entregas (
  id INT(11) NOT NULL AUTO_INCREMENT PRIMARY KEY,
  id_paquete INT(11) NOT NULL,
  id_agente INT(11) NOT NULL,
  gps_lat DECIMAL(10,8),
  gps_lng DECIMAL(11,8),
  fecha_entrega DATETIME NOT NULL,
  ip VARCHAR(50),
  user_agent VARCHAR(255),
  CONSTRAINT fk_auditoria_paquete
    FOREIGN KEY (id_paquete) REFERENCES paquetes(id),
  CONSTRAINT fk_auditoria_agente
    FOREIGN KEY (id_agente) REFERENCES agentes(id)
);
