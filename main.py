import os
from contextlib import asynccontextmanager
from dotenv import load_dotenv
from fastapi import FastAPI
from fastapi.staticfiles import StaticFiles
from fastapi.responses import FileResponse

load_dotenv()  # reads .env when present; no-op in Cloud Run where vars are injected

from database import init_db
from routers import auth as auth_router
from uvicorn.middleware.proxy_headers import ProxyHeadersMiddleware


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()
    yield


app = FastAPI(title="App01", lifespan=lifespan)

# Trust X-Forwarded-Proto from Cloud Run so request.url.scheme is https://
app.add_middleware(ProxyHeadersMiddleware, trusted_hosts="*")

# Routers
app.include_router(auth_router.router)

# Static files (SPA)
app.mount("/static", StaticFiles(directory="static"), name="static")


@app.get("/", include_in_schema=False)
async def root():
    return FileResponse("static/index.html")


if __name__ == "__main__":
    import uvicorn
    port = int(os.environ.get("PORT", 8080))
    uvicorn.run("main:app", host="0.0.0.0", port=port, reload=False)
