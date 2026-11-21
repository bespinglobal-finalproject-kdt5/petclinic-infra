# Private management path (aws-prod)

The management route table peers only to the two app subnet CIDRs. The app table returns traffic to the management subnet via that peer and keeps its NAT default. Neither the public nor DB tier has a peer route. Management has no internet default or inbound EC2 rule. Both VPCs use Amazon-provided DNS.

The root provisions `ssm`, `ssmmessages`, `eks` and regional `sts` interface endpoints in management. These are AWS service APIs; `kubectl` instead uses the **cluster-specific hostname**, which resolves to private addresses in the app subnets. The management SG allows TCP 443 to the endpoint SG and, across the peer, to the EKS cluster SG. There is no SSH key or SSH rule.

## Bootstrap after an approved apply

1. Use the same IAM principal that created the cluster (including re-assuming the apply role if necessary). EKS grants this principal bootstrap admin via an API access entry. Separately authorize the operator to describe the cluster and start an SSM session on this instance with the remote-host forwarding document; grant data-channel and session lifecycle permissions for their own session. Don't grant the management instance role those operator privileges.
2. On the operator workstation, use AWS CLI v2, the Session Manager plugin, and a compatible `kubectl`. Set `INSTANCE_ID` to the ID of `aws_instance.management`; confirm the AL2023 SSM agent is Online. Open a tunnel and leave it running:

   ```sh
   export AWS_REGION=ap-northeast-2
   api=$(aws eks describe-cluster --name petclinic-prod --query cluster.endpoint --output text)
   aws ssm start-session --target "$INSTANCE_ID" \
     --document-name AWS-StartPortForwardingSessionToRemoteHost \
     --parameters "host=${api#https://},portNumber=443,localPortNumber=8443"
   ```

3. In another terminal with the same AWS identity, use a temporary kubeconfig. Keep the EKS CA and set TLS SNI to the real API hostname; **do not disable certificate verification**. This authenticates as the local operator, not as EC2.

   ```sh
   export AWS_REGION=ap-northeast-2
   api=$(aws eks describe-cluster --name petclinic-prod --query cluster.endpoint --output text)
   tmpdir=$(mktemp -d); export KUBECONFIG="$tmpdir/config"
   aws eks update-kubeconfig --name petclinic-prod --kubeconfig "$KUBECONFIG"
   cluster=$(kubectl config view --minify -o jsonpath='{.contexts[0].context.cluster}')
   kubectl config set-cluster "$cluster" --server=https://127.0.0.1:8443 --tls-server-name="${api#https://}"
   kubectl get nodes -L topology.kubernetes.io/zone
   kubectl create namespace petclinic --dry-run=client -o yaml | kubectl apply -f -
   ```

4. Confirm two Ready nodes and healthy `kube-system` pods. Test a separately approved recovery administrator before removing bootstrap access. Close the tunnel and remove the temporary kubeconfig when finished. A single multi-AZ node group does not guarantee exactly one node per AZ.
5. For routine deployments **on EC2**, stage a checksum-verified Linux x86-64 `kubectl` via an approved offline transfer or pre-baked AL2023 image; the stock instance does not download it on boot. In an authorized SSM shell use regional AWS endpoints, `aws eks update-kubeconfig --region ap-northeast-2 --name petclinic-prod`, and `kubectl -n petclinic …`. Check `kubectl auth can-i create deployments -n petclinic` (yes) and `kubectl auth can-i create namespaces` (no). The instance role has namespace-scoped Edit, not cluster admin. Keep privileged workloads and service accounts out of this namespace.
