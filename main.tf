resource "aws_lambda_function" "asa-cleaner" {
  filename         = "${path.module}/files/lambda/asa-cleaner.zip"
  function_name    = "${var.env}-asa-cleaner"
  role             = aws_iam_role.asa-cleaner.arn
  handler          = "asa_cleaner.lambda_handler"
  source_code_hash = "${filebase64sha256("${path.module}/files/lambda/asa-cleaner.zip")}"
  runtime          = "ruby2.7"
  timeout          = "600"

  environment {
    variables = {
      ENVIRONMENT        = var.env
      ASA_API_KEY_PATH = var.asa_api_key_path
      ASA_API_SECRET_PATH = var.asa_api_secret_path
      ASA_TEAM = var.asa_team
    }
  }
}

resource "aws_cloudwatch_event_rule" "instance_terminated_events" {
  name        = "${var.env}-asa-capture-ec2-terminated-events"
  description = "Capture all EC2 instance terminated events"

  event_pattern = <<PATTERN
{
  "source": [
    "aws.ec2"
  ],
  "detail-type": [
    "EC2 Instance State-change Notification"
  ],
  "detail": {
    "state": [
      "terminated"
    ]
  }
}
PATTERN
}

resource "aws_cloudwatch_event_target" "asa-cleaner" {
  rule = aws_cloudwatch_event_rule.instance_terminated_events.name
  arn  = aws_lambda_function.asa-cleaner.arn
}

resource "aws_lambda_permission" "events" {
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.asa-cleaner.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.instance_terminated_events.arn
}

resource "aws_iam_role" "asa-cleaner" {
  name = "${var.env}-asa-cleaner"

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Action": "sts:AssumeRole",
      "Principal": {
        "Service": "lambda.amazonaws.com"
      },
      "Effect": "Allow"
    }
  ]
}
EOF

}

resource "aws_iam_policy" "asa-cleaner" {
  name        = "${var.env}-asa-cleaner"
  description = "Allow asa-cleaner lambda to write CloudWatch logs and read SSM secrets."
  policy      = data.aws_iam_policy_document.asa-cleaner.json
}

data "aws_iam_policy_document" "asa-cleaner" {
  statement {
    sid       = "CreateLogGroup"
    effect    = "Allow"
    actions   = ["logs:CreateLogGroup"]
    resources = ["arn:aws:logs:*:*:*"]
  }

  statement {
    sid     = "CreatePutLogEvents"
    effect  = "Allow"
    actions = ["logs:CreateLogStream", "logs:PutLogEvents"]
    resources = [
      "arn:aws:logs:**:*:log-group:/aws/lambda/${var.env}-asa-cleaner:*",
    ]
  }

  statement {
    sid       = "DescribeAllParameters"
    effect    = "Allow"
    actions   = ["ssm:DescribeParameters"]
    resources = ["*"]
  }

  statement {
    sid     = "GetApiParams"
    effect  = "Allow"
    actions = ["ssm:GetParameter*"]
    resources = [
      "arn:aws:ssm:*:*:parameter${var.asa_api_key_path}",
      "arn:aws:ssm:*:*:parameter${var.asa_api_secret_path}",
    ]
  }

  statement {
    sid       = "DecryptParams"
    effect    = "Allow"
    actions   = ["kms:Decrypt"]
    resources = ["${var.kms_key_arn}"]
  }
}

resource "aws_iam_role_policy_attachment" "attach-asa-cleaner" {
  role       = aws_iam_role.asa-cleaner.name
  policy_arn = aws_iam_policy.asa-cleaner.arn
}
