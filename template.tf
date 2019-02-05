provider "aws" {
  region     = "eu-west-2"
}

variable "vpc_cidr" {
    description = "CIDR for the whole VPC"
    default = "10.0.0.0/16"
}

variable "public_subnet_cidr" {
    description = "CIDR for the Public Subnet"
    default = "10.0.0.0/24"
}

variable "ec2_key_pair" {
    description = "Your EC2 Key Pair"
}

data "aws_region" "current_region" {
}



#### Creating all the network Resources
#### Creating all the network Resources
#### Creating all the network Resources


# Creating the VPC

resource "aws_vpc" "CDVPC" {
    cidr_block = "${var.vpc_cidr}"
    enable_dns_hostnames = true
    tags {
        Name = "CodeDeploy-aws-vpc"
    }
}

# Creating the IGW and attaching to VPC

resource "aws_internet_gateway" "CDIGW" {
    vpc_id = "${aws_vpc.CDVPC.id}"
}


# Creating the Public subnet

resource "aws_subnet" "CDPublicSubnet" {
    vpc_id = "${aws_vpc.CDVPC.id}"

    map_public_ip_on_launch = "true"
    cidr_block = "${var.public_subnet_cidr}"
    availability_zone = "eu-west-2a"

    tags {
        Name = "CodeDeploy Public Subnet"
    }
}

# Creating the Route Table for the Public subnet


resource "aws_route_table" "CDRouteTablePublic" {
    vpc_id = "${aws_vpc.CDVPC.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.CDIGW.id}"
    }

    tags {
        Name = "Public Subnet"
    }
}

# Associating the Public Route table to the Public subnet

resource "aws_route_table_association" "CDRouteTablePublicAssoc" {
    subnet_id = "${aws_subnet.CDPublicSubnet.id}"
    route_table_id = "${aws_route_table.CDRouteTablePublic.id}"
}


resource "aws_security_group" "CDSG" {
  name = "cd-default-sg"
  description = "Default security group that allows inbound and outbound traffic from all instances in the VPC"
  vpc_id = "${aws_vpc.CDVPC.id}"

  ingress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }
  egress {
    from_port   = "0"
    to_port     = "0"
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    self        = true
  }
}


# Network Resources creation Done
# Network Resources creation Done
# Network Resources creation Done



# Instance Profile creation

resource "aws_iam_instance_profile" "CDInstanceProfile" {
  name = "CodeDeployInstanceProfile"
  role = "${aws_iam_role.CodeDeployInstanceRole.name}"
}

resource "aws_iam_role" "CodeDeployInstanceRole" {
  name = "CodeDeployInstanceRole"
  path = "/"

  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {
               "Service": "codedeploy.amazonaws.com"
            },
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

## Attaching policy to Role

data "aws_iam_policy" "CodeDeployInstancePolicy" {
  arn = "arn:aws:iam::aws:policy/AmazonS3FullAccess"
}

resource "aws_iam_role_policy_attachment" "CD-role-policy-attach" {
  role = "${aws_iam_role.CodeDeployInstanceRole.name}"
  policy_arn = "${data.aws_iam_policy.CodeDeployInstancePolicy.arn}"
}



# Starting the creation of the Instances and AutoScaling Group/Load Balancer

resource "aws_autoscaling_group" "CDAutoScalingGroup" {

  lifecycle { create_before_destroy = true }
  name                      = "CDAutoScalingGroup-${aws_launch_configuration.CDLaunchConfig.name}"
  max_size                  = 5
  min_size                  = 2
  health_check_grace_period = 60
  health_check_type         = "ELB"
  desired_capacity          = 4
  force_delete              = true
  launch_configuration      = "${aws_launch_configuration.CDLaunchConfig.name}"
  vpc_zone_identifier       = ["${aws_subnet.CDPublicSubnet.id}"]
  load_balancers            = ["${aws_elb.CDELB.id}"]
}

resource "aws_launch_configuration" "CDLaunchConfig" {
  name_prefix   = "CD"
  image_id      = "ami-f976839e"
  instance_type = "t2.micro"
  user_data = "${file("./templates/user-data.tpl")}"
  iam_instance_profile = "${aws_iam_instance_profile.CDInstanceProfile.id}"
  security_groups = ["${aws_security_group.CDSG.id}"]
  key_name = "${var.ec2_key_pair}"

  lifecycle {
  create_before_destroy = "true"
 }

}


resource "aws_elb" "CDELB" {
  name = "CD-CLB"
  listener {
    instance_port = 80
    instance_protocol = "http"
    lb_port = 80
    lb_protocol = "http"
  }
  health_check {
    healthy_threshold = 3
    unhealthy_threshold = 2
    timeout = 5
    target = "HTTP:80/"
    interval = 10
  }

  cross_zone_load_balancing = true
  idle_timeout = 60
  subnets         = ["${aws_subnet.CDPublicSubnet.id}"]
  security_groups = ["${aws_security_group.CDSG.id}"]

  tags {
    Name = "app-elb"
  }
}

##### STARTING Provisioning CodeDeploy Resources

resource "aws_codedeploy_app" "CDApplication" {
  compute_platform = "Server"
  name             = "MyTerraformApplication"
}


resource "aws_iam_role" "CodeDeployServiceRole" {
  name = "TerraformCodeDeployRole"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "",
      "Effect": "Allow",
      "Principal": {
        "Service": "codedeploy.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF
}

resource "aws_iam_role_policy_attachment" "AWSCodeDeployRole" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSCodeDeployRole"
  role       = "${aws_iam_role.CodeDeployServiceRole.name}"
}

resource "aws_codedeploy_deployment_group" "CDDeploymentGroup" {
  app_name              = "${aws_codedeploy_app.CDApplication.name}"
  deployment_group_name = "MyTerraformDeploymentGroup"
  service_role_arn      = "${aws_iam_role.CodeDeployServiceRole.arn}"
  deployment_config_name = "CodeDeployDefault.AllAtOnce"
  autoscaling_groups     = ["${aws_autoscaling_group.CDAutoScalingGroup.name}"]

  load_balancer_info {
  elb_info {
    name = "${aws_elb.CDELB.name}"
  }
}

deployment_style {
  deployment_option = "WITH_TRAFFIC_CONTROL"
  deployment_type   = "IN_PLACE"
}
}

resource "aws_s3_bucket" "CodeDeployBucket" {
  force_destroy = true
  tags = {
    Name        = "My Cool Bucket with random name"
    Environment = "PRODUCTION BABY"
  }
}



#### DONE PROVISIONING CODEDEPLOY MAMBO jambo


# Generating Deployment command


output "A) Push Revision" {
  value = "aws deploy push --application-name ${aws_codedeploy_app.CDApplication.name} --s3-location s3://${aws_s3_bucket.CodeDeployBucket.id}/revision.zip  --ignore-hidden-files --region ${data.aws_region.current_region.name}"
}

output "B) Create Deployment" {
  value = "aws deploy create-deployment --application-name ${aws_codedeploy_app.CDApplication.name} --deployment-group-name ${aws_codedeploy_deployment_group.CDDeploymentGroup.deployment_group_name} --s3-location bucket=${aws_s3_bucket.CodeDeployBucket.id},bundleType=zip,key=revision.zip --region ${data.aws_region.current_region.name}"
}
