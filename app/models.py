from sqlalchemy import Column, Integer, String, Float
from database import Base

class ClaimModel(Base):
    __tablename__ = "claims"

    id = Column(Integer, primary_key=True, index=True)
    policy_number = Column(String, nullable=False)
    claim_type = Column(String, nullable=False)
    amount = Column(Float, nullable=False)
    status = Column(String, nullable=False, default="submitted")