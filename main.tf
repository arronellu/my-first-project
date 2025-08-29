terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }
}
provider "aws" {
  region     = "eu-central-1"
  access_key = "AKIAQ3BKKL74CAYUPVHB"
  secret_key = "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"
}

####### Create VPC

resource "aws_vpc" "prod" {
  cidr_block = "10.0.0.0/16"
  tags = {
    Name = "production"
  }
}

####### Create subnet

resource "aws_subnet" "public" {
  vpc_id     = aws_vpc.prod.id
  cidr_block = "10.0.1.0/24"
  tags = {
    Name = "public"
  }
}

resource "aws_subnet" "private" {
  vpc_id     = aws_vpc.prod.id
  cidr_block = "10.0.2.0/24"
  tags = {
    Name = "private"
  }
}

resource "aws_subnet" "private-new" {
  vpc_id     = aws_vpc.prod.id
  cidr_block = "10.0.3.0/24"
  tags = {
    Name = "private-new"
  }
}

####### Create IGW

resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.prod.id

  tags = {
    Name = "igw"
  }
}

####### Route table

resource "aws_route_table" "RT-prod" {
  vpc_id = aws_vpc.prod.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.igw.id
  }
}

####### Associate subnet with RT

resource "aws_route_table_association" "A" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.RT-prod.id
}

####### Create SG to allow ports 20, 80 & 443

resource "aws_security_group" "allow_WEB" {
  name        = "allow_web_traffic"
  description = "Allow Web inbound traffic"
  vpc_id      = aws_vpc.prod.id
}

resource "aws_vpc_security_group_ingress_rule" "HTTPS" {
  security_group_id = aws_security_group.allow_WEB.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 443
  ip_protocol = "tcp"
  to_port     = 443
}

resource "aws_vpc_security_group_ingress_rule" "ICMP" {
  security_group_id = aws_security_group.allow_WEB.id

  cidr_ipv4   = "86.120.188.67/32"
  from_port   = -1
  ip_protocol = "icmp"
  to_port     = -1

}
resource "aws_vpc_security_group_ingress_rule" "HTTP" {
  security_group_id = aws_security_group.allow_WEB.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 80
  ip_protocol = "tcp"
  to_port     = 80
}
resource "aws_vpc_security_group_ingress_rule" "SSH" {
  security_group_id = aws_security_group.allow_WEB.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 22
  ip_protocol = "tcp"
  to_port     = 22
}

resource "aws_vpc_security_group_egress_rule" "Allow_all_outbound_traffic" {
  security_group_id = aws_security_group.allow_WEB.id

  cidr_ipv4   = "0.0.0.0/0"
  from_port   = 0
  ip_protocol = "-1"
  to_port     = 0
}

####### Create an ENI

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.public.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_WEB.id]
}

####### Assign an EIP to the ENI

resource "aws_eip" "EIP" {
  domain                    = "vpc"
  network_interface         = aws_instance.web-server-instance.primary_network_interface_id
  associate_with_private_ip = aws_instance.web-server-instance.private_ip
  depends_on                = [aws_internet_gateway.igw]
}



####### Create Ubuntu server and install Apache

resource "aws_instance" "web-server-instance" {
  ami                         = "ami-0a116fa7c861dd5f9"
  instance_type               = "t3.micro"
  key_name                    = "SSH-access"
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.allow_WEB.id]
  user_data                   = <<-EOF
              apt update -y
              apt install -y nginx
              systemctl enable nginx
              systemctl start nginx
              <head><title>My Static Site</title></head>
              <body><h1>Salut din Nginx 🚀</h1><p>Site-ul meu rulează pe EC2 cu Terraform</p></body>
              </html>" > /var/www/html/index.html
              EOF
}

