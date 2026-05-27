import logging
import os
from urllib.parse import urlparse, parse_qs, urlencode, urlunparse
from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession, async_sessionmaker
from sqlalchemy.orm import DeclarativeBase

logger = logging.getLogger(__name__)

DATABASE_URL = os.environ["DATABASE_URL"]

# Neon Postgres uses postgresql+asyncpg scheme
if DATABASE_URL.startswith("postgresql://"):
    DATABASE_URL = DATABASE_URL.replace("postgresql://", "postgresql+asyncpg://", 1)
elif DATABASE_URL.startswith("postgres://"):
    DATABASE_URL = DATABASE_URL.replace("postgres://", "postgresql+asyncpg://", 1)

# asyncpg doesn't understand libpq-style query params (sslmode, channel_binding, etc.)
# Strip ALL query params from the URL and handle SSL explicitly via connect_args.
_parsed = urlparse(DATABASE_URL)
_params = parse_qs(_parsed.query)
_sslmode = (_params.get("sslmode", [None])[0])
DATABASE_URL = urlunparse(_parsed._replace(query=""))

_connect_args = {}
if _sslmode in ("require", "verify-ca", "verify-full") or _sslmode is None:
    # Neon always requires SSL; default to require when no sslmode is specified
    _connect_args["ssl"] = "require"
elif _sslmode == "disable":
    _connect_args["ssl"] = False

engine = create_async_engine(DATABASE_URL, echo=False, pool_pre_ping=True, connect_args=_connect_args)
AsyncSessionLocal = async_sessionmaker(engine, expire_on_commit=False, class_=AsyncSession)


class Base(DeclarativeBase):
    pass


async def get_db():
    async with AsyncSessionLocal() as session:
        yield session


async def init_db():
    """Create tables on startup if they don't exist."""
    from models import User  # noqa: F401 – ensures model is registered
    try:
        async with engine.begin() as conn:
            await conn.run_sync(Base.metadata.create_all)
        logger.info("Database tables verified/created.")
    except Exception as exc:
        logger.warning("Could not reach database on startup: %s", exc)
        logger.warning("The app will start, but DB-dependent routes will fail until connectivity is restored.")
