# Nodes Network
ifconfig
kubectl get nodes -o wide

# Pods Network
vi calico.yaml
# Check for "CALICO_IPV4POOL_CIDR"

# Create a test web app which run on port 8080
kubectl get all
kubectl create deployment hello-world --image=gcr.io/google-samples/hello-app:1.0
kubectl get pods -o wide
kubectl scale --replicas=3 deployment.apps/hello-world
kubectl get pods -o wide

# Check connectivity between nodes and pods
ping $Pod1_IP

# Check connectivity between pods
kubectl exec -it $POD1_Name -- /bin/sh
ip addr
ping $POD2_IP
ping $Master
exit

# Check the tunnel interface on nodes
route
ifconfig tunl0

# Try access the app directly
curl http://$pod1_IP
curl http://$pod1_IP:8080
curl http://$pod2_IP:8080
curl http://$pod3_IP:8080

# "Service" is the entry point of app
# ClusterIP type
kubectl expose deployment hello-world --port=80 --target-port=8080 --type ClusterIP
# Check "CLUSTER-IP"
kubectl get service
curl http://$ServiceIP
curl http://$ServiceIP:8080

# Check Service LB
curl http://$ServiceIP
curl http://$ServiceIP
curl http://$ServiceIP

# Where is the ClusterIP?
# kubeproxy(Control) + iptables(Data)

# Whatif a Node does not have a Pod?
kubectl scale --replicas=2 deployment.apps/hello-world
kubectl get pods -o wide
kubectl get nodes -o wide

# On Node with pod
curl http://$ServiceIP

# On Node without pod
curl http://$ServiceIP

# How can we access the app externally?
# NodePort type
kubectl delete service hello-world
kubectl expose deployment hello-world --port=80 --target-port=8080 --type NodePort
# Check "PORT(S)"
kubectl get service
kubectl get node -o wide

curl http://$Node1_IP
curl http://$Node1_IP:$NodePort
curl http://$Node2_IP:$NodePort
curl http://$Node3_IP:$NodePort
curl http://$Master_IP:$NodePort

# Will it LB?
curl http://$Node1_IP:$NodePort
curl http://$Node1_IP:$NodePort
curl http://$Node1_IP:$NodePort

############################
# LoadBalancer/Ingress type
############################

# Prepare the ADC
# If in AWS, use Citrix ADC VPX Express - 20 Mbps, t2.medium
add system user cic mypassword
bind system user cic superuser 0
add ns ip 172.16.1.54 255.255.255.0 -type SNIP
# If you are in a cloud environment, add SNIP and VIP in cloud IP Management so cloud network will allow the traffic in/out for the IPs.

# On K8s Master
# Create a secret which store the ADC login credential
kubectl create secret  generic nslogin --from-literal=username='cic' --from-literal=password='mypassword'
# Get the CIC deployment yaml file
wget  https://raw.githubusercontent.com/citrix/citrix-k8s-ingress-controller/master/deployment/baremetal/citrix-k8s-ingress-controller.yaml
vi ./citrix-k8s-ingress-controller.yaml
# Change NS_IP
# Change NS_USER and NS_PASSWORD to use the secret created before
# Check the "--ingress-classes" arg

kubectl create -f citrix-k8s-ingress-controller.yaml
kubectl get pods
kubectl describe pod cic-k8s-ingress-controller-xxx

# Create a Ingress
kubectl apply -f hello-world-ingress.yaml
kubectl get ingress

# On Master
curl http://$NS_VIP
curl http://$NS_VIP --header 'Host: www.hello.com'
curl http://www.hello.com:80/ --resolve www.hello.com:80:$NS_VIP

# Check LB
curl http://$NS_VIP --header 'Host: www.hello.com'
curl http://$NS_VIP --header 'Host: www.hello.com'
curl http://$NS_VIP --header 'Host: www.hello.com'

# How traffice goes? N-S? E-W?
# Scale App down
kubectl scale --replicas=2 deployment.apps/hello-world
# Check NS ServiceGroup
show run | grep k8s

# Scale App up
kubectl scale --replicas=3 deployment.apps/hello-world
show run | grep k8s

# ADC will do LB for N-S trffice, will Kubernets Service do E-W LB as well?
# Let's try unbind serviceGroup manually on ADC
unbind serviceGroup ...

# Let's try namebased
kubectl delete ingress hello-world-ingress
show ns runningConfig | grep k8s

# Add another App
kubectl create deployment foobar --image=k8s.gcr.io/echoserver:1.4
kubectl scale --replicas=3 deployment.apps/foobar
kubectl expose deployment foobar --port=80 --target-port=8080 --type NodePort

kubectl apply -f namebased-ingress.yaml
show ns runningConfig | grep k8s

curl http://$NS_VIP --header 'Host: www.hello.com'
curl http://$NS_VIP --header 'Host: www.foobar.com'

# Let's try pathbased
kubectl delete ingress namebased-ingress
kubectl apply -f pathbased-ingress.yaml

curl http://$NS_VIP/world --header 'Host: www.hello.com'
curl http://$NS_VIP/foobar --header 'Host: www.hello.com'

##########################
# 2-Tier Deployment
##########################
# Create a namespace for the environment
kubectl create namespace hello
kubectl create namespace foobar

