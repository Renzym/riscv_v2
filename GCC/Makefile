# Simple RV32IM + Classic Vitis flow.
#
#   make gcc
#       Build GCC/main.c for the RISC-V core and generate rv32i_program_image.h.
#
#   make
#       Build the RISC-V image/header, create/update the Classic Vitis
#       platform/app, copy FW/run_gcc_program.c and rv32i_program_image.h into
#       the app source folder, build the Vitis ARM loader ELF, and launch the
#       completed Classic Vitis workspace.

RISCV_PREFIX ?= riscv64-unknown-elf
PYTHON  ?= python

WINDOWS_DRIVES := C D E F G H I J K L M N O P Q R S T U V W X Y Z

AUTO_RISCV_TOOL_BIN := $(firstword \
	$(wildcard $(XILINX_VITIS)/gnu/riscv/nt/riscv64-unknown-elf/bin) \
	$(wildcard /mnt/*/Xilinx/Vitis/*/gnu/riscv/nt/riscv64-unknown-elf/bin) \
	$(wildcard /mnt/*/*/Vitis/*/gnu/riscv/nt/riscv64-unknown-elf/bin) \
	$(foreach drive,$(WINDOWS_DRIVES),$(wildcard $(drive):/Xilinx/Vitis/*/gnu/riscv/nt/riscv64-unknown-elf/bin)) \
	$(foreach drive,$(WINDOWS_DRIVES),$(wildcard $(drive):/*/Vitis/*/gnu/riscv/nt/riscv64-unknown-elf/bin)))

RISCV_TOOL_BIN ?= $(AUTO_RISCV_TOOL_BIN)
RISCV_TOOL     = $(if $(RISCV_TOOL_BIN),$(firstword $(wildcard $(RISCV_TOOL_BIN)/$(RISCV_PREFIX)-$(1)) $(wildcard $(RISCV_TOOL_BIN)/$(RISCV_PREFIX)-$(1).exe) $(RISCV_TOOL_BIN)/$(RISCV_PREFIX)-$(1)),$(RISCV_PREFIX)-$(1))

CC      = $(call RISCV_TOOL,gcc)
OBJCOPY = $(call RISCV_TOOL,objcopy)
OBJDUMP = $(call RISCV_TOOL,objdump)
SIZE    = $(call RISCV_TOOL,size)

TARGET    = program
SRCS      = main.c
ASM_SRCS  = crt0.s
LD_SCRIPT = linker.ld
OBJS      = $(SRCS:.c=.o) $(ASM_SRCS:.s=.o)
IMEM_BIN  = $(TARGET).imem.bin
IMAGE_HDR = rv32i_program_image.h

ARCH = rv32im
ABI  = ilp32

CFLAGS = -march=$(ARCH) -mabi=$(ABI) -O2 -Wall \
         -mno-relax -msmall-data-limit=0 \
         -fno-stack-protector -fomit-frame-pointer \
         -ffreestanding -ffunction-sections -fdata-sections \
         -nostdlib -nostartfiles -I.

LDFLAGS = -march=$(ARCH) -mabi=$(ABI) \
          -mno-relax -msmall-data-limit=0 \
          -T $(LD_SCRIPT) \
          -Wl,--gc-sections \
          -Wl,-Map=$(TARGET).map \
          -nostdlib -nostartfiles

REPO_ROOT      ?= ..
HW_XSA         ?= $(REPO_ROOT)/fpga/work/design_1_wrapper.xsa
VITIS_WS       ?= $(REPO_ROOT)/fpga/vitis
VITIS_PLATFORM ?= design_1_wrapper
VITIS_APP      ?= rv32i
VITIS_SRC      := $(VITIS_WS)/$(VITIS_APP)/src
VITIS_LAUNCHER := $(VITIS_WS)/open_vitis_classic.bat
FW_LOADER      ?= $(REPO_ROOT)/FW/run_gcc_program.c

.PHONY: all gcc vitis-flow copy-to-vitis vitis-create vitis-project vitis-src vitis-open vitis-build dump clean clean-vitis show-flow

all: gcc vitis-open

gcc: $(TARGET).elf $(TARGET).bin $(TARGET).hex $(IMEM_BIN) $(IMAGE_HDR)
	@echo ""
	$(SIZE) $(TARGET).elf
	@echo ""
	@echo "Built $(TARGET).imem.bin and $(IMAGE_HDR) for direct IMEM loading."

$(TARGET).elf: $(OBJS) $(LD_SCRIPT)
	$(CC) $(LDFLAGS) -o $@ $(OBJS)

%.o: %.c
	$(CC) $(CFLAGS) -c -o $@ $<

%.o: %.s
	$(CC) $(CFLAGS) -c -o $@ $<

$(TARGET).bin: $(TARGET).elf
	$(OBJCOPY) -O binary $< $@

$(TARGET).hex: $(TARGET).elf
	$(OBJCOPY) -O ihex $< $@

$(IMEM_BIN): $(TARGET).elf
	$(OBJCOPY) -O binary \
		-j .text.startup \
		-j .text \
		-j .text.* \
		-j .rodata \
		-j .rodata.* \
		$< $@

$(IMAGE_HDR): $(IMEM_BIN) emit_riscv_header.py
	$(PYTHON) emit_riscv_header.py \
		--input $(IMEM_BIN) \
		--output $@ \
		--tag "$(TARGET).imem.bin"

vitis-flow: $(IMAGE_HDR) $(FW_LOADER) vitis_flow.tcl vitis_make_flow.py
	$(PYTHON) vitis_make_flow.py \
		--repo-root "$(REPO_ROOT)" \
		--workspace "$(VITIS_WS)" \
		--xsa "$(HW_XSA)" \
		--platform "$(VITIS_PLATFORM)" \
		--app "$(VITIS_APP)" \
		--loader "$(FW_LOADER)" \
		--image-header "$(IMAGE_HDR)" \
		--tcl "vitis_flow.tcl" \
		--build

vitis-create vitis-project copy-to-vitis vitis-src vitis-build: vitis-flow

show-flow:
	@echo "RISC-V source : main.c"
	@echo "Image header  : $(IMAGE_HDR)"
	@echo "Vitis source  : $(VITIS_SRC)"
	@echo "Hardware XSA  : $(HW_XSA)"

vitis-open: vitis-flow
	$(PYTHON) vitis_make_flow.py --repo-root "$(REPO_ROOT)" --workspace "$(VITIS_WS)" --open-only

dump: $(IMEM_BIN)
	@echo "=== Disassembly ==="
	$(OBJDUMP) -D -M no-aliases $(TARGET).elf
	@echo ""
	@echo "=== Raw IMEM hex words (reference/debug only) ==="
	xxd -e -g4 $(IMEM_BIN)

clean:
	rm -f $(OBJS) $(TARGET).elf $(TARGET).bin $(TARGET).hex $(TARGET).map $(IMEM_BIN) $(IMAGE_HDR)

clean-vitis:
	rm -rf "$(VITIS_WS)/$(VITIS_APP)" "$(VITIS_WS)/$(VITIS_APP)_system"
