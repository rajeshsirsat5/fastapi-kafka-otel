"""
Standalone Kafka consumer.
Run with zero-code instrumentation:

    opentelemetry-instrument python -m app.kafka_consumer
"""
import asyncio
import json
import logging

from aiokafka import AIOKafkaConsumer

from app.config import settings
from app.logging_config import setup_logging

logger = logging.getLogger(__name__)

TOPIC = "random.users"
GROUP_ID = "user-consumer-group"


async def consume():
    logger.info("Starting Kafka consumer for topic '%s'", TOPIC)

    consumer = AIOKafkaConsumer(
        TOPIC,
        bootstrap_servers=settings.kafka_bootstrap_servers,
        group_id=GROUP_ID,
        value_deserializer=lambda v: json.loads(v.decode("utf-8")),
        auto_offset_reset="earliest",
    )

    await consumer.start()
    logger.info("Consumer started. Listening on topic '%s'...", TOPIC)

    try:
        async for message in consumer:
            user = message.value
            logger.info(
                "[CONSUMED] offset=%d user_id=%s user_name=%s",
                message.offset,
                user["id"],
                user["name"],
            )
    except asyncio.CancelledError:
        logger.info("Consumer cancelled")
    finally:
        await consumer.stop()
        logger.info("Consumer stopped")


if __name__ == "__main__":
    setup_logging()
    asyncio.run(consume())
