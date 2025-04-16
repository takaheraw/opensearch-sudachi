# Terraformバージョン
terraform {
  required_version = ">= 1.3" # Terraformのバージョン要件

  required_providers {
    aws = {
      source  = "hashicorp/aws" # AWSプロバイダーのソース
      version = ">= 5.0" # AWSプロバイダーのバージョン要件
    }
  }
}

# プロバイダー設定
provider "aws" {
  region = "ap-northeast-1" # 使用するAWSリージョン
}

# 環境の変数(dev または prd)
variable "environment" {
  description = "Environment (dev or prd)" # 環境の説明
  type        = string # 変数の型
  default     = "dev" # デフォルト値
}

data "aws_caller_identity" "current" {}

# ローカル変数の設定
locals {
  opensearch_domain_name = "opensearch-sudachi" # OpenSearchドメイン名
  config = {
    dev = {
      multi_az_with_standby_enabled = false         # マルチAZスタンバイの有効化
      availability_zone_count  = 1                  # 利用するアベイラビリティゾーンの数
      zone_awareness_enabled   = false              # ゾーンアウェアネスの有効化
      instance_type            = "t3.medium.search" # インスタンスタイプ
      instance_count           = 1                  # インスタンスの数
      ebs_volume_size          = 10                 # EBSボリュームのサイズ(GB)
      dedicated_master_enabled = false              # 専用マスターノードの有効化
      master_instance_type     = null               # マスターノードのインスタンスタイプ
      warm_enabled             = false              # ウォームノードの有効化
      auto_tune_enabled        = false              # 自動チューニングの有効化
    }
    prd = {
      multi_az_with_standby_enabled = true               # マルチAZスタンバイの有効化
      availability_zone_count       = 3                  # 利用するアベイラビリティゾーンの数
      zone_awareness_enabled        = true               # ゾーンアウェアネスの有効化
      instance_type                 = "r7g.large.search" # インスタンスタイプ
      instance_count                = 3                  # インスタンスの数
      ebs_volume_size               = 100                # EBSボリュームのサイズ(GB)
      dedicated_master_enabled      = true               # 専用マスターノードの有効化
      master_instance_type          = "m7g.large.search" # マスターノードのインスタンスタイプ
      dedicated_master_count        = 3                  # 専用マスターノードの数
      warm_enabled                  = false              # ウォームノードの有効化
      auto_tune_enabled             = true               # 自動チューニングの有効化
    }
  }

  env_config = local.config[var.environment] # 環境に応じた設定を選択
}

