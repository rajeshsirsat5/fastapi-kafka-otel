import json
import logging

from aiokafka import AIOKafkaProducer

from app.config import settings
from app.models import User

logger = logging.getLogger(__name__)

TOPIC = "random.users"

_producer: AIOKafkaProducer | None = None


async def get_producer() -> AIOKafkaProducer:
    global _producer
    if _producer is None:
        logger.info("Connecting to Kafka at %s", settings.kafka_bootstrap_servers)
        _producer = AIOKafkaProducer(
            bootstrap_servers=settings.kafka_bootstrap_servers,
            value_serializer=lambda v: json.dumps(v).encode("utf-8"),
        )
        await _producer.start()
        logger.info("Kafka producer started")
    return _producer


async def publish_user(user: User) -> bool:
    try:
        producer = await get_producer()
        await producer.send_and_wait(TOPIC, value=user.model_dump())
        logger.info("Published user %s to topic '%s'", user.id, TOPIC)
        return True
    except Exception as e:
        logger.exception("Error publishing to Kafka: %s", e)
        return False


async def stop_producer():
    global _producer
    if _producer:
        await _producer.stop()
        _producer = None
        logger.info("Kafka producer stopped")
