# AWS Certification Simulation Infrastructure

This OpenTofu stack is for a non-production sandbox certification campaign in `us-west-2`.

It intentionally does not change the local LocalStack boundary. Real AWS execution must use the opt-in scripts:

```bash
AWS_CERTIFICATION_ENABLED=1 AWS_REGION=us-west-2 AWS_CERT_TTL_HOURS=24 make aws-cert-preflight
AWS_CERTIFICATION_ENABLED=1 AWS_REGION=us-west-2 AWS_CERT_TTL_HOURS=24 make aws-cert-deploy
AWS_CERTIFICATION_ENABLED=1 AWS_REGION=us-west-2 AWS_CERT_TTL_HOURS=24 make aws-cert-run
AWS_CERTIFICATION_ENABLED=1 AWS_REGION=us-west-2 AWS_CERT_TTL_HOURS=24 make aws-cert-collect
AWS_CERTIFICATION_ENABLED=1 AWS_REGION=us-west-2 AWS_CERT_TTL_HOURS=24 make aws-cert-destroy
```

Root credentials are not permitted for deploy/test loops. Root is reserved only for account bootstrap or break-glass actions outside this stack.

