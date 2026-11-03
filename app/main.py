from typing import Literal
from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel, Field
from sqlalchemy.orm import Session

from database import engine, Base, get_db
from models import ClaimModel

# Create DB tables automatically on startup
Base.metadata.create_all(bind=engine)

app = FastAPI(title="ClaimTrack")

ALLOWED = {
    "submitted": ["in_review"],
    "in_review": ["approved", "rejected"],
    "approved": [],
    "rejected": [],
}

class ClaimIn(BaseModel):
    policy_number: str
    claim_type: Literal["auto", "home", "life"]
    amount: float = Field(gt=0)

class StatusChange(BaseModel):
    status: Literal["submitted", "in_review", "approved", "rejected"]

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/claims", status_code=201)
def create_claim(claim: ClaimIn, db: Session = Depends(get_db)):
    db_claim = ClaimModel(
        policy_number=claim.policy_number,
        claim_type=claim.claim_type,
        amount=claim.amount,
        status="submitted"
    )
    db.add(db_claim)
    db.commit()
    db.refresh(db_claim)
    return db_claim

@app.get("/claims/{claim_id}")
def get_claim(claim_id: int, db: Session = Depends(get_db)):
    claim = db.query(ClaimModel).filter(ClaimModel.id == claim_id).first()
    if not claim:
        raise HTTPException(status_code=404, detail="Claim not found")
    return claim

@app.patch("/claims/{claim_id}/status")
def change_status(claim_id: int, change: StatusChange, db: Session = Depends(get_db)):
    claim = db.query(ClaimModel).filter(ClaimModel.id == claim_id).first()
    if not claim:
        raise HTTPException(status_code=404, detail="Claim not found")

    if change.status not in ALLOWED[claim.status]:
        raise HTTPException(
            status_code=400, 
            detail=f"Cannot change status from {claim.status} to {change.status}"
        )

    claim.status = change.status
    db.commit()
    db.refresh(claim)
    return claim