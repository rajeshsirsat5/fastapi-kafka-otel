import uuid
import random
from pydantic import BaseModel

SAMPLE_NAMES = [
    "Alice Johnson", "Bob Smith", "Carol White", "David Brown",
    "Emma Davis", "Frank Miller", "Grace Wilson", "Henry Moore",
    "Isabella Taylor", "James Anderson", "Karen Thomas", "Liam Jackson",
]


class User(BaseModel):
    id: str
    name: str

    @classmethod
    def generate_random(cls) -> "User":
        return cls(
            id=str(uuid.uuid4()),
            name=random.choice(SAMPLE_NAMES),
        )
