from argon2 import PasswordHasher
from datetime import datetime, timedelta
from jose import JWTError, jwt
from typing import Optional

ph = PasswordHasher()

SECRET_KEY = "tu_clave_super_secreta_cambiar_en_produccion"
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 30


def hash_password(password: str) -> str:
    return ph.hash(password)


def verify_password(plain_password: str, hashed_password: str) -> bool:
    try:
        ph.verify(hashed_password, plain_password)
        return True
    except Exception:
        return False


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None) -> str:
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)

    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    print("CREATE_TOKEN payload =", to_encode)
    print("CREATE_TOKEN jwt =", encoded_jwt)
    return encoded_jwt


def verify_token(token: str) -> Optional[dict]:
    """Verifica y decodifica un token JWT."""
    try:
        print("VERIFY_TOKEN: token recibido =", token)
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        print("VERIFY_TOKEN: payload decodificado =", payload)
        if payload.get("sub") is None:
            print("VERIFY_TOKEN: no tiene 'sub'")
            return None
        return payload
    except JWTError as e:
        print("VERIFY_TOKEN ERROR:", e)
        return None
