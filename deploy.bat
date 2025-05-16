@echo off
setlocal

echo [1/5] 기존 Helm 릴리스 삭제 및 기존 리소스들 삭제
helm uninstall argocd -n argocd >nul 2>&1
helm uninstall argocd-image-updater -n argocd-image-updater >nul 2>&1
kubectl delete applications --all -n argocd
kubectl delete all --all -n default

echo [2/5] Helm repo 등록 및 업데이트
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo [3/5] Argo CD 설치 중...
helm upgrade --install argocd argo/argo-cd -n argocd -f argocd\values.yaml

echo [4/5] Image Updater 설치 중...
helm upgrade --install argocd-image-updater argo/argocd-image-updater -n argocd-image-updater -f image-updater\values.yaml

echo [5/5] Argo CD 루트 애플리케이션 등록 중...
kubectl apply -f root-app.yaml -n argocd

echo ✅ 모든 리소스 설치 및 ArgoCD 설정 완료!
kubectl get pods -n argocd
kubectl get pods -n argocd-image-updater

pause
endlocal
