import pytest
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)

def test_health_returns_200():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}

def test_create_valid_claim_returns_201():
    payload = {
        "policy_number": "POL-101",
        "claim_type": "auto",
        "amount": 450.00
    }
    response = client.post("/claims", json=payload)
    assert response.status_code == 201
    data = response.json()
    assert data["policy_number"] == "POL-101"
    assert data["status"] == "submitted"
    assert "id" in data

def test_negative_amount_returns_422():
    payload = {
        "policy_number": "POL-102",
        "claim_type": "home",
        "amount": -100.00
    }
    response = client.post("/claims", json=payload)
    assert response.status_code == 422

def test_illegal_status_change_returns_400():
    # 1. Create a claim
    create_resp = client.post("/claims", json={
        "policy_number": "POL-103",
        "claim_type": "life",
        "amount": 1000.00
    })
    claim_id = create_resp.json()["id"]

    # 2. Try illegal status jump (submitted directly to approved)
    patch_resp = client.patch(f"/claims/{claim_id}/status", json={"status": "approved"})
    assert patch_resp.status_code == 400
    assert "Cannot change status" in patch_resp.json()["detail"]