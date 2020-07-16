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

# LoadBalancer/Ingress type
#
# Prepare the ADC
add system user cic mypassword
bind system user cic superuser 0
add ns ip 172.16.x.x 255.255.255.0 -type SNIP

# On K8s Master
kubectl create secret  generic nslogin --from-literal=username='cic' --from-literal=password='mypassword'
wget  https://raw.githubusercontent.com/citrix/citrix-k8s-ingress-controller/master/deployment/baremetal/citrix-k8s-ingress-controller.yaml
vi ./citrix-k8s-ingress-controller.yaml
# Change NS_IP
# Change NS_USER and NS_PASSWORD to use the secret created before

kubectl create -f citrix-k8s-ingress-controller.yaml
kubectl get pods
kubectl describe pod cic-k8s-ingress-controller-xxx

# Create a Ingress Controller
kubectl apply -f hello-world-ingress.yaml
kubectl get ingress

# On Master
curl http://$NS_VIP
curl http://$NS_VIP --header 'Host: www.hello.com'
curl http://www.hello.com:80/ --resolve www.hello.com:80:$NS_VIP

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
