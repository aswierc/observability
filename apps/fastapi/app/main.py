from __future__ import annotations

import logging
import os
import time

import requests
from fastapi import FastAPI, Response
from opentelemetry import propagate, trace
from opentelemetry.trace import SpanKind, Status, StatusCode

from .otel import get_request_histogram, setup_otel


logger = logging.getLogger("fastapi-app")
tracer = trace.get_tracer("fastapi-app", "0.1.0")

app = FastAPI(title="fastapi-observability")
setup_otel(app)
request_duration = get_request_histogram()


@app.middleware("http")
async def duration_middleware(request, call_next):
    start = time.perf_counter()
    ctx = propagate.extract(dict(request.headers))

    with tracer.start_as_current_span(
        f"{request.method} {request.url.path}",
        context=ctx,
        kind=SpanKind.SERVER,
    ) as span:
        span.set_attribute("http.method", request.method)
        span.set_attribute("http.route", request.url.path)
        span.set_attribute("url.path", request.url.path)

        try:
            response: Response = await call_next(request)
        except Exception as e:
            span.record_exception(e)
            span.set_status(Status(StatusCode.ERROR))
            raise
        finally:
            duration_ms = (time.perf_counter() - start) * 1000.0
            request_duration.record(
                duration_ms,
                attributes={
                    "http.method": request.method,
                    "http.route": request.url.path,
                    "http.status_code": str(getattr(locals().get("response", None), "status_code", 500)),
                },
            )

        span.set_attribute("http.status_code", response.status_code)
        return response


@app.get("/health")
def health():
    return {"ok": True}


@app.get("/sleep")
def sleep(ms: int = 200):
    time.sleep(ms / 1000.0)
    logger.info("slept", extra={"sleep_ms": ms})
    return {"slept_ms": ms}


@app.get("/chain")
def chain(ms: int = 200):
    downstream = os.getenv("DOWNSTREAM_URL", "").strip()
    if not downstream:
        time.sleep(ms / 1000.0)
        logger.info("chain-no-downstream", extra={"sleep_ms": ms})
        return {"slept_ms": ms, "downstream": None}

    url = downstream.rstrip("/") + "/sleep"
    headers: dict[str, str] = {}
    propagate.inject(headers)

    with tracer.start_as_current_span("HTTP GET downstream /sleep", kind=SpanKind.CLIENT) as span:
        span.set_attribute("http.url", url)
        span.set_attribute("sleep_ms", ms)
        r = requests.get(url, params={"ms": ms}, headers=headers, timeout=2.5)
        span.set_attribute("http.status_code", r.status_code)
        if r.status_code >= 400:
            span.set_status(Status(StatusCode.ERROR))
        r.raise_for_status()

    logger.info("chain-downstream", extra={"downstream": url, "sleep_ms": ms})
    return {"downstream_url": url, "downstream_status": r.status_code, "downstream_json": r.json()}
