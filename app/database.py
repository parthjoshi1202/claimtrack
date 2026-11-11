import os
from sqlalchemy import create_engine
from sqlalchemy.orm import DeclarativeBase, sessionmaker

# Priority 1: Direct DATABASE_URL (used by local Docker Compose)
DATABASE_URL = os.getenv("DATABASE_URL")

# Priority 2: Injected ECS environment variables / Individual local overrides
if not DATABASE_URL:
    db_user = os.getenv("DB_USER") or os.getenv("POSTGRES_USER", "postgres")
    db_pass = os.getenv("DB_PASSWORD") or os.getenv("POSTGRES_PASSWORD", "postgres")
    db_host = os.getenv("DB_HOST") or os.getenv("POSTGRES_HOST", "localhost")
    db_port = os.getenv("DB_PORT") or os.getenv("POSTGRES_PORT", "5432")
    db_name = os.getenv("DB_NAME") or os.getenv("POSTGRES_DB", "claimtrack")

    # Uses psycopg3 driver (change to postgresql+asyncpg:// if using async SQLAlchemy)
    DATABASE_URL = (
        f"postgresql+psycopg://{db_user}:{db_pass}@{db_host}:{db_port}/{db_name}"
    )

engine = create_engine(DATABASE_URL)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)


class Base(DeclarativeBase):
    pass


def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()