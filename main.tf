# ============================================
# CAFÉ WEBSITE - S3 STATIC WEBSITE INFRASTRUCTURE
# ============================================

# ============================================
# SOURCE S3 BUCKET - Primary Region (us-east-1)
# ============================================

resource "aws_s3_bucket" "cafe_website_source" {
  bucket = var.source_bucket_name
}

resource "aws_s3_bucket_ownership_controls" "cafe_website_source_ownership" {
  bucket = aws_s3_bucket.cafe_website_source.id
  rule {
    object_ownership = "BucketOwnerPreferred"
  }
}

resource "aws_s3_bucket_public_access_block" "cafe_website_source_public_access" {
  bucket = aws_s3_bucket.cafe_website_source.id

  block_public_acls       = false
  block_public_policy     = false
  ignore_public_acls      = false
  restrict_public_buckets = false

  depends_on = [
    aws_s3_bucket_ownership_controls.cafe_website_source_ownership
  ]
}

resource "aws_s3_bucket_acl" "cafe_website_source_acl" {
  bucket = aws_s3_bucket.cafe_website_source.id
  acl    = "private"

  depends_on = [
    aws_s3_bucket_public_access_block.cafe_website_source_public_access,
    aws_s3_bucket_ownership_controls.cafe_website_source_ownership
  ]
}

resource "aws_s3_bucket_website_configuration" "cafe_website_hosting" {
  bucket = aws_s3_bucket.cafe_website_source.id

  index_document {
    suffix = "index.html"
  }

  error_document {
    key = "error.html"
  }
}

# ============================================
# WEBSITE CONTENT
# ============================================

