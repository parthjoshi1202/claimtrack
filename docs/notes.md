### Technical Incident & Troubleshooting Log

#### Issue 1: Docker Credential Helper Failure in WSL 2 (`The stub received bad data.`)

* **Symptom / Error:** Running `aws ecr get-login-password | docker login ...` failed with `error saving credentials: error storing credentials - err: exit status 1, out: The stub received bad data.`
* **Root Cause:** WSL 2 attempted to pass the ECR authentication payload across the Windows boundary to Docker Desktop's default Windows Credential Manager helper (`docker-credential-desktop.exe`), which encountered a socket/serialization error.
* **Resolution:** Bypassed the Windows host credential store by modifying `~/.docker/config.json` in WSL 2 to remove `"credsStore": "desktop.exe"`, allowing Docker to store the temporary ECR authorization token locally in standard configuration format.

---

#### Issue 2: AWS CLI Session Expiration & Empty Password Pipe

* **Symptom / Error:** `aws ecr get-login-password` produced `AWS: [ERROR]: Credentials were refreshed, but the refreshed credentials are still expired` and passed an empty string to `docker login`.
* **Root Cause:** The active IAM Identity Center / SSO token or session keys in the shell environment expired during development.
* **Resolution:** Unset stale session environment variables (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`, `AWS_SESSION_TOKEN`) and re-authenticated via `aws sso login` to establish a fresh credentials context.

---

#### Issue 3: Docker Daemon Unreachable in WSL 2 Subsystem

* **Symptom / Error:** Running Docker commands inside the Ubuntu terminal returned `The command 'docker' could not be found` or failed to connect to the Docker daemon with `BrokenPipeError`.
* **Root Cause:** Docker Desktop was not running on the Windows host machine, preventing the WSL 2 socket endpoint from binding to the backend daemon.
* **Resolution:** Launched Docker Desktop on Windows and ensured **WSL Integration** was explicitly enabled for the Ubuntu distribution under *Settings $\rightarrow$ Resources $\rightarrow$ WSL Integration*.

---

#### Issue 4: ECR Dependency Lock on Initial Terraform Provisioning

* **Symptom / Error:** ECS Fargate tasks could not be provisioned via `terraform apply` because the container image declared in `aws_ecs_task_definition` (`:v1`) did not exist yet in ECR.
* **Root Cause:** Circular dependency where ECS needs the image to launch, but ECR needs to be provisioned first before the image can be pushed.
* **Resolution:** Used targeted Terraform provisioning (`terraform apply -target=module.service.aws_ecr_repository.app`) to deploy the ECR registry independently, built and pushed the ARM64 image, then ran the full `terraform apply`.

---

#### Summary of Key Verification Commands Used

```bash
# 1. Clear expired credentials and re-authenticate SSO
unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN AWS_CREDENTIAL_EXPIRATION
aws sso login --region us-east-2

# 2. Log in Docker to ECR using active AWS CLI identity
aws ecr get-login-password --region us-east-2 | docker login --username AWS --password-stdin 895280308319.dkr.ecr.us-east-2.amazonaws.com

# 3. Build & push cross-architecture ARM64 image from x86_64 WSL 2
docker buildx build --platform linux/arm64 -t $REPO:v1 --push .

# 4. Verify remote ECR image availability
aws ecr list-images --repository-name claimtrack-dev



## Deployment & Troubleshooting Notes

### Terraform State & Plan Integrity
- **Plan File Usage:** Running `terraform apply` without `-var image_tag=v...` causes Terraform to fall back to the default variable value in `variables.tf`, resulting in a no-op apply. 
- **CI/CD Best Practice:** Always run `terraform plan -var image_tag=<tag> -out=tfplan` followed by `terraform apply tfplan`. This guarantees that the exact execution plan reviewed during `plan` is what gets applied, matching how CI/CD pipelines (like GitHub Actions) execute deployments safely.

### ECS & Runtime Troubleshooting Summary
1. **WSL/Docker Desktop ECR Login Failure (`401 Unauthorized` on Push):**
   - *Symptom:* Docker build succeeded, but `docker push` failed with `401 Unauthorized` and `The stub received bad data.`
   - *Root Cause:* Docker Desktop's credential helper (`desktop.exe`) in WSL failed to store the ECR token in Windows Credential Manager.
   - *Fix:* Cleared `"credsStore": ""` in `~/.docker/config.json` to store authentication directly in memory for the active terminal session.

2. **ECS Task Runtime Crash (`ModuleNotFoundError`):**
   - *Symptom:* ECS tasks crashed on startup with `ModuleNotFoundError: No module named 'models'` (or `database`).
   - *Root Cause:* Uvicorn executes from the project root (`app.main:app`), unlike local execution via `fastapi run`, requiring explicit module package prefixes.
   - *Fix:* Standardized all internal imports in `app/*.py` using explicit package paths (e.g., `from app.database import Base`, `from app.models import ClaimModel`). Added `pytest.ini` with `pythonpath = .` so test imports mirror runtime execution.

3. **Database Driver Standardization:**
   - *Fix:* Updated SQLAlchemy database connection strings to use `postgresql+psycopg://` explicitly for `psycopg` (v3) compatibility.

```