@echo off
setlocal enabledelayedexpansion

echo [1/8] 기존 Helm 릴리스 및 리소스 삭제
helm uninstall argocd -n argocd >nul 2>&1
helm uninstall argocd-image-updater -n argocd >nul 2>&1
kubectl delete applications --all -n argocd >nul 2>&1
kubectl delete deploy -n default -l arch=outer >nul 2>&1
kubectl delete deploy -n default -l arch=inner >nul 2>&1
kubectl delete svc -n default -l arch=outer >nul 2>&1
kubectl delete svc -n default -l arch=inner >nul 2>&1

echo [2/8] Helm repo 등록 및 업데이트
helm repo add argo https://argoproj.github.io/argo-helm >nul 2>&1
helm repo update

echo [3/8] Argo CD 설치
helm upgrade --install argocd argo/argo-cd ^
  --namespace argocd ^
  --create-namespace ^
  --version 5.51.6 ^
  --set crds.install=true ^
  -f argocd/values.yaml

echo [대기] ArgoCD 설치 후 안정화 대기 (3분)

echo [4/8] ArgoCD Image Updater 설치
helm upgrade --install argocd-image-updater argo/argocd-image-updater ^
  --namespace argocd ^
  --create-namespace ^
  -f image-updater/values.yaml

echo [대기] Image Updater 설치 후 안정화 대기 (3분)
timeout /t 120 >nul

echo [5/8] 00-core (RabbitMQ/Redis) 배포
kubectl apply -f apps/00-core/application.yaml -n argocd

echo [대기] 00-core 배포 안정화 대기 (3분)
timeout /t 120 >nul

echo [6/8] 01-config (Config Server) 배포
kubectl apply -f apps/01-config/application.yaml -n argocd

echo [대기] 01-config 배포 안정화 대기 (3분)
timeout /t 120 >nul

echo [7/8] 02-discovery (Eureka) 배포
kubectl apply -f apps/02-discovery/application.yaml -n argocd

echo [대기] 02-discovery 배포 안정화 대기 (3분)
timeout /t 120 >nul

echo [8/8] 03-services (App of Apps) 배포
kubectl apply -f apps/03-services/application.yaml -n argocd

echo [대기] 03-services 배포 안정화 대기 (3분)

echo.
echo [🎉] 전체 배포 완료! 아래 상태를 확인하세요.
kubectl get applications -n argocd
kubectl get pods -n default

pause
endlocal
