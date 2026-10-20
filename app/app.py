import os
import socket
import time

import psycopg
from flask import Flask, Response, jsonify, request, send_from_directory
from prometheus_client import CONTENT_TYPE_LATEST, Counter, Histogram, generate_latest

POD = socket.gethostname()                    # in Kubernetes = Name des Pods
KNOTEN = os.environ.get("KNOTEN", "lokal")    # setzt Kubernetes (siehe Deployment)

app = Flask(__name__)

# --- Eigene Messwerte für Prometheus/Grafana ---
RUNDEN = Counter("spiel_runden", "Gespeicherte Spielrunden")
REAKTION = Histogram(
    "spiel_reaktionszeit_ms",
    "Reaktionszeiten in Millisekunden",
    buckets=(150, 200, 250, 300, 350, 400, 500, 750, 1000),
)


def verbindung():
    # Ohne Parameter liest psycopg die Standard-Variablen PGHOST, PGUSER, PGPASSWORD, PGDATABASE
    return psycopg.connect(connect_timeout=3)


def tabelle_anlegen():
    """Beim Start warten, bis die Datenbank da ist, dann die Tabelle anlegen."""
    for _ in range(60):
        try:
            with verbindung() as conn:
                conn.execute(
                    """CREATE TABLE IF NOT EXISTS ergebnisse (
                           id     serial PRIMARY KEY,
                           name   text        NOT NULL,
                           ms     integer     NOT NULL,
                           pod    text        NOT NULL,
                           knoten text        NOT NULL,
                           zeit   timestamptz NOT NULL DEFAULT now())"""
                )
            print("Datenbank bereit", flush=True)
            return
        except psycopg.OperationalError as fehler:
            print(f"Warte auf Datenbank: {fehler}", flush=True)
            time.sleep(3)
    raise SystemExit("Keine Verbindung zur Datenbank")


@app.get("/")
def startseite():
    return send_from_directory("static", "index.html")


@app.get("/api/info")
def info():
    return jsonify(pod=POD, knoten=KNOTEN)


@app.get("/api/highscores")
def highscores():
    with verbindung() as conn:
        zeilen = conn.execute(
            "SELECT name, ms, knoten FROM ergebnisse ORDER BY ms LIMIT 10"
        ).fetchall()
    return jsonify([{"name": n, "ms": ms, "knoten": k} for n, ms, k in zeilen])


@app.post("/api/score")
def score():
    daten = request.get_json(silent=True) or {}
    name = str(daten.get("name", "")).strip()[:20]
    try:
        ms = int(daten.get("ms"))
    except (TypeError, ValueError):
        return jsonify(fehler="Zeit fehlt"), 400
    if not name or not 80 <= ms <= 5000:      # unter 80 ms ist kein Mensch -> geschummelt
        return jsonify(fehler="Ungültiges Ergebnis"), 400

    with verbindung() as conn:
        conn.execute(
            "INSERT INTO ergebnisse (name, ms, pod, knoten) VALUES (%s, %s, %s, %s)",
            (name, ms, POD, KNOTEN),
        )
        platz = conn.execute(
            "SELECT count(*) + 1 FROM ergebnisse WHERE ms < %s", (ms,)
        ).fetchone()[0]

    RUNDEN.inc()
    REAKTION.observe(ms)
    return jsonify(platz=platz, pod=POD, knoten=KNOTEN)


@app.get("/health")
def health():
    return "ok"


@app.get("/metrics")
def metrics():
    return Response(generate_latest(), content_type=CONTENT_TYPE_LATEST)


tabelle_anlegen()

