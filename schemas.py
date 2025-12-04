from datetime import datetime
from pydantic import BaseModel
from typing import Optional

class Agente(BaseModel):
    id: int
    nombre: str
    email: str

class AgenteCreate(BaseModel):
    nombre: str
    email: str
    password: str

class Agente(BaseModel):
    id: int
    nombre: str
    email: str

class AgenteCreate(BaseModel):
    nombre: str
    email: str
    password: str

class Paquete(BaseModel):
    id: int
    descripcion: str
    direccion: str
    latitud: Optional[float] = None
    longitud: Optional[float] = None
    estatus: str
    id_agente: Optional[int] = None
    foto_url: Optional[str] = None
    gps_lat: Optional[float] = None
    gps_lng: Optional[float] = None
    fecha_entrega: Optional[datetime] = None

class PaqueteCreate(BaseModel):
    descripcion: str
    direccion: str
    id_agente: int

class PaqueteEntrega(BaseModel):
    foto_url: str
    gps_lat: float
    gps_lng: float

class LoginRequest(BaseModel):
    email: str
    password: str

class LoginResponse(BaseModel):
    id: int
    nombre: str
    email: str

class Token(BaseModel):
    access_token: str
    token_type: str
    agente_id: int
    nombre: str
