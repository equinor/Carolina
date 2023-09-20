docker run -it quay.io/pypa/manylinux2014_x86_64 /bin/bash

docker cp build_boost.sh $(docker container ls | grep -v CONTAINER | cut -f 1 -d " "):/tmp/
docker cp build_dakota.sh $(docker container ls | grep -v CONTAINER | cut -f 1 -d " "):/tmp/
