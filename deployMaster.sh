#!/bin/bash
#Program:
#Deployment kubernetes
#Date:
#2022-06-10

#Variable
m_nodes="m1"
w_nodes="w1 w2"
export IP=`hostname -i`
namespace1="local-path-storage"
namespace2="metallb-system"
namespace3="ingress-nginx"
namespace4="quay"
namespace5="landlord"
namespace6="gf"

#Program
case $1 in
createMaster)

  for mlist in $m_nodes;
   do
    ssh $mlist 'sudo apk update'
    ssh $mlist 'sudo apk add kubeadm kubelet kubectl --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted'
    ssh $mlist 'sudo kubeadm init --service-cidr 10.98.0.0/24 --pod-network-cidr 10.244.0.0/16 --service-dns-domain=k8s.org --apiserver-advertise-address $IP'
    ssh $mlist 'sudo rc-update add kubelet default'
    ssh $mlist 'mkdir -p $HOME/.kube; sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config; sudo chown $(id -u):$(id -g) $HOME/.kube/config'
    ssh $mlist 'kubectl taint node m1 node-role.kubernetes.io/control-plane:NoSchedule-'
    ssh $mlist 'kubectl apply -f https://raw.githubusercontent.com/Happylasky/Kubernetes-yaml-file/main/kube-flannel.yml'
    echo -n "Prepare to reboot master node in"
    sleep 1;echo -n " 5 ";sleep 1;echo -n " 4 ";sleep 1;echo -n " 3 ";sleep 1;echo -n " 2 ";sleep 1;echo " 1 "
    echo "Master node rebooting...";sleep 3
    ssh $mlist 'sudo reboot'
   done
  ;;

createWorker)

  export JOIN=$(echo "sudo `kubeadm token create --print-join-command 2>/dev/null`")
  for wlist in $w_nodes;
   do
    ssh $wlist 'sudo apk update'
    ssh $wlist 'sudo apk add  kubeadm kubelet --update-cache --repository http://dl-3.alpinelinux.org/alpine/edge/testing/ --allow-untrusted'
    ssh $wlist 'sudo rc-update add kubelet default'
    ssh $wlist "$JOIN"
    echo -n "Prepare to reboot master node in"
    sleep 1;echo -n " 3 ";sleep 1;echo -n " 2 ";sleep 1;echo " 1 "
    echo "Worker node rebooting...";sleep 3
    ssh $wlist 'sudo reboot'
   done

  for mwlist in $m_nodes;
   do
    cat /etc/hosts | grep "192.168.153.220 quay.k8s.org"
    [ $? == 0 ] || ssh $mwlist 'echo "192.168.153.220 quay.k8s.org" | sudo tee -a /etc/hosts'
    kubectl label node w1 node-role.kubernetes.io/worker=; kubectl label node w2 node-role.kubernetes.io/worker=
    watch kubectl get pods -o wide -A
   done
  ;;

package)

  #local-path-storage
  kubectl apply -f https://raw.githubusercontent.com/Happylasky/Kubernetes-yaml-file/main/local-path-storage.yaml
  while true
   do 
    kubectl get pods -n $namespace1 | tail -n +2 | cut -b 51-57 | grep -v 'Running' &> /dev/null
    [ $? != 0 ] && break || clear
    echo -n "local-path-storage deploying"
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    clear
    continue
   done
  echo "local-path-storage deploy is done!";echo

  #metallb-system
  kubectl apply -f https://raw.githubusercontent.com/Happylasky/Kubernetes-yaml-file/main/metallb-namespace.yaml
  kubectl apply -f https://raw.githubusercontent.com/Happylasky/Kubernetes-yaml-file/main/metallb.yaml
  kubectl apply -f https://raw.githubusercontent.com/Happylasky/Kubernetes-yaml-file/main/metallb-ConfigMap.yaml
  while true
   do  
    kubectl get pods -n $namespace2 | tail -n +2 | cut -b 39-45 | grep -v 'Running' &> /dev/null
    [ $? != 0 ] && break || clear
    echo -n "metallb deploying"
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    clear
    continue
   done
  echo "metallb deploy is done!";echo

  #ingress-nginx
  kubectl apply -f https://raw.githubusercontent.com/Happylasky/Kubernetes-yaml-file/main/ingress-deploy.yaml
  while true
   do 
    kubectl get pods -n $namespace3 | tail -n +2 | cut -b 53-61 | grep -vE 'Running|Completed' &> /dev/null
    [ $? != 0 ] && break || clear
    echo -n "ingress-nginx deploying"
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    clear
    continue
   done
  echo "ingress-nginx deploy is done!";echo
  
  #quay
  kubectl create ns quay
  kubectl apply -f https://raw.githubusercontent.com/Happylasky/Kubernetes-yaml-file/main/quay.yaml
  while true
   do 
    kubectl get pods -n $namespace4 | tail -n +2 | cut -b 20-26 | grep -v 'Running' &> /dev/null
    [ $? != 0 ] && break || clear
    echo -n "Project Quay deploying"
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    clear
    continue
   done
  echo "Project Quay deploy is done!";echo
  ;;

