from __future__ import annotations

import asyncio
import contextlib
import json

from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware

from .hub_service import HubService
from .protocol import CommandMessage, SnapshotMessage

app = FastAPI(title="USB Hub Operator Console")
hub = HubService()

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",
        "http://127.0.0.1:5173",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.on_event("startup")
async def startup() -> None:
    hub.start()


@app.on_event("shutdown")
async def shutdown() -> None:
    await hub.stop()


@app.get("/api/health")
async def health() -> dict[str, str]:
    return {"status": "ok", "mode": hub.mode}


@app.websocket("/ws")
async def websocket_endpoint(websocket: WebSocket) -> None:
    await websocket.accept()

    telemetry = hub.get_telemetry()
    snapshot = SnapshotMessage(
        mode=hub.mode,
        events=hub.get_events(),
        telemetry=telemetry,
    )
    await websocket.send_text(snapshot.model_dump_json())

    async def telemetry_loop() -> None:
        while True:
            frame = hub.get_telemetry()
            await websocket.send_text(frame.model_dump_json())
            await asyncio.sleep(0.1)

    telemetry_task = asyncio.create_task(telemetry_loop())

    try:
        while True:
            raw = await websocket.receive_text()
            try:
                payload = json.loads(raw)
                command = CommandMessage.model_validate(payload)
            except (json.JSONDecodeError, ValueError):
                continue

            event = hub.handle_command(command)
            if event is not None:
                await websocket.send_text(event.model_dump_json())
    except WebSocketDisconnect:
        pass
    finally:
        telemetry_task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await telemetry_task
