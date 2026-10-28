"""Ponto de entrada do backend DTAE: Arquitetura Modular FastAPI.
"""
import os
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from .core.config import settings
from .api import auth, health, scoring, turmas, alunos, atividades, sessoes, metricas

app = FastAPI(
    title=settings.PROJECT_NAME,
    version=settings.VERSION,
    description="API REST para a Plataforma DTAE de Apoio à Alfabetização em Braille",
)

# Configurar CORS Middleware
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Montar diretório estático de arquivos/uploads
os.makedirs(settings.UPLOAD_DIR, exist_ok=True)
app.mount("/static/uploads", StaticFiles(directory=settings.UPLOAD_DIR), name="uploads")

# Incluir Routers Modulares
app.include_router(auth.router)
app.include_router(health.router)
app.include_router(scoring.router)
app.include_router(turmas.router)
app.include_router(alunos.router)
app.include_router(atividades.router)
app.include_router(sessoes.router)
app.include_router(metricas.router)
