# env.hcl 파일에서 환경 변수 읽기
locals {
    env_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))
}

remote_state {
    backend ="s3"
    
    generate = {
        path = "backend.tf"
        if_exists = "overwrite_terragrunt"
    }

    config = {
        bucket = local.env_vars.locals.bucket
        key = "${path_relative_to_include()}/terraform.tfstate"
        region = "ap-northeast-2"
        
        assume_role = {
            role_arn = local.env_vars.locals.role_arn
        }

        encrypt = false
        skip_bucket_root_access=true
        enable_lock_table_ssencryption = false
        skip_bucket_enforced_tls = true
        skip_bucket_ssencryption = true
    }
}

generate "provider" {
    path = "provider.tf"
    if_exists = "skip"

    contents = <<EOF
    provider "aws" {
        region = "ap-northeast-2"
        
        assume_role {
            role_arn = "${local.env_vars.locals.role_arn}"
        }
    }
    EOF
}

    