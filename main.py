from fastapi import FastAPI, HTTPException, Depends, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from fastapi.security import HTTPBearer
from fastapi.staticfiles import StaticFiles
from starlette.requests import Request
from typing import List
from datetime import timedelta, datetime
from database import get_connection
from schemas import (
    Agente, Paquete, AgenteCreate,
    PaqueteCreate, PaqueteEntrega, LoginRequest, LoginResponse, Token
)
from utils import hash_password, verify_password, create_access_token, verify_token
import os

app = FastAPI()

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

security = HTTPBearer()

# Carpeta uploads
os.makedirs("uploads", exist_ok=True)

# Servir archivos estáticos
app.mount("/uploads", StaticFiles(directory="uploads"), name="uploads")

# =====================
# AUTENTICACIÓN
# =====================

@app.post("/login", response_model=Token)
def login(datos: LoginRequest):
    conn = get_connection()
    if not conn:
        raise HTTPException(status_code=500, detail="Error de conexión a la BD")

    cursor = conn.cursor(dictionary=True)
    cursor.execute(
        "SELECT id, nombre, email, password_hash FROM agentes WHERE email = %s",
        (datos.email,)
    )
    agente = cursor.fetchone()
    cursor.close()
    conn.close()

    if not agente or not verify_password(datos.password, agente["password_hash"]):
        raise HTTPException(status_code=401, detail="Email o contraseña incorrectos")

    access_token_expires = timedelta(minutes=30)
    access_token = create_access_token(
        data={"sub": str(agente["id"])},
        expires_delta=access_token_expires
    )

    return Token(
        access_token=access_token,
        token_type="bearer",
        agente_id=agente["id"],
        nombre=agente["nombre"]
    )

@app.get("/me")
def get_current_agente(request: Request):
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Token no proporcionado")

    token = auth_header.replace("Bearer ", "").strip()
    payload = verify_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Token inválido o expirado")

    agente_id_str = payload.get("sub")
    if not agente_id_str:
        raise HTTPException(status_code=401, detail="Token sin información de usuario")

    try:
        agente_id = int(agente_id_str)
    except ValueError:
        raise HTTPException(status_code=401, detail="Token con formato inválido")

    return {"agente_id": agente_id}

# =====================
# AGENTES
# =====================

@app.get("/agentes", response_model=List[Agente])
def get_agentes():
    conn = get_connection()
    if not conn:
        raise HTTPException(status_code=500, detail="Error de conexión a la BD")

    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT id, nombre, email FROM agentes")
    agentes = cursor.fetchall()
    cursor.close()
    conn.close()

    return [Agente(**agente) for agente in agentes]

@app.post("/agentes", response_model=Agente)
def create_agente(agente: AgenteCreate):
    conn = get_connection()
    if not conn:
        raise HTTPException(status_code=500, detail="Error de conexión a la BD")

    cursor = conn.cursor()

    hashed_password = hash_password(agente.password)

    cursor.execute(
        "INSERT INTO agentes (nombre, email, password_hash) VALUES (%s, %s, %s)",
        (agente.nombre, agente.email, hashed_password)
    )
    conn.commit()
    new_id = cursor.lastrowid
    cursor.close()
    conn.close()

    return Agente(id=new_id, nombre=agente.nombre, email=agente.email)

# =====================
# PAQUETES
# =====================

@app.get("/paquetes", response_model=List[Paquete])
def get_paquetes(request: Request):
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Token no proporcionado")

    token = auth_header.replace("Bearer ", "").strip()
    print("GET_PAQUETES header =", auth_header)
    print("GET_PAQUETES token limpio =", token)

    payload = verify_token(token)
    print("GET_PAQUETES payload =", payload)

    if not payload:
        raise HTTPException(status_code=401, detail="Token inválido o expirado")

    agente_id_str = payload.get("sub")
    if not agente_id_str:
        raise HTTPException(status_code=401, detail="Token sin información de usuario")

    try:
        agente_id = int(agente_id_str)
    except ValueError:
        raise HTTPException(status_code=401, detail="Token con formato inválido")

    conn = get_connection()
    if not conn:
        raise HTTPException(status_code=500, detail="Error de conexión a la BD")

    cursor = conn.cursor(dictionary=True)
    cursor.execute("SELECT * FROM paquetes WHERE id_agente = %s", (agente_id,))
    paquetes = cursor.fetchall()
    cursor.close()
    conn.close()

    return [Paquete(**paquete) for paquete in paquetes]

