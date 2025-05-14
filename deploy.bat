@echo off
setlocal

echo [1/4] 기존 Helm 릴리스 삭제
helm uninstall argocd -n argocd >nul 2>&1
helm uninstall argocd-image-updater -n argocd-image-updater >nul 2>&1

echo [2/4] Helm repo 등록 및 업데이트
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update

echo [3/4] Argo CD 설치 중...
helm upgrade --install argocd argo/argo-cd -n argocd -f argocd\values.yaml

echo [4/4] Image Updater 설치 중...
helm upgrade --install argocd-image-updater argo/argocd-image-updater -n argocd-image-updater -f image-updater\values.yaml

echo ✅ 모든 리소스 설치 완료!
kubectl get pods -n argocd
kubectl get pods -n argocd-image-updater

pause
endlocal
