from fastapi import FastAPI, File, UploadFile, Response, HTTPException, status, Depends
from fastapi.middleware.cors import CORSMiddleware
from typing import Optional
from cryptography.x509 import load_pem_x509_certificate
from cryptography.hazmat.backends import default_backend
from datetime import datetime
from sqlalchemy.orm import Session
from libcloud.storage.types import Provider
from libcloud.storage.providers import get_driver
from . import crud, models, schemas
from .database import SessionLocal, engine
import uvicorn
import jwt
import requests
import os


app = FastAPI()

# CORS
origins = [

]

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # ["*"] durch "origins" ersetzten, wenn die richtigen origins oben definiert wurden
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# SQL DB
models.Base.metadata.create_all(bind=engine)

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# Certificate
PEMSTART = "-----BEGIN CERTIFICATE-----\n"
PEMEND = "\n-----END CERTIFICATE-----\n"

# Import environment variables 
ACCOUNT_NAME = os.getenv("STORAGE_ACCOUNT_NAME") # For AWS this is be the IAM Credential ID
ACCESS_KEY = os.getenv("STORAGE_ACCESS_KEY")
CONTAINER_NAME = os.getenv("STORAGE_CONTAINER")
PROVIDER = os.getenv("STORAGE_PROVIDER")
BACKEND_URL = os.getenv("BACKEND_URL")
AWS_REGION = os.getenv("AWS_REGION")
CUSTOM_VISION_KEY = os.getenv("CUSTOM_VISION_KEY")
CUSTOM_VISION_URL = os.getenv("CUSTOM_VISION_URL")

# Storage account config azure
if PROVIDER == "AZURE":
    cls = get_driver(Provider.AZURE_BLOBS)
    storage_driver = cls(key=ACCOUNT_NAME, secret=ACCESS_KEY)
else:
    cls = get_driver(Provider.S3)
    storage_driver = cls(key=ACCOUNT_NAME, secret=ACCESS_KEY, region=AWS_REGION)

storage_container = storage_driver.get_container(CONTAINER_NAME)


# Custom vision endpoint
if CUSTOM_VISION_URL != "":
    custom_vision_endpoint = CUSTOM_VISION_URL
    custom_vision_key = CUSTOM_VISION_KEY


def msal_validation(jwt_token):
    """Validate the Microsoft JWT Identifier Token
    returns "True" if the token is valid (not expired, valid, ...)
    returns "False" if the token expired or is simply not valid"""

    # https://docs.microsoft.com/en-us/azure/active-directory/develop/access-tokens#validating-tokens

    if jwt_token == None or jwt_token == "" or jwt_token == "null" or jwt_token == "None" or jwt_token == "Null":
        return "Kein Access Token"

    try:

        token_payload = jwt.decode(jwt_token, options={"verify_signature": False})
        token_header = jwt.get_unverified_header(jwt_token)
        # return token_header
    except Exception as e:
        return "Error Decoding JWT Token"

    # Obtain the Public Key List from Micrsoft - search for matching x5t or kid to get the correct x5c Public Key
    try:
        r = requests.get('https://login.microsoft.com/common/discovery/keys')
    except Exception as e:
        return "Could not get Microsoft Public Key List"

    microsoft_public_keys = r.json()
    public_key_found = False
    for key in microsoft_public_keys['keys']:
        if key['kid'] == token_header['kid']:
            microsoft_public_keys_cert = key['x5c'][0]
            public_key_found = True
    if public_key_found == False:
        return "Public Key Certificate (x5c) could not be found"

    # Wrap into Certificate Format
    try:
        cert_str = str.encode(PEMSTART + microsoft_public_keys_cert + PEMEND)
        cert_obj = load_pem_x509_certificate(cert_str, default_backend)
        public_key = cert_obj.public_key()
    except Exception as e:
        return "Building CERT Format failed"

    try:
        jwt.decode(jwt_token, public_key, algorithms=token_header['alg'], audience=token_payload['aud'],
                   options={"verify_exp": True})
        return "ValidToken"
    except Exception as e:
        return e


@app.get("/")
async def root():
    return {"message": "head to /docs#/ to see routes and test API"}


