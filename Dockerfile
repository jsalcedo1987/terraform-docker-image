# Multi-Stage builds require Docker Engine 17.05 or higher

# Build AWS provider
FROM ubuntu:xenial as builder

ARG AWS_PROVIDER_VERSION=2.51.0

ENV HOME /root
ENV GOPATH $HOME/go
ENV GOBIN $GOPATH/bin

RUN apt-get update &&\
    apt-get install -yqq software-properties-common \
                         git \
                         wget \
                         unzip \
                         build-essential &&\
    add-apt-repository ppa:longsleep/golang-backports &&\
    apt-get update &&\
    apt-get install -y golang &&\
    mkdir -p $GOPATH/src/github.com/terraform-providers &&\
    wget -O $HOME/terraform-provider-aws.zip https://github.com/terraform-providers/terraform-provider-aws/archive/v$AWS_PROVIDER_VERSION.zip &&\
    cd $GOPATH/src/github.com/terraform-providers/ &&\
    unzip $HOME/terraform-provider-aws.zip -d . &&\
    mv terraform-provider-aws-$AWS_PROVIDER_VERSION \
       terraform-provider-aws

WORKDIR $GOPATH/src/github.com/terraform-providers/terraform-provider-aws

# use binaries from specific installed version (1.12)
ENV PATH "$PATH:/usr/lib/go-1.12/bin"

RUN make build


# Build the actual image
FROM hashicorp/terraform:0.12.26

ARG AWS_PROVIDER_VERSION=2.51.0
ARG ANSIBLE_PROVISIONER_VERSION=2.3.3

ENV GOBIN /root/go/bin
ENV PATH $GOBIN:$PATH

RUN mkdir -p /root/.terraform.d/plugins

COPY --from=builder /root/go/bin/terraform-provider-aws $GOBIN/terraform-provider-aws_v$AWS_PROVIDER_VERSION

## Kubectl
RUN apk add curl
RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin

## Helm
RUN apk add --update --no-cache curl ca-certificates && \
    curl -L https://get.helm.sh/helm-v3.3.1-linux-amd64.tar.gz |tar xvz && \
    mv linux-amd64/helm /usr/bin/helm && \
    chmod +x /usr/bin/helm && \
    rm -rf linux-amd64 && \
    apk del curl && \
    rm -f /var/cache/apk/*

## Add bash
RUN apk update  && apk add bash

RUN wget -O /root/.terraform.d/plugins/terraform-provisioner-ansible_v$ANSIBLE_PROVISIONER_VERSION https://github.com/radekg/terraform-provisioner-ansible/releases/download/v${ANSIBLE_PROVISIONER_VERSION}/terraform-provisioner-ansible-linux-amd64_v${ANSIBLE_PROVISIONER_VERSION} &&\
    chmod +x $GOBIN/terraform-provider-aws_v$AWS_PROVIDER_VERSION &&\
    chmod +x /root/.terraform.d/plugins/terraform-provisioner-ansible_v$ANSIBLE_PROVISIONER_VERSION &&\
    apk add --update --no-cache \
        openssh \
        gettext \
        ansible \
        py-pip \
        py-netaddr &&\
    pip install --upgrade pip\
        botocore \
        boto \
        awscli \
        boto3 &&\
    rm -rf /var/cache/apk/* &&\
    mkdir -p /root/.ssh &&\
    chmod 0700 /root/.ssh &&\
    touch /root/.ssh/id_rsa_terraform &&\
    chmod 0600 /root/.ssh/id_rsa_terraform &&\
    echo "    IdentityFile /root/.ssh/id_rsa_terraform" >> /etc/ssh/ssh_config &&\
    mkdir -p /etc/ansible &&\
    chmod 0700 /etc/ansible
    
ENTRYPOINT ["/bin/sh", "-c"]