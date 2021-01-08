FROM nvidia/cuda:11.0-cudnn8-runtime-ubuntu16.04

# Install basic utils
RUN rm -r /etc/apt/sources.list.d && apt-get clean \
 && apt update && apt-get install -y \
    curl \
    ca-certificates \
    sudo \
    git \
    bzip2 \
    libx11-6 \
    zsh \
 && rm -rf /var/lib/apt/lists/*
 
# Make a work dir
RUN mkdir /work
WORKDIR /work

# Install conda with Python & pip
ENV CONDA_AUTO_UPDATE_CONDA=false
ENV PATH=/miniconda/bin:$PATH
RUN curl -sLo ./miniconda.sh https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh \
 && chmod +x ./miniconda.sh \
 && ./miniconda.sh -b -p /miniconda \
 && rm ./miniconda.sh \
 && conda install -y python==3.8 pip \
 && conda clean -ya

# Install all basic python packages
RUN pip install -i https://pypi.tuna.tsinghua.edu.cn/simple pip -U \
 && pip config set global.index-url https://pypi.tuna.tsinghua.edu.cn/simple \
 && pip install --no-cache-dir \
    numpy pandas \
    matplotlib seaborn \
    jupyter \
    mysql-connector-python sqlalchemy
    
    
# Install pytorch
RUN pip install --no-cache-dir\
    torch==1.7.1+cu110 \
    torchvision==0.8.2+cu110 \
    torchaudio===0.7.2 \
    -f https://download.pytorch.org/whl/torch_stable.html
    
# Install tensorflow
RUN pip install --no-cache-dir\
    tensorflow==2.4.0

# Set password
# ENV JUPYTER_PASSWORD=""
RUN jupyter notebook --generate-config && \
     echo "c.NotebookApp.password='$(python -c "from notebook.auth import passwd; print(passwd('${JUPYTER_PASSWORD}'))" )'" >> \
     /root/.jupyter/jupyter_notebook_config.py

# Set the default command to start jupyter notebook
CMD ["jupyter", "notebook", "--allow-root", \
                            "--notebook-dir=.", \
                            "--ip=0.0.0.0", \
                            "--port=8888", \
                            "--no-browser"]