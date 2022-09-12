from sqlalchemy import create_engine
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker
import os
import time

while not os.getenv("DB_ENDPOINT"):
    print("waiting for database ... ")
    time.sleep(5)

DB_ENDPOINT = os.getenv("DB_ENDPOINT")
DB_USER = os.getenv("DB_USER")
DB_PASSWD = os.getenv("DB_PASSWD")
db_name = ""

if DB_ENDPOINT == "inventoriadb.mariadb.database.azure.com":
    db_name = "%40inventoriadb"
    

engine = create_engine(
    # "sqlite:///./sql_app.db" , connect_args={"check_same_thread": False}
    "mysql+pymysql://"+ DB_USER + db_name + ":"+ DB_PASSWD +"@" + DB_ENDPOINT + "/inventoriadb" 
)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()