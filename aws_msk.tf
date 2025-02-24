provider "aws" {
  region = "us-east-1"  # Change as needed
}

resource "aws_msk_cluster" "example" {
  cluster_name           = "example-msk-cluster"
  kafka_version         = "3.4.0"
  number_of_broker_nodes = 3

  broker_node_group_info {
    instance_type   = "kafka.t3.small"
    client_subnets  = ["subnet-xxxxx", "subnet-yyyyy", "subnet-zzzzz"]
    security_groups = [aws_security_group.msk_sg.id]
  }
}

resource "aws_lb" "nlb" {
  name               = "msk-nlb"
  internal           = true
  load_balancer_type = "network"
  subnets           = ["subnet-xxxxx", "subnet-yyyyy", "subnet-zzzzz"]
}

#
# bootstrap_brokers - Comma separated list of one or more hostname:port pairs of kafka brokers suitable to bootstrap connectivity to the kafka cluster.
#

resource "aws_lb_target_group" "kafka" {
  count       = length(aws_msk_cluster.example.bootstrap_brokers)
  name        = "tg-${replace(element(aws_msk_cluster.example.bootstrap_brokers, count.index), ".", "-")}"
  port        = 9092
  protocol    = "TCP"
  vpc_id      = "vpc-xxxxx"  # Change to your VPC
  target_type = "instance"
}


resource "aws_lb_listener" "kafka_listener" {
  count             = length(aws_lb_target_group.kafka)
  load_balancer_arn = aws_lb.nlb.arn
  port             = 9092
  protocol         = "TCP"
  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.kafka[count.index].arn
  }
}

resource "aws_route53_record" "nlb_alias" {
  zone_id = "ZXXXXXXXXXXXXX"
  name    = "kafka.example.com"
  type    = "A"

  alias {
    name                   = aws_lb.nlb.dns_name
    zone_id                = aws_lb.nlb.zone_id
    evaluate_target_health = false
  }
}

resource "aws_security_group" "msk_sg" {
  name_prefix = "msk-sg-"
  vpc_id      = "vpc-xxxxx"

  ingress {
    from_port   = 9092
    to_port     = 9092
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Adjust for security
  }
}