# OpenSearchドメインのリソース設定
resource "aws_opensearch_domain" "opensearch_sudachi" {
  domain_name    = local.opensearch_domain_name # ドメイン名
  engine_version = "OpenSearch_2.17" # OpenSearchのバージョン

  cluster_config {
    instance_type            = local.env_config.instance_type # インスタンスタイプ
    instance_count           = local.env_config.instance_count # インスタンスの数
    zone_awareness_enabled   = local.env_config.zone_awareness_enabled # ゾーンアウェアネスの有効化
    dedicated_master_enabled = local.env_config.dedicated_master_enabled # 専用マスターノードの有効化

    dynamic "zone_awareness_config" {
      for_each = local.env_config.zone_awareness_enabled ? [1] : [] # ゾーンアウェアネスが有効な場合の設定
      content {
        availability_zone_count = local.env_config.availability_zone_count # アベイラビリティゾーンの数
      }
    }

    multi_az_with_standby_enabled = local.env_config.multi_az_with_standby_enabled # マルチAZスタンバイの有効化

    dedicated_master_type  = local.env_config.dedicated_master_enabled ? local.env_config.master_instance_type : null # マスターノードのインスタンスタイプ
    dedicated_master_count = local.env_config.dedicated_master_enabled ? local.env_config.dedicated_master_count : null # 専用マスターノードの数
  }

  ebs_options {
    ebs_enabled = true # EBSの有効化
    volume_type = "gp3" # EBSボリュームのタイプ
    volume_size = local.env_config.ebs_volume_size # EBSボリュームのサイズ(GB)
    throughput  = 125 # スループット(MB/s)
    iops        = 3000 # IOPS
  }

  node_to_node_encryption {
    enabled = true # ノード間暗号化の有効化
  }

  encrypt_at_rest {
    enabled    = true # 保存データの暗号化の有効化
  }

  advanced_security_options {
    enabled                        = true # 高度なセキュリティオプションの有効化
    internal_user_database_enabled = true # 内部ユーザーデータベースの有効化
    master_user_options {
      master_user_name     = "master-user"            # マスターユーザー名
      master_user_password = var.master_user_password # マスターユーザーパスワード
    }
  }

  auto_tune_options {
    desired_state = local.env_config.auto_tune_enabled ? "ENABLED" : "DISABLED" # 自動チューニングの状態
  }

  software_update_options {
    auto_software_update_enabled = false # 自動ソフトウェア更新の無効化
  }

  advanced_options = {
    "override_main_response_version" = "false" # メインレスポンスバージョンのオーバーライド
  }

  domain_endpoint_options {
    enforce_https       = true # HTTPSの強制
    tls_security_policy = "Policy-Min-TLS-1-2-2019-07" # TLSセキュリティポリシー
  }

  access_policies = jsonencode({
    Version   = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Principal = "*"
        Action = "es:*"
        Resource = "arn:aws:es:ap-northeast-1:${data.aws_caller_identity.current.account_id}:domain/${local.opensearch_domain_name}/*"
        Condition = {
          IpAddress = {
            "aws:SourceIp" = var.source_ip # アクセス元IPアドレス
          }
        }
      }
    ]
  })

  tags = {
    Environment = var.environment # 環境タグ
    ManagedBy   = "Terraform"     # 管理者タグ
  }
}

resource "aws_s3_bucket" "opensearch_packages" {
  bucket = "opensearch-sudachi-${var.environment}-packages"
}

resource "aws_s3_object" "sudachi_system_dict" {
  bucket       = aws_s3_bucket.opensearch_packages.bucket
  content_type = "binary/octet-stream"
  key          = "system_core.dic"
  source       = "./system_core.dic"
}

resource "aws_s3_object" "sudachi_user_dict" {
  bucket       = aws_s3_bucket.opensearch_packages.bucket
  content_type = "binary/octet-stream"
  key          = "user_dict.dic"
  source       = "./user_dict.dic"
}

resource "aws_opensearch_package" "sudachi_system_dict" {
  package_name = "sudachi-system-dict-${var.environment}"
  package_source {
    s3_bucket_name = aws_s3_bucket.opensearch_packages.bucket
    s3_key         = aws_s3_object.sudachi_system_dict.key
  }
  package_type = "TXT-DICTIONARY"
}

resource "aws_opensearch_package" "sudachi_user_dict" {
  package_name = "sudachi-user-dict-${var.environment}"
  package_source {
    s3_bucket_name = aws_s3_bucket.opensearch_packages.bucket
    s3_key         = aws_s3_object.sudachi_user_dict.key
  }
  package_type = "TXT-DICTIONARY"
}

resource "aws_opensearch_package_association" "sudachi_system_dict" {
  package_id  = aws_opensearch_package.sudachi_system_dict.id
  domain_name = aws_opensearch_domain.opensearch_sudachi.domain_name
}

resource "aws_opensearch_package_association" "sudachi_user_dict" {
  package_id  = aws_opensearch_package.sudachi_user_dict.id
  domain_name = aws_opensearch_domain.opensearch_sudachi.domain_name
}

resource "aws_opensearch_package_association" "sudachi_plugin" {
  package_id  = "G101931787" # analysis-sudachi OpenSearch 2.17
  domain_name = aws_opensearch_domain.opensearch_sudachi.domain_name

  timeouts {
    create = "30m"
    delete = "30m"
  }
}
