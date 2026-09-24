#!/usr/bin/env bash
# A drill, not a gate: shows what IAM does and does not enforce on the local AWS (Floci), so the claims in ADR-0006 and
# ADR-0020 rest on evidence you can re-run. Read docs/guides/iam-policies-and-trust.md first. Needs the dev environment
# up (scripts/dev-up.ps1), Docker, the AWS CLI and Python. Leaves nothing behind.
#
#   1. A Floci with IAM enforcement ON (a throwaway on port 4577, not your environment): identity policies and
#      permission boundaries deny what they should.
#   2. Your Floci, a forged GitHub token against the project's real OIDC role: accepted. This is the known gap.
#   3. The throwaway, the same kind of token: rejected, because Floci cannot verify GitHub's signature.
#   4. Your Floci, IRSA: tokens Floci mints for the cluster's own OIDC issuer. The right service account is allowed,
#      another is denied by the trust policy's `sub` condition, and a tampered token fails its signature check.
set -uo pipefail
export AWS_PAGER="" AWS_DEFAULT_REGION=us-east-1 AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test

MAIN="--endpoint-url http://localhost:4566"
ENF="--endpoint-url http://127.0.0.1:4577"
CLUSTER="${CLUSTER:-yaaf-dev}"
FLOCI_IMAGE="floci/floci@sha256:f5aa8c18302cedb4f2385f5c4e455b3efc77fee6bf7b6e5d1712b2817ba102db" # keep in step with compose.yaml
work="$(mktemp -d)"
OP=""

cleanup() {
  aws $MAIN iam delete-role --role-name drill-irsa >/dev/null 2>&1
  [ -n "$OP" ] && aws $MAIN iam delete-open-id-connect-provider --open-id-connect-provider-arn "arn:aws:iam::000000000000:oidc-provider/$OP" >/dev/null 2>&1
  docker rm -f floci-iam-drill >/dev/null 2>&1
  rm -rf "$work"
}
trap cleanup EXIT

# The AWS CLI on Windows is a native program that cannot see Git Bash's /tmp, so hand it a Windows-style path.
fileuri() { if command -v cygpath >/dev/null 2>&1; then echo "file://$(cygpath -m "$1")"; else echo "file://$1"; fi; }
b64url() { python -c "import sys,base64; print(base64.urlsafe_b64encode(sys.stdin.buffer.read()).decode().rstrip('='))"; }
fake_jwt() { # $1 = issuer, $2 = subject; a well-formed token with a signature nobody can verify
  printf '%s.%s.%s' "$(printf '{"alg":"RS256","typ":"JWT"}' | b64url)" \
    "$(printf '{"iss":"%s","sub":"%s","aud":"sts.amazonaws.com","exp":4102444800}' "$1" "$2" | b64url)" \
    "$(printf 'not-a-real-signature' | b64url)"
}
result() { head -c 170 | tr '\n' ' '; echo; }
oidc_token() { curl -s -X POST "http://localhost:4566/_floci/eks/clusters/$CLUSTER/oidc-token" -H 'Content-Type: application/json' \
  -d "{\"namespace\":\"demo\",\"serviceAccount\":\"$1\"}" | python -c "import sys,json; print(json.load(sys.stdin)['token'])"; }

curl -sf http://localhost:4566/_floci/health >/dev/null || { echo "Your Floci is not running: run scripts/dev-up.ps1 first."; exit 1; }

echo "Starting a throwaway Floci with IAM enforcement on (port 4577)"
docker rm -f floci-iam-drill >/dev/null 2>&1
docker run -d --name floci-iam-drill -p 127.0.0.1:4577:4566 -e FLOCI_SERVICES_IAM_ENFORCEMENT_ENABLED=true "$FLOCI_IMAGE" >/dev/null || exit 1
for _ in $(seq 1 30); do curl -sf http://127.0.0.1:4577/_floci/health >/dev/null && break; sleep 2; done

adm() { aws $ENF "$@"; }
as() { # as <access-key> <secret> <aws args...>
  local k="$1" s="$2"; shift 2; AWS_ACCESS_KEY_ID="$k" AWS_SECRET_ACCESS_KEY="$s" aws $ENF "$@"; }
mkuser() { adm iam create-user --user-name "$1" >/dev/null; adm iam create-access-key --user-name "$1" --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text; }

