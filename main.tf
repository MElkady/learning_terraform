terraform {
  backend "s3" {}
}

#######################################################
# IRL
#######################################################
provider "aws" {
  alias  = "irl"
  region = "eu-west-1"
  default_tags {
    tags = {
      Environment = "Demo"
      Project     = "TF Test"
    }
  }
}

resource "aws_key_pair" "webserver-key" {
  key_name   = "webserver-key"
  public_key = file("~/.ssh/id_rsa.pub")
}

data "aws_ssm_parameter" "irl_ami" {
  provider = aws.irl
  name     = "/aws/service/ami-amazon-linux-latest/amzn2-ami-hvm-x86_64-gp2"
}

module "irl_network" {
  source      = "./modules/networking"
  instance_az = "eu-west-1a"
  providers = {
    aws = aws.irl
  }
}

variable "ingress_rules" {
  type = list(object({
    port        = number
    proto       = string
    cidr_blocks = list(string)
  }))
  default = [
    {
      port        = 80
      proto       = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    },
    {
      port        = 22
      proto       = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  ]
}

resource "aws_security_group" "instance_sg" {
  vpc_id = module.irl_network.vpc_id
  dynamic "ingress" {
    for_each = var.ingress_rules
    content {
      cidr_blocks = ingress.value["cidr_blocks"]
      protocol    = ingress.value["proto"]
      from_port   = ingress.value["port"]
      to_port     = ingress.value["port"]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "tf_instance_sg"
  }
}

resource "aws_instance" "irl_instance" {
  provider                    = aws.irl
  ami                         = data.aws_ssm_parameter.irl_ami.value
  instance_type               = "t2.nano"
  associate_public_ip_address = true
  key_name                    = aws_key_pair.webserver-key.key_name
  subnet_id                   = module.irl_network.public_subnet_id
  security_groups             = [aws_security_group.instance_sg.id]

  provisioner "remote-exec" {
    inline = [
      "sudo yum -y install httpd",
      "sudo systemctl enable httpd",
      "sudo systemctl start httpd"
    ]

    connection {
      type        = "ssh"
      user        = "ec2-user"
      private_key = file("~/.ssh/id_rsa")
      host        = self.public_ip
    }
  }

  tags = {
    Name = "irl-tf-instance"
  }
}

output "irl_instance_url" {
  value = "http://${aws_instance.irl_instance.public_ip}"
}


#######################################################
# FRA
#######################################################
provider "aws" {
  alias  = "fra"
  region = "eu-central-1"
  default_tags {
    tags = {
      Environment = "Demo"
      Project     = "TF Test"
    }
  }
}

resource "aws_s3_bucket" "fra_bucket" {
  bucket_prefix = "fra-bucket"
  provider      = aws.fra
}

module "far_simple_lambda_function" {
  source = "terraform-aws-modules/lambda/aws"
  providers = {
    aws = aws.fra
  }

  function_name = "simple-lambda"
  description   = "My awesome lambda function"
  handler       = "index.handler"
  runtime       = "nodejs14.x"

  source_path = "./simple_lambda"

  attach_policy_statements = true
  policy_statements = {
    s3_read = {
      effect    = "Allow",
      actions   = ["s3:ListAllMyBuckets"],
      resources = ["*"]
    }
  }

  tags = {
    Name = "simple-lambda"
  }
}

output "fra_bucket_arn" {
  value = aws_s3_bucket.fra_bucket.arn
}
