from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes import auth, users, checkins, journals, tasks, chat, handbook, admin
from app.db.database import create_tables
from app.core.config import settings


@asynccontextmanager
async def lifespan(app: FastAPI):
    await create_tables()
    yield


app = FastAPI(
    title="Enigma API",
    description="Student Mental Health Support System API",
    version="1.0.0",
    lifespan=lifespan,
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.CORS_ORIGINS,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router,      prefix="/auth",     tags=["Auth"])
app.include_router(users.router,     prefix="/users",    tags=["Users"])
app.include_router(checkins.router,  prefix="/checkins", tags=["Check-ins"])
app.include_router(journals.router,  prefix="/journals", tags=["Journals"])
app.include_router(tasks.router,     prefix="/tasks",    tags=["Tasks"])
app.include_router(chat.router,      prefix="/chat",     tags=["AI Chat"])
app.include_router(handbook.router,  prefix="/handbook", tags=["Handbook"])
app.include_router(admin.router,     prefix="/admin",    tags=["Admin"])


@app.get("/", tags=["Health"])
async def root():
    return {"status": "ok", "message": "Enigma API is running"}
