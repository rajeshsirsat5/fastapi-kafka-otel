"""
main.py — Pure application code. Zero OTel imports.

The opentelemetry-instrument agent wraps this process at startup and
automatically instruments FastAPI routes, logging, and outbound calls.
"""
import logging
from contextlib import asynccontextmanager

from fastapi import FastAPI, HTTPException

from app.logging_config import setup_logging
from app.models import User
from app.kafka_producer import publish_user, stop_producer

setup_logging()
logger = logging.getLogger(__name__)


@asynccontextmanager
async def lifespan(app: FastAPI):
    logger.info("Application starting up")
    yield
    logger.info("Application shutting down")
    await stop_producer()


app = FastAPI(
    title="FastAPI Kafka OTel Demo",
    version="1.0.0",
    lifespan=lifespan,
)


@app.get("/health")
async def health_check():
    return {"status": "ok"}


@app.post("/users/generate", response_model=User)
async def generate_user():
    """Generate a random User and publish it to Kafka topic 'random.users'."""
    logger.info("Received request to generate a random user")

    user = User.generate_random()
    logger.debug("Generated user: id=%s name=%s", user.id, user.name)

    success = await publish_user(user)
    if not success:
        logger.error("Failed to publish user %s to Kafka", user.id)
        raise HTTPException(status_code=500, detail="Failed to publish user to Kafka")

    logger.info("Successfully published user %s to Kafka", user.id)
    return user
