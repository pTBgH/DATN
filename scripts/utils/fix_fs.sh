cd src/storage_service/laravel_back 
docker build -f Dockerfile.production -t localhost:5000/job7189/storage-service:v2.7.8 . 
docker push localhost:5000/job7189/storage-service:v2.7.8
kubectl rollout restart deployment storage-service -n job7189-apps
echo "DONE!"
