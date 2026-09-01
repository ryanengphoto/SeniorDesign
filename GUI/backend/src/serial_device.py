"""Serial/USB-CDC device backend stub for future MCU integration.

When HUB_MODE=serial, open SERIAL_PORT (default /dev/ttyACM0), read
newline-delimited JSON telemetry frames, and write command JSON + newline.
"""


class SerialDevice:
    def __init__(self, port: str = "/dev/ttyACM0", baud: int = 115200) -> None:
        self.port = port
        self.baud = baud

    @property
    def mode(self) -> str:
        return "serial"

    def start(self) -> None:
        raise NotImplementedError(
            "Serial device mode is not implemented yet. Set HUB_MODE=mock."
        )

    async def stop(self) -> None:
        pass
