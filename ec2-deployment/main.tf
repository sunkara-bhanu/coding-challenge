variable "input_region" {
  type = string
  description = "Region in which the EC2 instance deployment needed"
}

variable "ing_rule"{
  type = list
  default = [80,443]
}

variable "eg_rule"{
  type=list
  default = [80,443]
}

variable "amis"{
    type = map
    default = {
        "ap-south-1" : "ami-01a4f99c4ac11b03c"
        "ap-southeast-1" : "ami-0753e0e42b20e96e3"
        "ap-southeast-2" : "ami-023dd49682f8a7c2b"
        "ap-northeast-1" : "ami-06ee4e2261a4dc5c3"
        "ap-northeast-2" : "ami-013218fccb68a90d4"
        "ap-northeast-3" : "ami-062f8fd8345beef36"
    }
}

provider "aws" {
    region = var.input_region
}

resource "aws_security_group" "allow_http_https_traffic"{
  dynamic "ingress"{
    iterator = port
    for_each = var.ing_rule
    content {
      from_port = port.value
      to_port = port.value
      protocol = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }
  dynamic "egress"{
    iterator = port
    for_each = var.eg_rule
    content {
      from_port = port.value
      to_port = port.value
      protocol = "TCP"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

}
 
resource "aws_instance" "ec2_resource"{
    ami = var.amis[var.input_region]
    instance_type = "t2.micro"
    security_groups = [aws_security_group.allow_http_https_traffic.name]
    user_data = file("user_data.sh")
    tags = {
      "Name" = "ec2-deployment"
    }
}

output "public_ip"{
  value = aws_instance.ec2_resource.public_ip
}