resource "aws_s3_object" "cafe_website_index" {
  bucket       = aws_s3_bucket.cafe_website_source.id
  key          = "index.html"
  content_type = "text/html"

  content = <<-HTML
    <!DOCTYPE html>
    <html>
    <head>
        <title>Frank & Martha's Café</title>
        <style>
            body { font-family: Arial, sans-serif; margin: 0; padding: 20px; background-color: #f5f5f5; }
            .header { background-color: #8B4513; color: white; padding: 20px; text-align: center; border-radius: 10px; }
            .content { background-color: white; padding: 30px; margin-top: 20px; border-radius: 10px; box-shadow: 0 2px 5px rgba(0,0,0,0.1); }
            .info { background-color: #fff3cd; padding: 15px; border-radius: 5px; margin-top: 20px; }
            h1 { margin: 0; }
        </style>
    </head>
    <body>
        <div class="header">
            <h1>☕ Frank & Martha's Café</h1>
            <p>Delicious Desserts & Premium Coffee</p>
        </div>
        <div class="content">
            <h2>Welcome to Our Café!</h2>
            <p>We serve the finest desserts and coffee in the city.</p>
            <p>Visit us at our single location in the heart of the city.</p>
            <div class="info">
                <h3>📍 Location</h3>
                <p>123 Main Street, City Center</p>
                <h3>🕐 Business Hours</h3>
                <p>Monday - Friday: 7:00 AM - 8:00 PM</p>
                <p>Saturday - Sunday: 8:00 AM - 6:00 PM</p>
                <h3>📞 Contact</h3>
                <p>Phone: (555) 123-4567</p>
                <h3>🍰 Our Specialties</h3>
                <ul>
                    <li>Fresh Pastries</li>
                    <li>Gourmet Coffee</li>
                    <li>Homemade Desserts</li>
                    <li>Seasonal Specials</li>
                </ul>
            </div>
        </div>
    </body>
    </html>
  HTML

  depends_on = [
    aws_s3_bucket_website_configuration.cafe_website_hosting
  ]
}

resource "aws_s3_object" "cafe_website_error" {
  bucket       = aws_s3_bucket.cafe_website_source.id
  key          = "error.html"
  content_type = "text/html"

  content = <<-HTML
    <!DOCTYPE html>
    <html>
    <head>
        <title>Page Not Found - Frank & Martha's Café</title>
        <style>
            body { font-family: Arial, sans-serif; text-align: center; padding: 50px; }
            h1 { color: #8B4513; }
        </style>
    </head>
    <body>
        <h1>☕ Oops! Page Not Found</h1>
        <p>Sorry, the page you're looking for doesn't exist.</p>
        <p><a href="/">Return to Homepage</a></p>
    </body>
    </html>
  HTML
}

# ============================================
# BUCKET POLICY - Public Read Access
# ============================================

data "aws_iam_policy_document" "cafe_website_public_read_policy" {
  statement {
    sid    = "PublicReadGetObject"
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = [
      "s3:GetObject"
    ]
    resources = [
      "${aws_s3_bucket.cafe_website_source.arn}/*"
    ]
  }

  statement {
    sid    = "PublicReadListBucket"
    effect = "Allow"
    principals {
      type        = "*"
      identifiers = ["*"]
    }
    actions = [
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.cafe_website_source.arn
    ]
  }
}

resource "aws_s3_bucket_policy" "cafe_website_public_read_policy" {
  bucket = aws_s3_bucket.cafe_website_source.id
  policy = data.aws_iam_policy_document.cafe_website_public_read_policy.json

  depends_on = [
    aws_s3_bucket_public_access_block.cafe_website_source_public_access
  ]
}

# ============================================
# VERSIONING - Data Protection
# ============================================

resource "aws_s3_bucket_versioning" "cafe_website_source_versioning" {
  bucket = aws_s3_bucket.cafe_website_source.id
  versioning_configuration {
    status = "Enabled"
  }
}

# ============================================
# LIFECYCLE POLICIES - Cost Optimization
# ============================================

resource "aws_s3_bucket_lifecycle_configuration" "cafe_website_ia_transition" {
  bucket = aws_s3_bucket.cafe_website_source.id

  rule {
    id     = "move-previous-versions-to-ia-after-30-days"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_transition {
      days          = 30
      storage_class = "STANDARD_IA"
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.cafe_website_source_versioning
  ]
}

resource "aws_s3_bucket_lifecycle_configuration" "cafe_website_expiry" {
  bucket = aws_s3_bucket.cafe_website_source.id

  rule {
    id     = "delete-old-versions-after-365-days"
    status = "Enabled"

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      days = 365
    }
  }

  depends_on = [
    aws_s3_bucket_lifecycle_configuration.cafe_website_ia_transition
  ]
}

# ============================================
# CROSS-REGION REPLICATION - Disaster Recovery
# ============================================

resource "aws_s3_bucket" "cafe_website_destination" {
  provider = aws.secondary
  bucket   = var.destination_bucket_name
}

resource "aws_s3_bucket_versioning" "cafe_website_destination_versioning" {
  provider = aws.secondary
  bucket   = aws_s3_bucket.cafe_website_destination.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_iam_role" "cafe_website_replication_role" {
  name = "CafeRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "s3.amazonaws.com"
        }
      }
    ]
  })
}

resource "aws_iam_policy" "cafe_website_replication_policy" {
  name = "CafeReplicationPolicy"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:ReplicateObject",
          "s3:ReplicateDelete",
          "s3:ReplicateTags",
          "s3:GetObject",
          "s3:GetObjectVersion",
          "s3:GetObjectVersionTagging"
        ]
        Resource = [
          aws_s3_bucket.cafe_website_source.arn,
          "${aws_s3_bucket.cafe_website_source.arn}/*",
          aws_s3_bucket.cafe_website_destination.arn,
          "${aws_s3_bucket.cafe_website_destination.arn}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "cafe_website_replication_policy_attachment" {
  role       = aws_iam_role.cafe_website_replication_role.name
  policy_arn = aws_iam_policy.cafe_website_replication_policy.arn
}

resource "aws_s3_bucket_replication_configuration" "cafe_website_replication" {
  bucket = aws_s3_bucket.cafe_website_source.id
  role   = aws_iam_role.cafe_website_replication_role.arn

  rule {
    id       = "replicate-entire-bucket-to-dr"
    status   = "Enabled"
    priority = 1

    filter {
      prefix = ""
    }

    destination {
      bucket        = aws_s3_bucket.cafe_website_destination.arn
      storage_class = "STANDARD"
    }

    delete_marker_replication {
      status = "Enabled"
    }
  }

  depends_on = [
    aws_s3_bucket_versioning.cafe_website_source_versioning,
    aws_s3_bucket_versioning.cafe_website_destination_versioning,
    aws_iam_role_policy_attachment.cafe_website_replication_policy_attachment
  ]
}