from sqlalchemy.orm import Session
from . import models, schemas

def create_image(db: Session, image: schemas.ImageCreate):
    db_image = models.Image(name = image.name, classification = image.classification, url = image.url, owner = image.owner, description = image.description)
    db.add(db_image)
    db.commit()
    db.refresh(db_image)
    return db_image

def update_image(db: Session, image: schemas.Image):
    db_image = db.query(models.Image).filter_by(id=image.id).first()
    db_image.name = image.name
    db_image.classification = image.classification
    db_image.url = image.url
    db_image.description = image.description
    db.commit()
    db.refresh(db_image)
    return db_image

# get all images for one user
def get_images(db: Session, img_owner: str):
    return db.query(models.Image).filter_by(owner=img_owner).all()

# get image by id
def get_image(db: Session, img_id: int):
    return db.query(models.Image).filter_by(id=img_id).first()

# delete image by id
def delete_image(db: Session, img_id: int):
    db_image = db.query(models.Image).filter_by(id=img_id).first()
    db.delete(db_image)
    db.commit()
    return None