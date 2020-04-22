FROM ubuntu

WORKDIR /app

RUN apt-get update && apt-get install -y curl

COPY run.sh .

RUN chmod u+x /app/run.sh

ENTRYPOINT /app/run.sh


