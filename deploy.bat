@echo off
setlocal enabledelayedexpansion

:: Wait for pod to become Ready by label
:wait_for_ready
set APP_LABEL=%1
set TIMEOUT=%2

kubectl wait --for=condition=ready pod -l app=%APP_LABEL% --timeout=%TIMEOUT% || (
  echo [ERROR] %APP_LABEL% Ready timeout exceeded (%TIMEOUT%)
  exit /b 1
)
echo [✓] %APP_LABEL% is ready.
goto :eof

:: ============================ START ============================

:: [1] 기존 리소스 삭제
helm uninstall argocd -n argocd >nul 2>&1
helm uninstall argocd-image-updater -n argocd-image-updater >nul 2>&1
kubectl delete applications --all -n argocd
kubectl delete deploy -n default -l app >nul 2>&1
kubectl delete svc -n default -l app >nul 2>&1

:: [2] Helm repo 등록 및 업데이트
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

:: [3] Argo CD 설치
helm upgrade --install argocd argo/argo-cd ^
  --namespace argocd ^
  --create-namespace ^
  --version 5.51.6 ^
  --set crds.install=true ^
  -f argocd/values.yaml

:: [3.5] CRD 재적용
kubectl apply -k https://github.com/argoproj/argo-cd//manifests/crds?ref=v3.0.1

:: [3.6] ArgoCD 컨트롤러 재시작
kubectl rollout restart statefulset argocd-application-controller -n argocd
kubectl rollout restart deployment argocd-repo-server -n argocd
kubectl rollout restart deployment argocd-server -n argocd

:: [4] Image Updater 설치
helm upgrade --install argocd-image-updater argo/argocd-image-updater ^
  --namespace argocd-image-updater ^
  --create-namespace ^
  -f image-updater/values.yaml

:: [5] 00-core 배포 및 상태 확인
kubectl apply -f apps/00-core/application.yaml -n argocd
call :wait_for_ready rabbitmq 90s

:: [6] 01-config 배포 및 상태 확인
kubectl apply -f apps/01-config/application.yaml -n argocd
call :wait_for_ready config-server 90s

:: [7] 02-discovery 배포 및 상태 확인
kubectl apply -f apps/02-discovery/application.yaml -n argocd
call :wait_for_ready service-discovery 90s

:: [8] 03-services 배포 (App of Apps)
kubectl apply -f apps/03-services/application.yaml -n argocd

:: [✅ 완료]
echo.
echo [🎉] 전체 배포 완료! ArgoCD 및 EKS에서 상태를 확인하세요.
kubectl get applications -n argocd
kubectl get pods -n default

pause
endlocal
