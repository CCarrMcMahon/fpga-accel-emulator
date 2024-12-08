# FPGA-Accel-Emulator

## Summary

FPGA-Accel-Emulator is an FPGA-based project designed to emulate the functionality of the ADXL362 accelerometer. This project aims to facilitate testing and development by allowing direct control over the accelerometer's FIFO registers via an SPI interface, without the need for actual hardware. The emulator supports communication with an external MCU and a PC, providing a flexible and controllable environment for algorithm testing.

## Status

**Work in Progress**

## Current Functionality

-   **UART Receiver Module**: Converts UART serial data from the RX line to an 8-bit register along with ready and error signals. It synchronizes the `rx` and `data_read` signals to the system clock, uses a state machine to manage the reception process, and detects start, data, and stop bits according to the specified baud rate.
-   **SPI Master Module**: Facilitates communication with SPI slave devices. It synchronizes the `data_read` and `start_tx` signals to the system clock, uses a state machine to manage the SPI transmission process, generates the SPI clock signal according to the specified frequency, and handles the SPI protocol including chip select, data shifting, and clocking.

## Future Functionality

-   [ ] Implement a UART to SPI converter to allow for easier integration between the PC and future modules.
-   [ ] Create a SPI slave module so SPI masters can properly transmit data.
-   [ ] Create a UART transmitter module so data can be sent back to the PC.
-   [ ] Design an Arbiter to manage communication between multiple devices, ensuring only one device communicates with the accelerometer module at a time.
-   [ ] Develop a traffic manager to route direct FIFO commands from the PC to a dedicate SPI slave in the accelerometer to avoid overloading the main accelerometer SPI interface.
-   [ ] Integrate FIFO control registers and data injection mechanisms.
-   [ ] Implement looping mechanism for FIFO data.
-   [ ] Develop Accelerometer Emulation: Emulate the functionality of the ADXL362 accelerometer.

## Design and Considerations

-   **Arbiter**: Ensures that either the MCU or the PC can communicate with the accelerometer module without conflicts. Implements a priority scheme and state machine for managing access.
-   **Traffic Manager**: Routes PC traffic to a separate SPI slave interface to avoid overloading the arbiter SPI lines with FIFO data.
-   **FIFO Control**: Provides mechanisms for direct data injection and looping, allowing for consistent and controlled testing scenarios.
-   **Modular Design**: Ensures that each component is well-documented and easily testable, facilitating debugging and future modifications.
-   **Error Handling**: Implements robust error detection and handling mechanisms for both UART and SPI communications.
-   **Timing and Synchronization**: Manages clock domains and ensures proper synchronization between UART and SPI interfaces.

## Requirements

-   **FPGA Board**: Nexys A7 (Nexys 4 DDR) with Xilinx Artix-7 FPGA (XC7A100T-1CSG324C).
-   **Development Software**: Xilinx Vivado Design Suite.

## Getting Started

1. **Clone the Repository**:

    ```bash
    git clone git@github.com:CCarrMcMahon/fpga-accel-emulator.git
    ```

2. **Set Up Your FPGA Development Environment**:

    - Install Xilinx Vivado Design Suite.
    - During installation, make sure to install `Artix-7` from the list of devices.

3. **Open the Project**

    - Load the `fpga-accel-emulator.xpr` file in Vivado.

4. **Build and Simulate**:

    - Use Vivado Simulator to test the modules.
    - Verify the functionality and timing of each module if desired.

5. **Deploy to FPGA**:

    - Synthesize and implement the design on your FPGA board.
    - Connect the PC and MCU to the FPGA and start testing.

## License

This project is licensed under the MIT License. See the LICENSE file for details.