echo
echo "1. Identity policies and permission boundaries (enforcement on)"
read -r AK SK < <(mkuser alice); adm s3 mb s3://drill-bucket >/dev/null
printf "   alice, no policy, list buckets:              "; as "$AK" "$SK" s3api list-buckets --query 'length(Buckets)' --output text 2>&1 | result
adm iam attach-user-policy --user-name alice --policy-arn arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
printf "   alice, S3 read-only, list buckets:           "; as "$AK" "$SK" s3api list-buckets --query 'length(Buckets)' --output text 2>&1 | result
printf "   alice, S3 read-only, make a bucket:          "; as "$AK" "$SK" s3 mb s3://alice-bucket 2>&1 | result
read -r BK BS < <(mkuser bob)
adm iam attach-user-policy --user-name bob --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
adm iam put-user-permissions-boundary --user-name bob --permissions-boundary arn:aws:iam::aws:policy/AmazonS3ReadOnlyAccess
printf "   bob, admin + S3 read-only boundary, S3 read: "; as "$BK" "$BS" s3api list-buckets --query 'length(Buckets)' --output text 2>&1 | result
printf "   bob, admin + S3 read-only boundary, IAM:     "; as "$BK" "$BS" iam create-user --user-name mallory 2>&1 | result

echo
echo "2. Your Floci: a forged GitHub token for another repository against the project's real role"
printf "   evil-org/evil-repo assumes yaaf-gha-tofu-apply: "
aws $MAIN sts assume-role-with-web-identity --role-arn arn:aws:iam::000000000000:role/yaaf-gha-tofu-apply --role-session-name drill-forged \
  --web-identity-token "$(fake_jwt https://token.actions.githubusercontent.com 'repo:evil-org/evil-repo:ref:refs/heads/main')" \
  --no-sign-request --query 'AssumedRoleUser.Arn' --output text 2>&1 | result

echo
echo "3. Enforcement on: a GitHub-style token, even with exactly the right claims"
adm iam create-open-id-connect-provider --url https://token.actions.githubusercontent.com --client-id-list sts.amazonaws.com >/dev/null 2>&1
cat > "$work/gh-trust.json" <<'EOF'
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Federated":"arn:aws:iam::000000000000:oidc-provider/token.actions.githubusercontent.com"},"Action":"sts:AssumeRoleWithWebIdentity","Condition":{"StringEquals":{"token.actions.githubusercontent.com:aud":"sts.amazonaws.com","token.actions.githubusercontent.com:sub":"repo:ya11so22/yaaf-project:ref:refs/heads/main"}}}]}
EOF
adm iam create-role --role-name drill-gh --assume-role-policy-document "$(fileuri "$work/gh-trust.json")" >/dev/null
printf "   the right repository and branch:              "
adm sts assume-role-with-web-identity --role-arn arn:aws:iam::000000000000:role/drill-gh --role-session-name drill-correct \
  --web-identity-token "$(fake_jwt https://token.actions.githubusercontent.com 'repo:ya11so22/yaaf-project:ref:refs/heads/main')" \
  --no-sign-request --query 'AssumedRoleUser.Arn' --output text 2>&1 | result

echo
echo "4. Your Floci: IRSA, with tokens Floci itself signs for the cluster's OIDC issuer"
ISS=$(aws $MAIN eks describe-cluster --name "$CLUSTER" --query cluster.identity.oidc.issuer --output text); OP=${ISS#https://}
aws $MAIN iam create-open-id-connect-provider --url "$ISS" --client-id-list sts.amazonaws.com >/dev/null 2>&1
cat > "$work/irsa-trust.json" <<EOF
{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Federated":"arn:aws:iam::000000000000:oidc-provider/$OP"},"Action":"sts:AssumeRoleWithWebIdentity","Condition":{"StringEquals":{"$OP:aud":"sts.amazonaws.com","$OP:sub":"system:serviceaccount:demo:allowed"}}}]}
EOF
aws $MAIN iam create-role --role-name drill-irsa --assume-role-policy-document "$(fileuri "$work/irsa-trust.json")" >/dev/null
for sa in allowed intruder; do
  printf "   service account demo/%-9s                   " "$sa"
  aws $MAIN sts assume-role-with-web-identity --role-arn arn:aws:iam::000000000000:role/drill-irsa --role-session-name "drill-$sa" \
    --web-identity-token "$(oidc_token "$sa")" --no-sign-request --query 'SubjectFromWebIdentityToken' --output text 2>&1 | result
done
tok="$(oidc_token intruder)"; sig="${tok##*.}"; hdr="${tok%%.*}"
forged="$hdr.$(printf '{"iss":"%s","sub":"system:serviceaccount:demo:allowed","aud":"sts.amazonaws.com","exp":4102444800}' "$ISS" | b64url).$sig"
printf "   intruder's token with its subject rewritten:  "
aws $MAIN sts assume-role-with-web-identity --role-arn arn:aws:iam::000000000000:role/drill-irsa --role-session-name drill-tampered \
  --web-identity-token "$forged" --no-sign-request --query 'SubjectFromWebIdentityToken' --output text 2>&1 | result

echo
echo "Done. Cleaning up (throwaway Floci, test role and OIDC provider)."
