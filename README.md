# Shipping Infrastructure Safely with Modern IaC and CI/CD Patterns

Hey! Welcome to the companion repo for the talk *"Shipping Infrastructure Safely with Modern IaC and CI/CD Patterns"*. If you were in the session — or just stumbled across this — everything you need to replicate the demo yourself is right here.

This is a hands-on, end-to-end example of how to ship Terraform changes safely using GitHub Actions, OIDC authentication, and a multi-environment pipeline. No hand-waving, no "left as an exercise" — the actual code is here and you can deploy it.

---

## What you'll learn

By working through this repo you'll see three patterns in action:

| Pattern | What it teaches |
|---|---|
| **Plan → Review → Apply with OIDC** | How to ditch long-lived AWS keys and use GitHub's OIDC token instead |
| **Layered Pipeline with Controlled Promotion** | How to ship to dev first and gate prod on dev's success |
| **Drift Detection & Reconciliation** | How to catch infrastructure drift before it becomes an incident |

There's also a real-world incident walkthrough baked into the code — specifically around how AWS Service Control Policies (SCPs) can silently block permissions that IAM happily approved. It's the kind of thing that only hits you in production at 2am, so let's talk about it now.

---

## How the pipeline works

```
Open a PR
    │
    ├── terraform fmt      (catches sloppy formatting)
    ├── terraform validate  (catches bad references and typos)
    ├── tfsec              (flags security misconfigurations)
    └── terraform plan     (shows exactly what will change)
                │
         All results posted as a PR comment
                │
         Merge to main
                │
         ┌──────▼──────┐
         │  Deploy Dev  │  ← terraform apply + upload site to S3
         └──────┬──────┘
                │ (only if dev succeeded)
         ┌──────▼──────┐
         │  Deploy Prod │  ← same thing, but gated
         └─────────────┘
```

**What gets deployed:**
- An S3 bucket serving a static website (the demo landing page)
- An EC2 instance with some hardening applied
- An IAM role that lets GitHub Actions authenticate without any stored keys
- An SCP that enforces permission boundaries at the organization level

---

## Repository structure

```
.
├── .github/
│   ├── CODEOWNERS                        # Who gets auto-tagged for review
│   └── workflows/
│       ├── terraform-plan.yml            # Runs on every PR
│       └── terraform-apply.yml           # Runs when you merge to main
├── app/
│   └── index.html                        # The static site that gets deployed to S3
├── docs/
│   └── *.pdf                             # Slide deck from the talk
└── infrastructure/
    ├── main.tf                           # AWS provider config + S3 backend
    ├── variables.tf                      # Input variables for the root module
    ├── versions.tf                       # Terraform and provider version pins
    ├── ec2.tf                            # The demo EC2 instance (hardened)
    ├── outputs.tf                        # Values exported after apply
    ├── environments/
    │   ├── dev/terraform.tfvars          # Dev-specific values
    │   └── prod/terraform.tfvars         # Prod-specific values
    ├── modules/
    │   └── s3-static-site/              # Reusable module for S3 website hosting
    └── shared/
        ├── main.tf                       # OIDC provider + GitHub Actions IAM role
        ├── scp.tf                        # Organization-level Service Control Policy
        ├── variables.tf
        ├── versions.tf
        ├── outputs.tf
        └── terraform.tfvars             # Your values go here before bootstrapping
```

---

## Before you start — what you'll need

