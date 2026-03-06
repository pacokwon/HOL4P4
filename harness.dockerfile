FROM ubuntu:22.04
LABEL description="This is a docker image for HOL4P4"
ARG DEBIAN_FRONTEND=noninteractive
ENV DEBCONF_NOWARNINGS="yes"
USER root

# Version without git
COPY . /HOL4P4

# This lets us use the same installation scripts
RUN apt update && apt-get install -y -q sudo

# Then, just run the regular install script
RUN ./HOL4P4/scripts/install.sh
WORKDIR /HOL4P4/hol/p4_from_json

# Copy additional include headers used by test suite
COPY p4include/ /HOL4P4/hol/p4_from_json/p4include/

# Test compilation
#RUN export PATH=$PATH:/HOL4P4/HOL/bin && opam exec -- make hol

ENTRYPOINT ["/bin/bash", "--login"]