@app.get("/historial", response_model=List[Paquete])
def get_historial(
    request: Request,
    desde: str | None = None,
    hasta: str | None = None,
):
    auth_header = request.headers.get("Authorization")
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Token no proporcionado")

    token = auth_header.replace("Bearer ", "").strip()
    payload = verify_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Token inválido o expirado")

    agente_id_str = payload.get("sub")
    if not agente_id_str:
        raise HTTPException(status_code=401, detail="Token sin información de usuario")

    try:
        agente_id = int(agente_id_str)
    except ValueError:
        raise HTTPException(status_code=401, detail="Token con formato inválido")

    conn = get_connection()
    if not conn:
        raise HTTPException(status_code=500, detail="Error de conexión a la BD")

    cursor = conn.cursor(dictionary=True)

    query = """
        SELECT * FROM paquetes
        WHERE id_agente = %s
          AND estatus = 'entregado'
    """
    params: list = [agente_id]

    if desde:
        query += " AND fecha_entrega >= %s"
        params.append(desde + " 00:00:00")
    if hasta:
        query += " AND fecha_entrega <= %s"
        params.append(hasta + " 23:59:59")

    query += " ORDER BY fecha_entrega DESC"

    cursor.execute(query, tuple(params))
    rows = cursor.fetchall()
    cursor.close()
    conn.close()

    return [Paquete(**row) for row in rows]

@app.post("/paquetes", response_model=Paquete)
def create_paquete(paquete: PaqueteCreate):
    conn = get_connection()
    if not conn:
        raise HTTPException(status_code=500, detail="Error de conexión a la BD")

    cursor = conn.cursor()
    cursor.execute(
        """
        INSERT INTO paquetes (descripcion, direccion, id_agente)
        VALUES (%s, %s, %s)
        """,
        (paquete.descripcion, paquete.direccion, paquete.id_agente)
    )
    conn.commit()
    new_id = cursor.lastrowid
    cursor.close()
    conn.close()

    return Paquete(
        id=new_id,
        descripcion=paquete.descripcion,
        direccion=paquete.direccion,
        latitud=None,
        longitud=None,
        estatus="pendiente",
        id_agente=paquete.id_agente,
        foto_url=None,
        gps_lat=None,
        gps_lng=None,
        fecha_entrega=None,
    )

@app.put("/paquetes/{paquete_id}/entregar", response_model=Paquete)
async def entregar_paquete(
    paquete_id: int,
    gps_lat: float = Form(...),
    gps_lng: float = Form(...),
    foto: UploadFile = File(...),
    request: Request = None
):
    auth_header = request.headers.get("Authorization") if request else None
    if not auth_header or not auth_header.startswith("Bearer "):
        raise HTTPException(status_code=401, detail="Token no proporcionado")

    token = auth_header.replace("Bearer ", "").strip()
    payload = verify_token(token)
    if not payload:
        raise HTTPException(status_code=401, detail="Token inválido o expirado")

    agente_id_str = payload.get("sub")
    if not agente_id_str:
        raise HTTPException(status_code=401, detail="Token sin información de usuario")

    try:
        agente_id = int(agente_id_str)
    except ValueError:
        raise HTTPException(status_code=401, detail="Token con formato inválido")

    conn = get_connection()
    if not conn:
        raise HTTPException(status_code=500, detail="Error de conexión a la BD")

    try:
        cursor = conn.cursor(dictionary=True)

        cursor.execute("SELECT id_agente FROM paquetes WHERE id = %s", (paquete_id,))
        paquete = cursor.fetchone()
        if not paquete:
            cursor.close()
            conn.close()
            raise HTTPException(status_code=404, detail="Paquete no encontrado")

        if paquete["id_agente"] != agente_id:
            cursor.close()
            conn.close()
            raise HTTPException(status_code=403, detail="No puedes entregar este paquete")

        os.makedirs("uploads", exist_ok=True)
        filename = f"foto_{paquete_id}_{int(datetime.now().timestamp())}.jpg"
        filepath = f"uploads/{filename}"

        contents = await foto.read()
        with open(filepath, "wb") as f:
            f.write(contents)

        foto_url = f"http://10.127.57.108:8000/uploads/{filename}"

        cursor.execute(
            """
            UPDATE paquetes
            SET estatus = %s,
                foto_url = %s,
                gps_lat = %s,
                gps_lng = %s,
                fecha_entrega = NOW()
            WHERE id = %s
            """,
            ("entregado", foto_url, gps_lat, gps_lng, paquete_id)
        )
        conn.commit()

        if cursor.rowcount == 0:
            cursor.close()
            conn.close()
            raise HTTPException(status_code=404, detail="Paquete no encontrado")

        # Auditoría de entrega
        ip = request.client.host if request and request.client else None
        user_agent = request.headers.get("user-agent") if request else None

        cursor.execute(
            """
            INSERT INTO auditoria_entregas
              (id_paquete, id_agente, gps_lat, gps_lng, fecha_entrega, ip, user_agent)
            VALUES (%s, %s, %s, %s, NOW(), %s, %s)
            """,
            (paquete_id, agente_id, gps_lat, gps_lng, ip, user_agent)
        )
        conn.commit()

        cursor.execute("SELECT * FROM paquetes WHERE id = %s", (paquete_id,))
        row = cursor.fetchone()
        cursor.close()
        conn.close()

        return Paquete(**row)

    except HTTPException as e:
        conn.close()
        raise e
    except Exception as e:
        conn.close()
        raise HTTPException(status_code=500, detail=f"Error: {str(e)}")
