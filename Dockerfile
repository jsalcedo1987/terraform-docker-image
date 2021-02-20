## Multi-steps docker build
## conftest + terraform + kubectl

## Conftest layer
FROM openpolicyagent/conftest:v0.22.0 as conftest
RUN apk add make bash

## Terraform layer
FROM  hashicorp/terraform:0.14.7 as terraform

## Main layer
FROM golang:alpine

COPY --from=conftest /usr/local/bin/conftest /usr/local/bin/conftest
COPY --from=terraform /bin/terraform /usr/local/bin/terraform

RUN apk add --update --no-cache \ 
    curl \
    git \ 
    bash \
    openssh \
    gettext \
    ansible \
    py-pip \
    make \
    py-netaddr &&\
pip install --upgrade pip\
    botocore \
    boto \
    awscli \
    boto3

RUN curl -LO https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl
RUN chmod +x ./kubectl
RUN mv ./kubectl /usr/local/bin
RUN curl -o aws-iam-authenticator https://amazon-eks.s3.us-west-2.amazonaws.com/1.17.9/2020-08-04/bin/linux/amd64/aws-iam-authenticator && chmod +x ./aws-iam-authenticator && \
mv ./aws-iam-authenticator /usr/local/bin

WORKDIR $GOPATH
ENTRYPOINT ["terraform"]
