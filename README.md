# trireme
The Trireme RISC-V Design Platform is a complete RISC-V design space exploration exploration environment. It allows researchers and design engineers to bring up a customized instance of RISC-V system using the provided design automation tools, soft parameterizable hardware modules, and the software ecosystem for application development and compiling. The systems supported range from ultra-low-power microcontrollers to high-performance multi-core processors.

All parts of the platform are open-source and available for download at https://www.trireme-riscv.org/index.html

The Trireme Platform contains all the tools necessary for register-transfer level (RTL) architecture design space exploration. The platform includes RTL, example software, a toolchain wrapper, and configuration graphical user interface (GUI). The platform is designed with a high degree of modularity. It provides highly-parameterized, composable RTL modules for fast and accurate exploration of different RISC-V based core complexities, multi-level caching and memory organizations. 


The platform can be used for both RTL simulation and FPGA based emulation. The hardware modules are implemented in synthesizable Verilog using no vendor-specific blocks. The platform’s RISC-V compiler toolchain wrapper is used to develop software for the cores. A web-based system configuration (GUI) can be used to rapidly generate different processor configurations. The interfaces between hardware components are carefully designed to allow processor subsystems such as the cache hierarchy, cores or individual pipeline stages, to be modified or replaced without impacting the rest of the system. 


The platform allows users to quickly instantiate complete working RISC-V multi-core systems with synthesizable RTL and make targeted modifications to fit their needs.