landlord)
  
  #ns & configmap
  kubectl create ns landlord
  kubectl create -n landlord configmap kuser-conf --from-file /home/bigred/.kube/config
  
  #service
  kubectl apply -f https://raw.githubusercontent.com/Happylasky/Kubernetes-yaml-file/main/1-landlord-service.yaml
  while true
   do 
    kubectl get svc -n $namespace5 | tail -n +2 | cut -b 11-22 | grep -vE 'LoadBalancer|ClusterIP' &> /dev/null
    [ $? != 0 ] && break || clear
    echo -n "landlord service deploying"
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    clear
    continue
   done
  echo "landlord service is done!";echo
  
  #PVC
  kubectl apply -f https://raw.githubusercontent.com/Happylasky/Kubernetes-yaml-file/main/2-landlord-PVC.yaml
  while true
   do 
    kubectl get pvc -n $namespace5 | tail -n +2 | cut -b 11-17 | grep -v 'Pending' &> /dev/null
    [ $? != 0 ] && break || clear
    echo -n "landlord PVC deploying"
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    clear
    continue
   done
  echo "landlord PVC is done!";echo
  
  #gateway
  kubectl apply -f https://raw.githubusercontent.com/Happylasky/Kubernetes-yaml-file/main/3-landlord-gateway.yaml
  while true
   do 
    kubectl get pod -n $namespace5 | tail -n +2 | cut -b 36-42 | grep -v 'Running' &> /dev/null
    [ $? != 0 ] && break || clear
    echo -n "landlord gateway deploying"
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    clear
    continue
   done
  echo "landlord gateway is done!";echo

  #kuser
  kubectl apply -f https://raw.githubusercontent.com/Happylasky/Kubernetes-yaml-file/main/4-landlord-kuser.yaml
  while true
   do 
    kubectl get pod -n $namespace5 | tail -n +2 | cut -b 36-42 | grep -v 'Running' &> /dev/null
    [ $? != 0 ] && break || clear
    echo -n "landlord kuser deploying"
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    clear
    continue
   done
  echo "landlord kuser is done!";echo

  #logger
  kubectl apply -f https://raw.githubusercontent.com/Happylasky/Kubernetes-yaml-file/main/5-landlord-logger.yaml
  while true
   do 
    kubectl get pod -n $namespace5 | tail -n +2 | cut -b 36-42 | grep -v 'Running' &> /dev/null
    [ $? != 0 ] && break || clear
    echo -n "landlord logger deploying"
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    clear
    continue
   done
  echo "landlord logger is done!";echo

  #mariadb
  kubectl apply -f https://raw.githubusercontent.com/Happylasky/Kubernetes-yaml-file/main/6-landlord-mariadb.yaml
  while true
   do 
    kubectl get pod -n $namespace5 | tail -n +2 | cut -b 36-42 | grep -v 'Running' &> /dev/null
    [ $? != 0 ] && break || clear
    echo -n "landlord mariadb deploying"
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    clear
    continue
   done
  echo "landlord mariadb is done!";echo

  #tenant
  kubectl apply -f https://raw.githubusercontent.com/Happylasky/Kubernetes-yaml-file/main/7-landlord-tenant.yaml
  while true
   do 
    kubectl get pod -n $namespace5 | tail -n +2 | cut -b 36-42 | grep -v 'Running' &> /dev/null
    [ $? != 0 ] && break || clear
    echo -n "landlord tenant deploying"
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    clear
    continue
   done
  echo "landlord tenant is done!";echo

  #gf
  kubectl create ns gf
  kubectl apply -f https://web.flymks.com/grafana/v1/grafana.yaml
  while true
   do 
    kubectl get pod -n $namespace6 | tail -n +2 | cut -b 36-42 | grep -v 'Running' &> /dev/null
    [ $? != 0 ] && break || clear
    echo -n "grafana tenant deploying"
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    echo -n ".";sleep 0.5
    clear
    continue
   done
  echo "grafana tenant is done!";echo

  ;;

unpackage)

  #quay
  kubectl delete -f https://raw.githubusercontent.com/Happylasky/Kubernetes-yaml-file/main/quay.yaml
  
  #ingress-nginx
  kubectl delete -f https://raw.githubusercontent.com/Happylasky/Kubernetes-yaml-file/main/ingress-deploy.yaml
  
  #metallb-system
  kubectl delete -f https://raw.githubusercontent.com/Happylasky/Kubernetes-yaml-file/main/metallb-ConfigMap.yaml
  kubectl delete -f https://raw.githubusercontent.com/Happylasky/Kubernetes-yaml-file/main/metallb.yaml
  kubectl delete -f https://raw.githubusercontent.com/Happylasky/Kubernetes-yaml-file/main/metallb-namespace.yaml
  
  #local-path-storage
  kubectl delete -f https://raw.githubusercontent.com/Happylasky/Kubernetes-yaml-file/main/local-path-storage.yaml
  ;;

delete)

  for list in $m_nodes $w_nodes;
   do
    echo -e "y\n" | ssh $list 'sudo kubeadm reset'
    ssh $list 'sudo rc-update del kubelet default'
    ssh $list 'sudo rm -r /etc/kubernetes'
    ssh $list 'sudo podman rmi -a'
   done

  for list in $m_nodes;
   do
    sudo apk del kubeadm kubelet kubectl
    rm -r .kube
    sudo rm -r /etc/kubernetes
   done

  for list in $w_nodes;
   do
    ssh $list 'sudo apk del kubeadm kubelet'
   done
  ;;

images)

  for list in $m_nodes $w_nodes;
   do
    ssh $list 'sudo podman images'
   done

;;

rmi)

  for list in $m_nodes $w_nodes;
   do
    ssh $list 'sudo podman rmi -a'
   done

;;

*)

  echo "Please input parameter.";echo
  echo "createMaster: Deploy kubernetes master node."
  echo "createWorker: Deploy kubernetes worker node."
  echo "package: Download images & deploy basic service pods."
  echo "landlord: Download images & deploy landlord service pods."
  echo "images: Check cluster images."
  echo "rmi: Remove all unuse images on cluster."
  echo "delete: Remove all kubernetes file & packages.";echo

;;

esac
