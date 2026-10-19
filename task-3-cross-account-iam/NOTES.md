# Task 3 notes

## Access method versus permission

The brief separates who may use the console from what they may do.

`group1` is CLI and programmatic only. `engine` and `ci` have no login profile, so console password sign-in does not exist for them. For literal assignment compliance, optional access keys can be created with `create_access_keys = true`. The group policy allows `sts:GetCallerIdentity` and nothing else. That action cannot be limited to a resource. `Resource "*"` here is the STS requirement, not a grant of other services.

`ci` gets real pipeline rights from Task 4, attached to the user, not to `group1`. Attaching them to the group would give `engine` the same pipeline rights. The brief does not say `engine` deploys.

`group2` may use the console and the CLI. The console path is a login profile. The AWS provider generates the password and keeps it in state, and `password_reset_required` forces a change at first sign-in. I do not take the password as a variable, because this provider rejects a configured password and because a password in tfvars is a second copy of the secret. For the assignment, the optional access key supplies the CLI credential and the group policy allows `sts:AssumeRole` on `roleA` and `roleB`. In production, a person should instead sign in through IAM Identity Center and receive temporary role credentials. The group is not `AdministratorAccess`; administrative rights remain behind `roleA`.

## Why `engine` and `ci` do not get access keys

Although the assignment implementation can create long-lived keys to demonstrate the requested access type, I would not create them for either user in a real production environment.

An access key is a password that does not expire unless someone rotates it. It is copied into CI variables, laptops, and shell history. When it leaks, it works until it is found and deactivated. CloudTrail shows the access key id, which helps after the fact. It does not limit the blast radius before then.

`ci` is a pipeline identity. The modern replacement is GitHub Actions, GitLab CI, or Jenkins assuming a role with OIDC. The trust policy allows `token.actions.githubusercontent.com` (or the equivalent) and a condition on the repository and branch. Each job gets credentials that die with the job. There is no key to rotate and no key to commit.

`engine` is a person. The modern replacement is IAM Identity Center. The person signs in with the corporate identity provider and receives a role session. There is no long-lived access key on the production IAM user. If a break-glass user must exist, its key is stored securely, used rarely, and rotated. The optional keys in this Terraform exist only to demonstrate the assignment's requested access method and are disabled by default.

Enabling `aws_iam_access_key` puts the secret in the state file. That is a second copy of the credential, in the state bucket, for as long as state history keeps that version. This is why `create_access_keys` defaults to false and must not be enabled in a real production deployment.

## Why the trust is the two users, not the account

`roleA` and `roleB` trust `jagan` and `priya` by ARN.

Trusting `arn:aws:iam::ACCOUNT_A:root` means any principal in Account A that also has `sts:AssumeRole` on that role can assume it. Today that might be only the two users. Tomorrow someone attaches `sts:AssumeRole` on `*` to another user, or creates a role that can assume `roleA`, and the trust already allows it. The identity policy and the trust policy are different doors. Leaving the trust on the account root leaves one door open.

Trusting the group ARN does not work. IAM does not accept a group as a principal in a role trust policy. The group is how we grant `AssumeRole`. The trust is who is allowed to be granted it.

I did not trust `roleB` from every role in Account A. Only the two named users can become `roleB`.

## Why `roleC` trusts `roleB` and not Account A

`roleC` has one principal:

```text
arn:aws:iam::ACCOUNT_A:role/roleB
```

If the trust were `arn:aws:iam::ACCOUNT_A:root`, then any principal in Account A with `sts:AssumeRole` permission on `roleC` could assume it directly. `roleB` would no longer be the boundary. A user, a compromised CI key, or a future role in Account A could reach the bucket without passing through `roleB`.

Trusting `arn:aws:iam::ACCOUNT_A:user/roleB` is the bug in Task 5. `roleB` is a role. There is no user by that name. `AssumeRole` from the role does not match a user principal, so the call is denied. Even if someone later created a user named `roleB`, that user would match and the role would not. The principal type has to be the principal that actually calls.

The chain is deliberate. `jagan` assumes `roleB` in Account A. The session principal is `roleB`. That session assumes `roleC` in Account B. CloudTrail in Account B shows `roleB`, not the user, as the assumer. CloudTrail in Account A shows which user assumed `roleB`. Together the two logs name the person and the hop.

A broader trust was avoided because the bucket policy is `s3:*` on that bucket, including delete. The only thing that keeps every other principal in Account A away from that delete is the trust line.

## External ID

An external ID stops the confused deputy problem when a vendor account is trusted and the vendor could be tricked into assuming your role for someone else. Here the trusted principal is our own `roleB`. We control that role's identity policy. An external ID would be a shared string both sides must send, and it would not reduce who inside Account A can reach `roleB`. I did not add one.

## Residual risk on `roleA`

`Allow *` plus `Deny iam:*` is administrative access except IAM, which is what the brief asks for. It is not least privilege beyond that sentence.

What remains possible from `roleA`:

- Every non-IAM service, including organizations and account settings.
- `sts:AssumeRole` on other roles, if those roles trust this one.
- Creating resources that then use their own roles.

What is blocked: IAM users, keys, policies, and roles. The deny is explicit and evaluated with the allow. An allow of `iam:*` elsewhere on the same role does not override this deny. A permissions boundary or an SCP could still be added by the organization. This role does not pretend to be an SCP.

I did not also deny `organizations:*` or `account:*`. A reviewer can ask for that as a tighter reading. It would be a stricter policy than the sentence in the brief. The sentence is implemented as written, and this paragraph is the risk that comes with it.

## What I did not choose

One role with a trust of the whole account, and a condition on `aws:PrincipalArn`, can express the same two users. It is harder to read and easier to widen with a wildcard condition. Two explicit ARNs are obvious in review.

Permission sets in IAM Identity Center are the production shape for `jagan` and `priya`. This task still creates IAM users because the brief names users, groups, and roles. The notes say the users should not be the long-term control plane.
