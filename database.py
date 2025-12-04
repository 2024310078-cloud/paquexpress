import mysql.connector
from mysql.connector import Error

def get_connection():
    try:
        connection = mysql.connector.connect(
            host="localhost",
            user="root",
            password="",  # sin contraseña
            database="paquexpress"
        )
        return connection
    except Error as e:
        print(f"Error al conectar a MySQL: {e}")
        return None
