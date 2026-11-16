# Container Image Repository
resource "aws_ecr_repository" "app" {
  #checkov:skip=CKV_AWS_136:Uses free default AES-256 encryption to avoid $1/mo KMS CMK cost in dev.
  name                 = var.name
  image_tag_mutability = "IMMUTABLE"
  force_delete         = true # Dev environment enablement for easy destroy

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = {
    Name = "${var.name}-ecr"
  }
}

# Image Lifecycle Policy: Retain 3 newest images
resource "aws_ecr_lifecycle_policy" "app" {
  repository = aws_ecr_repository.app.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 3 images"
        selection = {
          tagStatus   = "any"
          countType   = "imageCountMoreThan"
          countNumber = 3
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}