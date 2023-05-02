FROM python:3.10-alpine
LABEL maintainer="Trayan Azarov <trayan.azarov@amikos.tech>"

ADD main.py /app/main.py
ADD requirements.txt /app/requirements.txt

RUN apk add build-base && \
    pip install -r /app/requirements.txt

WORKDIR /app
EXPOSE 8000
# RUN opentelemetry-bootstrap -a install
# ENTRYPOINT ["opentelemetry-instrument","python", "main.py"]
ENTRYPOINT ["python", "main.py"]