@app.get("/validate/{jwt_token}")
def validate(jwt_token: str):
    return_message = msal_validation(jwt_token=jwt_token)
    if return_message != "ValidToken":
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            # detail="Error: " + str(return_message) + " Bitte (neu) anmelden",
            detail="Nicht Autorisiert! Bitte (neu) anmelden",
            headers={"WWW-Authenticate": "Bearer"},
        )
    else:
        return "Authorized"


# File upload --> no sure if this is best way, could also create temp file on os before upload would save one db access
@app.post("/images", response_model=schemas.Image)
def upload_file(account_id: str, file: UploadFile = File(...), db: Session = Depends(get_db)):
    # this should be changed back to a normal increment once the Backend is deployed for good. Then Backend and db will always need to be in sync!
    timestamp = datetime.now().strftime("%m-%d-%Y_%H:%M:%S")
    # check if file is attached
    if not file.filename:
        raise HTTPException(status_code=400, detail="No file attached.")
    # initialise image instance 
    img = schemas.ImageCreate(name=file.filename, classification="", owner=account_id, url="", description="")
    # create db entry to generate unique id
    img = crud.create_image(db, image=img)
    # upload image blob to storage account
    img_info = storage_driver.upload_object_via_stream(iterator=file.file, container=storage_container, object_name=str(img.id))
    # get file object for identification, if custom vision endpoint is set
    img_category = ""
    if CUSTOM_VISION_URL != "":
        img_obj = storage_driver.get_object(container_name=CONTAINER_NAME, object_name=str(img.id))
        img_data = next(storage_driver.download_object_as_stream(img_obj))
        # analyse image using img data
        request = requests.post(custom_vision_endpoint, img_data,
                        headers={"Prediction-Key": custom_vision_key, "Content-Type": "application/octet-stream"})
        img_category = request.json()['predictions'][0]['tagName']
    # re-instance image with all info
    img = schemas.Image(id=img.id, name=img.name, classification=img_category, owner=img.owner, url=BACKEND_URL + "/images/" + str(img.id) + "/image", description="" )
    # update db entry
    img = crud.update_image(db, image=img)
    return img

# Get all images for one user
@app.get("/images")
def retrieve_all_files(account_id: str, db: Session = Depends(get_db)):
    response = crud.get_images(db, img_owner=account_id)
    return response


# File download
@app.get("/images/{file_id}/image")
def retrieve_file(file_id: int, db: Session = Depends(get_db)):
    # query db for image
    img_info = crud.get_image(db, img_id=file_id)
    # return 404 if image is not found
    if not img_info:
        raise HTTPException(status_code=404, detail="Item not found")
    # download and return image
    img_obj = storage_driver.get_object(container_name=CONTAINER_NAME, object_name=str(img_info.id))
    img = next(storage_driver.download_object_as_stream(img_obj))
    return Response(content=img, media_type="image/png")


# Get info of one image
@app.get("/images/{file_id}")
def retrieve_file_info(file_id: str, db: Session = Depends(get_db)):
    # query db for image
    img_info = crud.get_image(db, img_id=file_id)
    # return 404 if image is not found
    if not img_info:
        raise HTTPException(status_code=404, detail="Item not found")
    return img_info


# Update an inventory item
@app.put("/images/{file_id}")
def update_entry(file_id: str, new_image_info: schemas.Image, db: Session = Depends(get_db)):
    img_info = crud.get_image(db, img_id=file_id)
    # update values
    img = schemas.Image(id=img_info.id, name=new_image_info.name, classification=new_image_info.classification, owner=img_info.owner, url=img_info.url, description=new_image_info.description )
    # update db entry
    img_info = crud.update_image(db, image=img)
    return img_info

''' CURRENTLY NOT IMPLEMENTED IN FRONTEND
# Update image
@app.put("/images/{file_id}/image")
def update_image(file_id: str, file: UploadFile = File(...)):
    service.get_blob_client(container="images", blob=file_id).upload_blob(file.file, overwrite=True)
    return "Image was updated"
'''

# Delete an inventory item
@app.delete("/images/{file_id}")
def delete_entry(file_id: int, db: Session = Depends(get_db)):
    # Delete db entry
    crud.delete_image(db, img_id=file_id)
    img_obj = storage_driver.get_object(container_name=CONTAINER_NAME, object_name=str(file_id))
    storage_driver.delete_object(img_obj)
    return "item was deleted"

# For local execution
if __name__ == "__main__":
    uvicorn.run("main:app", host="127.0.0.1", port=8888, reload=True)