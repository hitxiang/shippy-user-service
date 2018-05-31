```
 export GCP_PROJECT_ID=xxxxx
 export VERSION="$(TZ=Asia/Tokyo date +%Y%m%dt%H%M%S)-$(git rev-parse --short HEAD)" && echo $VERSION && cd -
 make ...
```