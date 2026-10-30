from typing import Literal
from fastapi import FastAPI, HTTPException
from pydantic import BaseModel, Field

app = FastAPI(title="ClaimTrack")

claims = {}      # id -> claim dict (temporary; Postgres comes later)
next_id = 1

ALLOWED = {
    "submitted": ["in_review"],
    "in_review": ["approved", "rejected"],
    "approved": [],
    "rejected": [],
}

class ClaimIn(BaseModel):
    policy_number: str
    claim_type: Literal["auto", "home", "life"]
    amount: float = Field(gt=0)   # Pydantic rejects 0 and negatives for you

class StatusChange(BaseModel):
    status: Literal["submitted", "in_review", "approved", "rejected"]

@app.get("/health")
def health():
    return {"status": "ok"}

@app.post("/claims", status_code=201)
def create_claim(claim: ClaimIn):
    # TODO: give it the next id, status "submitted", save it in `claims`, return it
    global next_id

    claim_data = {
         "id": next_id,
         "policy_number": claim.policy_number,
         "claim_type": claim.claim_type,
         "amount": claim.amount,
         "status": "submitted"
    }
    claims[next_id] = claim_data
    next_id += 1
    return claim_data
    # hint: you need `global next_id` to change it inside the function

@app.get("/claims/{claim_id}")
def get_claim(claim_id: int):
    # TODO: return the claim, or raise HTTPException(status_code=404, ...) if missing
    if claim_id not in claims:
            raise HTTPException(status_code=404, detail="Claim not found")
    return claims[claim_id]
    

@app.patch("/claims/{claim_id}/status")
def change_status(claim_id: int, change: StatusChange):
    # TODO: 404 if missing; 400 if change.status is not in ALLOWED[current status];
    if claim_id not in claims:
            raise HTTPException(status_code=404, detail="Item not found")

    current_status = claims[claim_id]["status"]
    
    if change.status not in ALLOWED[current_status]:
         raise HTTPException(status_code=400, detail=f"Cannot change status from {current_status} to {change.status}")
    #       otherwise update and return the claim
    
    claims[claim_id]["status"] = change.status 
    return claims[claim_id]