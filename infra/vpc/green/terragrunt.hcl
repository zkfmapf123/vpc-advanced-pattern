include "root" {
    path = find_in_parent_folders("__shared__.hcl")
}

terraform {
    source = "github.com/leedonggyu-terraform-factory/terraform-resource-vpc?ref=master"
}

locals {
    name = basename(get_terragrunt_dir())
    cidr_block = "11.0.0.0/16"
}

inputs = {
    common_attr = {
    name   = local.name
    env    = "prd"
    region = "ap-northeast-2"
  }

  vpc_attr = {
    cidr_block = local.cidr_block
    azs        = 2
    subnet_cidrs = {
      "webserver" : [cidrsubnet(local.cidr_block, 8, 1), cidrsubnet(local.cidr_block, 8, 2)],
      "was" : [cidrsubnet(local.cidr_block, 8, 3), cidrsubnet(local.cidr_block, 8, 4)],
      "db" : [cidrsubnet(local.cidr_block, 8, 5), cidrsubnet(local.cidr_block, 8, 6)]
    }
    is_nat = false
  }

  subnet_tags_attr = {
    "webserver" : {
      "Properties" : "webserver"
    },
    "was" : {
      "Properties" : "was"
    },
    "db" : {
      "Properties" : "db"
    }
  }

  tag_attr = {
    "Common" : "aaa"
  }

  webserver_nacl_attr = {
    "ingress" : {
      "100" : {
        "protocol" : "-1",
        "action" : "allow",
        "cidr_block" : "0.0.0.0/0",
        "from_port" : 0,
        "to_port" : 0
      },
    },
    "egress" : {
      "100" : {
        "protocol" : "-1",
        "action" : "allow",
        "cidr_block" : "0.0.0.0/0",
        "from_port" : 0,
        "to_port" : 0
      },
    }
  }

  was_nacl_attr = {
    "ingress" : {
      "100" : {
        "protocol" : "-1",
        "action" : "allow",
        "cidr_block" : "10.0.0.0/16",
        "from_port" : 0,
        "to_port" : 0
      },
    },
    "egress" : {
      "100" : {
        "protocol" : "-1",
        "action" : "allow",
        "cidr_block" : "0.0.0.0/0",
        "from_port" : 0,
        "to_port" : 0
      },
    }
  }

  db_nacl_attr = {
    "ingress" : {
      "100" : {
        "protocol" : "tcp",
        "action" : "allow",
        "cidr_block" : "10.0.0.0/16",
        "from_port" : 3306,
        "to_port" : 3306
      }
    },
    "egress" : {
      "100" : {
        "protocol" : "-1",
        "action" : "allow",
        "cidr_block" : "0.0.0.0/0",
        "from_port" : 0,
        "to_port" : 0
      }
    }
  } 
}