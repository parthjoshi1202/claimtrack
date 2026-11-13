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

## AWS ECS Deployment & Infrastructure Troubleshooting Notes

### 1. Terraform State & Execution Plan Integrity
- **Plan File Lock (`-out=tfplan`):** Running `terraform apply` without passing `-var image_tag=v3` defaults to base variable definitions, resulting in a no-op apply where no ECS task updates occur.
- **CI/CD Alignment:** Always run `terraform plan -var image_tag=v3 -out=tfplan` followed directly by `terraform apply tfplan`. This guarantees that the exact execution plan generated and reviewed during `plan` is what gets applied, preventing drift and matching automated GitHub Actions workflow patterns.

### 2. Docker & ECR Authentication (WSL Integration)
- **Error:** `401 Unauthorized` during `docker push` accompanied by `error saving credentials ... The stub received bad data.`
- **Root Cause:** Docker Desktop's WSL credential helper (`desktop.exe`) attempted to write the ECR token to the Windows Credential Manager and failed, preventing Docker from storing valid authentication tokens.
- **Resolution:** Updated `~/.docker/config.json` to clear `"credsStore": ""`. This forces Docker to retain ECR tokens directly in session memory without calling the broken helper.

### 3. ECS Task Startup Runtime Fixes (`ModuleNotFoundError`)
- **Error:** ECS container crashed on startup with `ModuleNotFoundError: No module named 'models'` (or `database`).
- **Root Cause:** Running standard Uvicorn (`uvicorn app.main:app`) executes from the project root rather than within the `/app` subdirectory, breaking top-level relative imports that worked under `fastapi run`.
- **Resolution:**
  - Standardized all internal import statements across `app/*.py` using explicit package paths (e.g., `from app.database import Base`, `from app.models import ClaimModel`).
  - Added `pytest.ini` with `pythonpath = .` to align local test imports with Uvicorn container execution.
  - Switched startup command from `fastapi` CLI to `uvicorn` in the Dockerfile to eliminate missing dependency runtime crashes.

### 4. Database Driver Configuration
- **Resolution:** Standardized SQLAlchemy engine connection strings to use `postgresql+psycopg://` for compatibility with `psycopg` v3 drivers across both local Docker Compose and AWS Aurora Serverless v2 environments.



## Step 5.1: CI/CD authentication — blocked OIDC, scoped IAM users instead

### Issue hit
- Applying `aws_iam_openid_connect_provider` failed with `AccessDenied` (explicit deny in a service control policy).
- Cause: this AWS account type (AWS Settings "project") has an AWS-managed SCP, `DenyIAMRestrictedActions`, that denies `iam:*Provider*`, so no OIDC or SAML providers can be created.
- AWS's published RCP for project accounts (`DenyAnyoneOutsideMyOrgAndAWS`) also covers STS and would likely block GitHub's web-identity call too. Not tested, because removing it also requires activation.
- Editing either policy requires "activating advanced features", which is irreversible and permanently removes the account's **$20 hard spend limit**.

### Decision
- **Kept the $20 spend limit.** For a personal account on a fixed budget, a hard spending cap is worth more than keyless auth.
- **Documented the OIDC design** in `docs/oidc-design.tf.example` (provider, PR-only plan role, main-only deploy role). Moving to OIDC in an account that allows it means applying that file and changing the credentials step in the workflows.
- **Two least-privilege IAM users** in `infra/bootstrap/iam-ci.tf`:
  - `claimtrack-gha-plan` (pull requests): `ReadOnlyAccess`, plus read access to the whole state bucket and write/delete **only on `*.tflock`**, so a PR run can lock state but never overwrite it.
  - `claimtrack-gha-deploy` (manual deploy and nightly destroy): `PowerUserAccess`, plus IAM permissions limited to `claimtrack-*` roles in this account. `iam:PassRole` is in a separate statement restricted with `iam:PassedToService = ecs-tasks.amazonaws.com`.
- **Access keys created with the AWS CLI** (`aws iam create-access-key`), not Terraform's `aws_iam_access_key`, so secret keys never appear in `terraform.tfstate`.
- **Branch restriction moved from IAM to GitHub.** With OIDC, the trust policy's `sub` condition meant only `main` could deploy. With keys, AWS can't tell which branch is calling, so:
  - Deploy keys are **environment secrets** in the GitHub environment `aws-deploy`, which only the `main` branch can use.
  - Plan keys are repository secrets.
  - GitHub doesn't pass secrets to pull requests from forks.

### Risks accepted
- **Long-lived keys can leak.** Mitigations: environment-scoped secrets, rotation every 90 days (calendar reminder set), immediate `aws iam delete-access-key` if exposed, CloudTrail to trace where a key was used.
- **`PowerUserAccess` is broader than Terraform needs.** Production version: a custom policy generated from the actions CloudTrail records during one deploy and destroy cycle (IAM Access Analyzer policy generation).
- **Terraform state contains the database password** (from `random_password`), so read access to the state bucket effectively means access to the password. Production version: `manage_master_user_password` so RDS keeps the password in Secrets Manager and it never enters state.

### Bootstrap state re-import
- **What happened:** bootstrap uses local state, and that state file no longer recorded the bucket. `apply` tried to create it again and failed with `BucketAlreadyOwnedByYou`.
- **Fix:** backed up `terraform.tfstate`, then ran `terraform import` for all five resources (`aws_s3_bucket`, `versioning`, `server_side_encryption_configuration`, `public_access_block`, `bucket_policy`) until `terraform plan` showed `No changes`.
- **Lesson:** local state for bootstrap is a single point of failure. Next improvement: move bootstrap state into the S3 bucket itself.


```