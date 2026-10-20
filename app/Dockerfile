FROM python:3.12-slim

WORKDIR /app

# Erst nur die Abhängigkeiten -> Docker kann diese Schicht cachen,
# solange sich requirements.txt nicht ändert. Builds werden viel schneller.
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .
COPY static/ static/

# Nie als root laufen lassen
USER nobody

EXPOSE 8000
# 1 Prozess mit 8 Threads. Mehr Leistung holen wir über mehr Pods, nicht über mehr Prozesse.
CMD ["gunicorn", "--bind", "0.0.0.0:8000", "--workers", "1", "--threads", "8", "--access-logfile", "-", "app:app"]