# Create backend http server pods
kubectl create deployment hello-world --image=gcr.io/google-samples/hello-app:1.0 -n hello
kubectl scale --replicas=2 deployment.apps/hello-world -n hello
kubectl get pods -n hello -o wide
kubectl get deployment -n hello -o wide

kubectl create deployment foobar --image=k8s.gcr.io/echoserver:1.4 -n foobar
kubectl scale --replicas=2 deployment.apps/foobar -n foobar
kubectl get pods -n foobar -o wide
kubectl get deployment -n foobar -o wide

# expose as Headless Services
kubectl apply -f headlessHTTPService-hello.yaml -n hello
kubectl get service -n hello

kubectl apply -f headlessHTTPService-foobar.yaml -n foobar
kubectl get service -n foobar

# Let's first deploy the 2nd tier CPX
# create rbac account for cpx
kubectl apply -f rbac-cpx-hello.yaml -n hello
kubectl get serviceaccount -n hello

kubectl apply -f rbac-cpx-foobar.yaml -n foobar
kubectl get serviceaccount -n foobar

# Create a secret for storing the CPX login credential
kubectl create secret generic nslogin --from-literal=username='nsroot' --from-literal=password='nsroot' -n hello
kubectl create secret generic nslogin --from-literal=username='nsroot' --from-literal=password='nsroot' -n foobar

# create cpx with cic as a sidecar and expose as a service
# Port 80 will be exposed to get inbound traffic
kubectl apply -f cpx-cic-2tier-hello.yaml -n hello
kubectl get pods -o wide -n hello
kubectl get deployment -n hello
kubectl get service -n hello

kubectl apply -f cpx-cic-2tier-foobar.yaml -n foobar
kubectl get pods -n foobar
kubectl get deployment -n foobar
kubectl get service -n foobar

# login to cpx and check the config
kubectl exec -n hello -it cpx-cic-hello-[string] -- bash
cli_script.sh "show ns run"
cli_script.sh "show ns run" | grep k8s
exit

# create the ingress object
kubectl apply -f ingress-2tier-hello.yaml -n hello
kubectl get ingress -n hello

kubectl apply -f ingress-2tier-foobar.yaml -n foobar
kubectl get ingress -n foobar

# check the ingress
# you will see backend http server listed in "Backends"
kubectl describe ingress ingress-2tier-hello -n hello
kubectl describe ingress ingress-2tier-foobar -n foobar

# Check the CPX configuration
kubectl exec -n hello -it cpx-cic-hello-[string] -- bash
cli_script.sh "show ns run" | grep k8s
exit

# Access CPX lb service
kubectl get pods -n hello -o wide
CPX_POD_IP=`kubectl get pods -n hello -o wide | grep cpx-cic | awk '{ print $6 }'`
curl http://$CPX_POD_IP --header 'Host: www.hello.com'
kubectl get service -n hello -o wide
CPX_Cluster_IP=`kubectl get service -n hello -o wide | grep cpx-cic | awk '{ print $3 }'`
curl http://$CPX_Cluster_IP --header 'Host: www.hello.com'
kubectl get nodes -o wide
curl http://$CPX_NODE_IP:NODEPORT --header 'Host: www.hello.com'

kubectl get pods -n foobar -o wide
CPX_POD_IP=`kubectl get pods -n foobar -o wide | grep cpx-cic | awk '{ print $6 }'`
curl http://$CPX_POD_IP --header 'Host: www.foobar.com'
kubectl get service -n foobar -o wide
CPX_Cluster_IP=`kubectl get service -n foobar -o wide | grep cpx-cic | awk '{ print $3 }'`
curl http://$CPX_Cluster_IP --header 'Host: www.foobar.com'
kubectl get nodes -o wide
curl http://$CPX_NODE_IP:NODEPORT --header 'Host: www.foobar.com'

# Examing LB, try curl several times, you will see CPX is doing the LB

#
# Tier 2 DONE!
#
# Now 2nd tier is ready, let's move to 1st tier VPX/CIC
# We will deploy CICs in both of the namespace to control the tier1 VPX
# Prepare VPX, same as before.
add system user cic mypassword
bind system user cic superuser 0
add ns ip 172.16.1.54 255.255.255.0 -type SNIP

# Back to Master
# create the secret for tier1 VPX in namespace
kubectl create secret  generic nslogin-vpx --from-literal=username='cic' --from-literal=password='mypassword' -n hello
kubectl create secret  generic nslogin-vpx --from-literal=username='cic' --from-literal=password='mypassword' -n foobar

# Deploy the 1st-tier CIC
kubectl apply -f cic-1tier-hello.yaml -n hello
kubectl get pods -n hello

kubectl apply -f cic-1tier-foobar.yaml -n foobar
kubectl get pods -n foobar

# Create the 1st-tier Ingress object
kubectl apply -f ingress-1tier-hello.yaml -n hello
kubectl get ingress -n hello

kubectl apply -f ingress-1tier-foobar.yaml -n foobar
kubectl get ingress -n foobar

# Access the 1st-tier VPX VIP
curl http://$VPX_VIP_HELLO --header 'Host: www.hello.com'
curl http://$VPX_VIP_FOOBAR --header 'Host: www.foobar.com'

# Congratulations! Well Done!