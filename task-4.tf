provider "aws" {
  region = "ap-south-1"
  profile = "Ddhruv"
}

variable "key_name" {}

resource "tls_private_key" "example" {
  algorithm   = "RSA"
  rsa_bits = "4096"
}


resource "aws_key_pair" "generated_key" {
  key_name   = var.key_name
  public_key = tls_private_key.example.public_key_openssh
}


resource "aws_vpc" "vpc_1" { 
  cidr_block = "10.0.0.0/16"
  instance_tenancy = "default"
  enable_dns_hostnames = "true"

  tags = {
    Name = "vpc_1"
  }
}


resource "aws_subnet" "public_subs" { 
  vpc_id     = aws_vpc.vpc_1.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "ap-south-1a"
  map_public_ip_on_launch = "true"
  depends_on = [aws_vpc.vpc_1]

  tags = {
    Name = "public_subs"
  }
}


resource "aws_subnet" "private_subs" { 
  vpc_id     = aws_vpc.vpc_1.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "ap-south-1b"
  map_public_ip_on_launch = "false"
  depends_on = [aws_vpc.vpc_1]

  tags = {
    Name = "private_subs"
  }
}


resource "aws_internet_gateway" "net_way" { 
  vpc_id = aws_vpc.vpc_1.id
  depends_on = [aws_vpc.vpc_1]

  tags = {
    Name = "net_way"
  }
}



resource "aws_eip" "n_eip" {
  vpc =true
}
resource "aws_nat_gateway" "g_way" {
  allocation_id = "${aws_eip.n_eip.id}"
  subnet_id     = "${aws_subnet.public_subs.id}"

  tags = {
    Name = "nat_gate_way"
  }
}



resource "aws_route_table" "r_table" { 
  vpc_id = aws_vpc.vpc_1.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.net_way.id
  }
  depends_on = [aws_vpc.vpc_1]

  tags = {
    Name = "r_table"
  }
}


resource "aws_route_table_association" "rt_associate" {
  subnet_id      = aws_subnet.public_subs.id
  route_table_id = aws_route_table.r_table.id
  depends_on = [aws_subnet.public_subs]
}


resource "aws_security_group" "s_g" {
  name        = "s_g"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpc_1.id

 ingress {
    description = "http"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

 ingress {
    description = "ssh"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  depends_on = [aws_vpc.vpc_1]

  tags = {
    Name = "s_g"
  }
}


resource "aws_instance" "wordpress" {
  ami           = "ami-049cbce295a54b26b"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.generated_key.key_name //"aaa111"
  subnet_id =  aws_subnet.public_subs.id
  vpc_security_group_ids = [ "${aws_security_group.s_g.id}"]
  
  tags = {
    Name = "wordpress"
  }
}

output "wordpress_public_ip"{
  value=aws_instance.wordpress.public_ip
}


resource "aws_security_group" "sql_s_g" {
  name        = "basic"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.vpc_1.id

  ingress {
    description = "t3mysql"
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  depends_on = [aws_vpc.vpc_1]

  tags = {
    Name = "sql_s_g"
  }
}


resource "aws_instance" "sql_os" {
  ami           = "ami-08706cb5f68222d09"
  instance_type = "t2.micro"
  key_name      = aws_key_pair.generated_key.key_name //"aaa111"
  subnet_id =  aws_subnet.private_subs.id
  vpc_security_group_ids = [aws_security_group.sql_s_g.id]
  
  tags = {
    Name = "sql_os"
  }
}

resource "null_resource" "null" {
depends_on = [aws_instance.wordpress,aws_instance.sql_os]

connection {
        type        = "ssh"
    	user        = "ec2-user"
    	private_key = file("C:/Users/ACER/Downloads/aaa111.pem")
        host     = aws_instance.wordpress.public_ip
        }

provisioner "local-exec" {    
      command = "start chrome http://${aws_instance.wordpress.public_ip}/wordpress"
   }
}