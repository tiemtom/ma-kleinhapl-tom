from sqlalchemy import Boolean, Column, ForeignKey, Integer, String
from sqlalchemy.orm import relationship

from .database import Base


class Image(Base):
    __tablename__ = "images"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(50))
    classification = Column(String(50))
    url = Column(String(100))
    owner = Column(String(50))
    description = Column(String(200))

