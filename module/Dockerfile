FROM alpine

WORKDIR /app

RUN apk add --no-cache curl

COPY run.sh .

RUN chmod u+x /app/run.sh

ENTRYPOINT /app/run.sh


