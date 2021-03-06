provider "aws" {
    region = "eu-west-3"
    access_key = "X"
    secret_key = "X"
}


/*resource "aws_instance" "my-first-server" {
  ami           = "ami-0f7cd40eac2214b37" 
  instance_type = "t2.micro"
  tags = {
      //Name = "ubuntu"
  }
}

//If running terraform apply 
//while instance is already open
//without config changes
//Will do nothing
*/

/*
----CREATE A SUBNET----
resource "aws_subnet" "subnet-1" {
    vpc_id = aws_vpc.vpc.id
    cidr_block = "10.0.1.0/24"
    tags = {
        Name = "prod-subnet"
    }
}

resource "aws_vpc" "vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "prod"
    }
}

resource "aws_vpc" "vpc2" {
    cidr_block = "10.1.0.0/16"
    tags = {
        Name = "dev"
    }
}

resource "aws_subnet" "subnet-2" {
    vpc_id = aws_vpc.vpc2.id
    cidr_block = "10.1.1.0/24"
    tags = {
        Name = "dev-subnet"
    }
}
*/

variable "subnet_prefix" {
    description = "cidr block"
    //type = string
}


resource "aws_vpc" "prod-vpc" {
    cidr_block = "10.0.0.0/16"
    tags = {
        Name = "prod"
    }
}


resource "aws_internet_gateway" "gw" {
    vpc_id = aws_vpc.prod-vpc.id
}

resource "aws_route_table" "prod-route-table" {
  vpc_id = aws_vpc.prod-vpc.id
  route {
      cidr_block = "0.0.0.0/0"
      gateway_id = aws_internet_gateway.gw.id
  }
  route { 
      ipv6_cidr_block        = "::/0"
      gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "prod"
  }
}

resource "aws_subnet" "subnet" {
    vpc_id = aws_vpc.prod-vpc.id
    cidr_block = var.subnet_prefix
    availability_zone = "eu-west-3a"

    tags = {
        Name = "dev-subnet"
    }
}

resource "aws_route_table_association" "a" {
    subnet_id      = aws_subnet.subnet.id
    route_table_id = aws_route_table.prod-route-table.id
}

resource "aws_security_group" "allow_web" {
  name        = "allow_web_traffic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.prod-vpc.id

    ingress {
            description      = "Https Traffic"
            from_port        = 443
            to_port          = 443
            protocol         = "tcp"
            cidr_blocks      = ["0.0.0.0/0"]
    }

    ingress {
            description      = "Http Traffic"
            from_port        = 80
            to_port          = 80
            protocol         = "tcp"
            cidr_blocks      = ["0.0.0.0/0"]
    }

    ingress {
            description      = "SSH"
            from_port        = 22
            to_port          = 22
            protocol         = "tcp"
            cidr_blocks      = ["0.0.0.0/0"]
    }


  egress {
      from_port        = 0
      to_port          = 0
      protocol         = "-1"
      cidr_blocks      = ["0.0.0.0/0"]
      ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_web"
  }
}

resource "aws_network_interface" "web-server-nic" {
  subnet_id       = aws_subnet.subnet.id
  private_ips     = ["10.0.1.50"]
  security_groups = [aws_security_group.allow_web.id]
}

resource "aws_eip" "one" {
  vpc                       = true
  network_interface         = aws_network_interface.web-server-nic.id
  associate_with_private_ip = "10.0.1.50"
  depends_on = [aws_internet_gateway.gw]
}

resource "aws_instance" "web-server" {
    ami = "ami-0f7cd40eac2214b37"
    instance_type = "t2.micro"
    availability_zone = "eu-west-3a"
    key_name = "terra-aws-train"

    network_interface {
        device_index = 0
        network_interface_id = aws_network_interface.web-server-nic.id
    }

    user_data = <<-EOF
            #!/bin/bash
            sudo apt update -y
            sudo apt install apache2 -y
            sudo systemct1 start apache2
            sudo bash -c 'echo your first web server > /var/www/html/index.html'
            EOF
    tags = {
        Name = "Web Server"
    }
}

output "public-ip"{
    value = aws_eip.one.public_ip
}
output "private-ip"{
    value = aws_eip.one.private_ip
}

