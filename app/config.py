from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    # Kafka
    kafka_bootstrap_servers: str = "localhost:9092"

    # Logging
    log_level: str = "INFO"

    class Config:
        env_file = ".env"


settings = Settings()
