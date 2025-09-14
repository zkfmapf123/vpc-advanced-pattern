include "root" {
    path = find_in_parent_folders("__shared__.hcl")
}

terraform {
    source = "github.com/leedonggyu-terraform-factory/terraform-resource-ec2?ref=master"
}

dependency "vpc" { 
    config_path = "${get_parent_terragrunt_dir()}/vpc/${basename(get_terragrunt_dir())}"
}

## x86_64
inputs = {
    items = {
        "blue" = {
            ami = "ami-0ae2c887094315bed"
            instance_type = "t3.micro"
            vpc_id = dependency.vpc.outputs.vpc_id
            subnet_id = dependency.vpc.outputs.was_subnet_ids["a"]
            user_data = base64encode("hello world")
            # user_data = file("${get_terragrunt_dir()}/user_data.sh")
        }
    }
}