import argparse
import logging

import serial
import serial.tools.list_ports

logger = logging.getLogger(__name__)
logging.basicConfig(level=logging.INFO)


def str_to_int(string: str) -> int:
    """
    Convert a string to an integer. Supports decimal, hexadecimal (0x), and binary (0b) formats.

    Args:
        string (str): The string to convert.

    Returns:
        int: The converted integer, or -1 if the format is unknown or invalid.
    """
    string = string.strip().lower()
    if string.isdigit():
        return int(string)

    if len(string) < 3:
        logger.warning("Value missing from string: %s", string)
        return -1

    if string.startswith("0x"):
        try:
            return int(string, 16)
        except ValueError:
            logger.warning("Invalid hex value: %s", string)
            return -1

    if string.startswith("0b"):
        try:
            return int(string, 2)
        except ValueError:
            logger.warning("Invalid binary value: %s", string)
            return -1

    logger.warning("Unknown format for string: %s", string)
    return -1


def detect_com_port() -> str:
    """
    Detect available COM ports and select the first one found.

    Returns:
        str: The selected COM port, or None if no ports are detected.
    """
    ports = list(serial.tools.list_ports.comports())
    if not ports:
        logger.error("No COM ports detected")
        return None

    for port in ports:
        logger.info("Detected COM port: %s", port.device)

    # Automatically select the first available port
    selected_port = ports[0].device
    logger.info("Selected COM port: %s", selected_port)
    return selected_port


def loop_send_uart_input(com_port: str, baudrate: int = 9600) -> None:
    """
    Continuously read input from the user, convert it to an integer, and send it over UART.

    Args:
        com_port (str): The COM port to use for UART communication.
        baudrate (int, optional): The baud rate for UART communication. Defaults to 9600.
    """
    try:
        ser = serial.Serial(com_port, baudrate)
    except serial.SerialException as e:
        logger.error("Failed to open serial port: %s", e)
        return

    try:
        while True:
            data_str = input("Enter int, hex, or bits to send (or x to exit): ").strip().lower()
            if data_str == "x":
                break

            data_int = str_to_int(data_str)
            if data_int == -1:
                continue

            data_byte_len = (data_int.bit_length() + 7) // 8
            data_bytes = data_int.to_bytes(data_byte_len or 1, byteorder="little")
            ser.write(data_bytes)
    except KeyboardInterrupt:
        logger.info("Interrupted by user")
    finally:
        ser.close()
        logger.info("Serial port closed")


def main():
    """Main function to start the UART input loop. Uses argparse to handle command line arguments."""
    parser = argparse.ArgumentParser(description="UART communication script")
    parser.add_argument(
        "--com_port",
        type=str,
        default="",
        help="Specify the COM port (e.g., COM5). If not specified, the script will auto-detect an available COM port.",
    )
    args = parser.parse_args()

    com_port = args.com_port if args.com_port else detect_com_port()
    if com_port:
        loop_send_uart_input(com_port)


if __name__ == "__main__":
    main()
