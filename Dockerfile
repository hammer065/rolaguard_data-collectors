FROM golang:1.20-buster AS build-stage

WORKDIR /app
COPY ./lorawanwrapper/utils/*.go ./

# Install go dependencies
RUN go env -w GO111MODULE=off
RUN go get -d ./...

# Compile go library
RUN go build -o /lorawanWrapper.so -buildmode=c-shared jsonUnmarshaler.go lorawanWrapper.go micGenerator.go sessionKeysGenerator.go


FROM python:3.7-slim-buster

# Set the working directory to /app
WORKDIR /root/app

# Upgrade setuptools in order to install latest chirpstack_api dependencies
COPY ./requirements.txt ./

RUN apt-get update && apt-get install -y libcurl4-nss-dev build-essential \
  && pip3 install --upgrade pip \
  && pip3 install --upgrade --trusted-host pypi.python.org --no-cache-dir --timeout 1900 -r requirements.txt \
  && apt-get autopurge -y build-essential \
  && apt-get clean autoclean \
  && apt-get autopurge -y \
  && rm -rf /var/lib/apt/lists/*

# https://stackoverflow.com/questions/71759248/importerror-cannot-import-name-builder-from-google-protobuf-internal
ADD 'https://raw.githubusercontent.com/protocolbuffers/protobuf/main/python/google/protobuf/internal/builder.py' /usr/local/lib/python3.6/site-packages/google/protobuf/internal/

ENV PYTHONPATH="/root/app"
COPY . .
COPY --from=build-stage /lorawanWrapper.so ./lorawanwrapper/utils/

CMD python3 auditing/datacollectors/Orchestrator.py
