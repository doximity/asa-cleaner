# asa-cleaner

Terraform module that creates an AWS Lambda to remove Okta ASA servers on EC2 termination events.

## Description

This Terraform module creates an AWS Lambda which executes on CloudWatch EC2 termination events. This lambda then uses the Okta ASA API to remove the EC2 instance from ASA inventory.

An ASA service user with API keypair secrets stored in SSM is needed to run this module.

## Usage

```hcl
module "asa_cleaner" {
  source = "git::https://github.com/doximity/asa-cleaner?ref=tags/0.1.0"
  
  env   					= "production"
  asa_team 				= "demo_team"
  kms_key_arn 			= aws_kms_key.demo_key.arn
  asa_api_key_path 		= "/demo/asa/api_key"
  asa_api_secret_path 	= "/demo/asa/api_secret"
}

```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/asa-cleaner/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
6. Sign the CLA if you haven't yet. See CONTRIBUTING.md

## License

asa-cleaner is licensed under an Apache 2 license. Contributors are required to sign an contributor license agreement. See LICENSE.txt and CONTRIBUTING.md for more information.
