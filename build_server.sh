#!/bin/bash
# @Author: Han
# @Date:   2021-01-08 11:20:44
# @Last Modified by:   Jimin Han
# @Last Modified time: 2021-01-08 23:52:33

# TODO: server settings
# export JIMIN_WORK_DIR=
# export JIMIN_DATA_DIR=
# export JIMIN_PASSWORD=
# export JIMIN_TUNNEL_SERVER=
# export JIMIN_CONSOLE_PORT=
# export JIMIN_COMPUTE_PORT=
# export JIMIN_DATABASE_PORT=

# ssh related
export JIMIN_PORTS=($JIMIN_CONSOLE_PORT $JIMIN_COMPUTE_PORT $JIMIN_DATABASE_PORT)
alias ssh_auto="autossh -M 0 -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -fCN"

show_tunnel(){
     ps ux | grep ssh | grep -v "grep"
}

kill_tunnel(){
     show_tunnel | tr -s ' '| cut -d ' ' -f 2 | uniq | xargs kill -9
}

build_tunnel(){
    kill_tunnel
    for port in ${JIMIN_PORTS[@]}; do
        ssh_auto -R ${port}:localhost:${port} ${JIMIN_TUNNEL_SERVER}
    done
}

# jupyter related
export JIMIN_CONDA_NAME="jimin_conda"

run_jupyter(){
    # install conda and create environment
    curl -Lo ${JIMIN_WORK_DIR}/miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
    chmod +x ${JIMIN_WORK_DIR}/miniconda.sh
    ${JIMIN_WORK_DIR}/miniconda.sh -b -p ${JIMIN_WORK_DIR}/miniconda
    ${JIMIN_WORK_DIR}/miniconda/bin/conda init bash
    source ~/.bashrc
    rm ${JIMIN_WORK_DIR}/miniconda.sh
    conda create -y -n ${JIMIN_CONDA_NAME} python=3.8
    source activate ${JIMIN_CONDA_NAME}

    # install jupyter and run server
    pip install -i https://pypi.tuna.tsinghua.edu.cn/simple pip -U
    pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple
    pip install jupyter

    JIMIN_KEY=$(python -c "from notebook.auth import passwd; print(passwd('${JIMIN_PASSWORD}'))")
    nohup jupyter notebook --allow-root \
                     --NotebookApp.password=${JIMIN_KEY} \
                     --port=${JIMIN_CONSOLE_PORT} \
                     --ip=0.0.0.0 \
                     --notebook-dir=${JIMIN_WORK_DIR} \
                     --no-browser &
}

# docker related
export JIMIN_DOCKER_NETWOEK="jimin_network"
export JIMIN_DATABASE_NAME="jimin_database"
export JIMIN_COMPUTE_NAME="jimin_compute"
export JIMIN_COMPUTE_IMAGE="jimin/compute"

alias docker='sudo docker'

docker_build_compute(){
    docker build -t ${JIMIN_COMPUTE_IMAGE} -f ${JIMIN_WORK_DIR}/ServerConfig/Dockerfile
}

docker_run_database(){
    mkdir -p ${JIMIN_DATA_DIR}/mysql
    docker run -d --restart=always \
               --name ${JIMIN_DATABASE_NAME} \
               -p ${JIMIN_DATABASE_PORT}:3306 \
               -v ${JIMIN_DATA_DIR}/mysql:/var/lib/mysql \
               -e MYSQL_ROOT_HOST=% \
               -e MYSQL_ROOT_PASSWORD=${JIMIN_PASSWORD} \
               --net ${JIMIN_DOCKER_NETWOEK} \
               mysql/mysql-server:latest
}

docker_run_compute(){
    docker run -d --restart=always --gpus all \
               --name ${JIMIN_COMPUTE_NAME} \
               -p ${JIMIN_COMPUTE_PORT}:8888 \
               -v ${JIMIN_WORK_DIR}:/work \
               --net ${JIMIN_DOCKER_NETWOEK} \
               ${JIMIN_COMPUTE_IMAGE}
}

docker_run_all(){
    docker network create ${JIMIN_DOCKER_NETWOEK}
    docker_run_compute
    docker_run_database
}

alias docker_bash_database="docker exec -it ${JIMIN_DATABASE_NAME} /bin/bash"
alias docker_log_database="docker logs ${JIMIN_DATABASE_NAME}"
alias docker_rm_database="docker stop ${JIMIN_DATABASE_NAME} && docker rm ${JIMIN_DATABASE_NAME}"

alias docker_bash_compute="docker exec -it ${JIMIN_COMPUTE_NAME} /bin/bash"
alias docker_log_compute="docker logs ${JIMIN_COMPUTE_NAME}"
alias docker_rm_compute="docker stop ${JIMIN_COMPUTE_NAME} && docker rm ${JIMIN_COMPUTE_NAME}"

alias docker_rm_all="docker_rm_database && docker_rm_compute"

# set up everything
build_all(){
  # maybe get input from keyboard
  echo "build tunnel...\n" && build_tunnel
  echo "run jupyter...\n" && run_jupyter 
  echo "build docker image...\n" && docker_build_compute
  echo "run docker servers...\n" && docker_run_all
}