- **Terraform >= 1.5** — [Install guide](https://developer.hashicorp.com/terraform/install)
- **An AWS account** — Free tier works for everything except the EC2 instance (t3.micro stays within free tier for the first year)
- **AWS Organizations enabled** if you want to try the SCP part — optional, you can skip it
- **A GitHub repo** with Actions enabled — fork this one or create your own
- **An S3 bucket** to store Terraform state — create one manually in the AWS console before starting

---

## Step 1 — Bootstrap (do this once)

The `infrastructure/shared/` folder sets up the trust relationship between GitHub Actions and AWS. This is what allows the pipeline to authenticate without storing any AWS keys.

**Fill in your values:**

```hcl
# infrastructure/shared/terraform.tfvars
github_org   = "your-github-username-or-org"
github_repo  = "your-repo-name"
state_bucket = "your-tfstate-bucket-name"
project_name = "your-project-name"
aws_region   = "us-east-1"
```

**Apply it:**

```bash
cd infrastructure/shared
terraform init
terraform apply
```

**Grab the output and save it — you'll need it in the next step:**

```
role_arn = "arn:aws:iam::123456789012:role/github-actions-role"
```

---

## Step 2 — Configure GitHub Actions environments

In your GitHub repo, go to **Settings → Environments** and create two environments: `dev` and `prod`.

For each environment, add these secrets/variables:

```
AWS_ROLE_ARN    = arn:aws:iam::YOUR_ACCOUNT_ID:role/github-actions-role
AWS_REGION      = us-east-1
TF_STATE_BUCKET = your-tfstate-bucket-name
```

> **Tip:** For the `prod` environment, consider adding a required reviewer under "Deployment protection rules." That way, every prod deployment needs a human to click approve first — which is exactly the kind of control you want in real life.

---

## Step 3 — Open a PR and watch the pipeline run

Make any small change (update the `index.html`, tweak a variable, add a tag) and open a pull request. The `terraform-plan.yml` workflow will kick off automatically and post a comment showing:

- Whether the code is formatted correctly
- Whether the configuration is valid
- Any security issues tfsec found
- The exact changes Terraform would make — resources added, modified, or destroyed

Once you merge, `terraform-apply.yml` takes over and deploys to dev, then prod.

---

## Running it locally (optional)

If you want to run Terraform yourself before wiring up the pipeline:

```bash
cd infrastructure

# Initialize — point at your state bucket and pick an environment key
terraform init \
  -backend-config="bucket=your-tfstate-bucket" \
  -backend-config="key=dev/website/terraform.tfstate" \
  -backend-config="region=us-east-1"

# See what would change
terraform plan -var-file="environments/dev/terraform.tfvars"

# Apply it
terraform apply -var-file="environments/dev/terraform.tfvars"
```

---

## The security stuff worth understanding

### Why OIDC instead of access keys?

The traditional approach is storing `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` as GitHub secrets. That works, but those keys are long-lived — if they leak, someone has persistent access to your AWS account until you rotate them.

OIDC flips this around. GitHub generates a short-lived token for each job run. AWS validates that token and issues temporary credentials that expire when the job ends. Nothing to leak, nothing to rotate.

```
GitHub Actions job starts
    │
    └── GitHub issues a one-time OIDC token
                │
                └── AWS STS validates it and returns temporary credentials (expire in ~1 hour)
                                │
                                └── Job uses those credentials, then they're gone
```

The IAM role created in `infrastructure/shared/main.tf` is scoped to your specific repository — so even if someone forked your repo, they couldn't use your role.

### The SCP incident story

`infrastructure/shared/scp.tf` creates an organization-level Service Control Policy that blocks wildcard permissions like `s3:*`, `ec2:*`, and `iam:*`.

Here's why that matters: IAM lets you write a policy with `dynamodb:*`. Terraform will validate it, apply it successfully, and report no errors. But if your organization has an SCP that restricts wildcard actions, every `dynamodb:*` API call will be denied at runtime — and you won't find out until something breaks in production.

The lesson: **IAM and SCPs are enforced independently.** Passing `terraform apply` doesn't mean your permissions will actually work under your organization's guardrails. Test with least-privilege policies in dev, under the same SCPs that prod uses.

The GitHub Actions role in this demo is explicitly exempted from the SCP so the pipeline keeps working — see the `not_principals` block in `scp.tf`.

### EC2 hardening (what and why)

The EC2 instance in `infrastructure/ec2.tf` isn't just a vanilla instance. It has:

- **No SSH key pair** — You can't SSH in. If you need access, use SSM Session Manager instead.
- **IMDSv2 enforced** — The instance metadata service (IMDS) is what gives EC2 instances their IAM credentials. IMDSv1 can be abused by SSRF attacks to steal those credentials. IMDSv2 requires a session token, which blocks that attack path.
- **Encrypted root volume** — EBS encryption at rest, enabled by default.
- **No inbound security group rules** — The instance can reach out, but nothing can reach in.

---

## Tech stack

| Layer | Tool |
|---|---|
| Infrastructure as Code | Terraform >= 1.5 |
| Cloud provider | AWS (S3, EC2, IAM, Organizations) |
| CI/CD | GitHub Actions |
| Authentication | AWS OIDC (no stored credentials) |
| Security scanning | tfsec |
| Org-level governance | AWS Service Control Policies |

---

## Questions or stuck on something?

Feel free to open an issue in this repo. If you were at the live session, you can also reach me at **edwin.moedano@caylent.com**.

The slide deck is in the `docs/` folder if you want to revisit any of the concepts from the talk.
