"""
logging_config.py

Plain standard-library logging setup.
Zero OTel imports here — the opentelemetry-instrument agent will
automatically attach its LoggingHandler to the root logger at runtime
when OTEL_PYTHON_LOGGING_AUTO_INSTRUMENTATION_ENABLED=true is set.
"""

import logging
import logging.handlers
import os

from app.config import settings

LOG_FORMAT = "%(asctime)s | %(levelname)-8s | %(name)s:%(funcName)s:%(lineno)d - %(message)s"
DATE_FORMAT = "%Y-%m-%d %H:%M:%S"


def setup_logging() -> None:
    os.makedirs("logs", exist_ok=True)

    formatter = logging.Formatter(fmt=LOG_FORMAT, datefmt=DATE_FORMAT)

    console_handler = logging.StreamHandler()
    console_handler.setFormatter(formatter)

    file_handler = logging.handlers.RotatingFileHandler(
        filename="logs/app.log",
        maxBytes=10 * 1024 * 1024,
        backupCount=7,
        encoding="utf-8",
    )
    file_handler.setFormatter(formatter)

    root = logging.getLogger()
    root.setLevel(settings.log_level.upper())
    root.addHandler(console_handler)
    root.addHandler(file_handler)

    logging.getLogger("aiokafka").setLevel(logging.WARNING)
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("grpc").setLevel(logging.WARNING)
