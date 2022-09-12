from pydantic import BaseModel
from typing import Optional

class ImageBase(BaseModel):
    name: str
    classification: Optional[str]
    url: Optional[str]
    owner: str
    description: Optional[str]
    
class ImageCreate(ImageBase):
    pass

class Image(ImageBase):
    id: int

    class Config:
        orm_mode = True

