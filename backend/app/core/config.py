import os

class Settings:
    PROJECT_NAME: str = "DTAE API"
    VERSION: str = "0.5.0"

    # JWT Settings
    JWT_SECRET_KEY: str = os.getenv("JWT_SECRET_KEY", "dtae_secret_key_braillepad_2026_super_secure")
    ALGORITHM: str = "HS256"
    ACCESS_TOKEN_EXPIRE_DAYS: int = 30

    # PostgreSQL Database Settings
    PGHOST: str = os.getenv("PGHOST", "localhost")
    PGPORT: str = os.getenv("PGPORT", "5432")
    PGDATABASE: str = os.getenv("PGDATABASE", os.getenv("POSTGRES_DB", "dtae"))
    PGUSER: str = os.getenv("PGUSER", os.getenv("POSTGRES_USER", "dtae_database"))
    PGPASSWORD: str = os.getenv("PGPASSWORD", os.getenv("POSTGRES_PASSWORD", "Joao_e_seus_amigos"))

    # Upload Directory
    UPLOAD_DIR: str = os.getenv("UPLOAD_DIR", "/app/uploads")

settings = Settings()
