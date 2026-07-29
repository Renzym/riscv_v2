# RV32IM direct-BRAM mailbox example for the custom core on Zybo Z7-10
#
# Build on Linux/WSL with a bare-metal RISC-V toolchain:
#   make
#   make dump

RISCV_PREFIX ?= riscv64-unknown-elf
CC      = $(RISCV_PREFIX)-gcc
OBJCOPY = $(RISCV_PREFIX)-objcopy
OBJDUMP = $(RISCV_PREFIX)-objdump
SIZE    = $(RISCV_PREFIX)-size

TARGET    = program
SRCS      = main.c
# crt0.s provides stack setup and .data/.bss initialization before main().
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

.PHONY: all dump header clean

all: $(TARGET).elf $(TARGET).bin $(TARGET).hex $(IMEM_BIN) $(IMAGE_HDR)
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
	python3 emit_riscv_header.py \
		--input $(IMEM_BIN) \
		--output $@ \
		--tag "$(TARGET).imem.bin"

dump: $(IMEM_BIN)
	@echo "=== Disassembly ==="
	$(OBJDUMP) -D -M no-aliases $(TARGET).elf
	@echo ""
	@echo "=== Raw IMEM hex words (reference/debug only) ==="
	xxd -e -g4 $(IMEM_BIN)

header: $(IMAGE_HDR)

clean:
	rm -f $(OBJS) $(TARGET).elf $(TARGET).bin $(TARGET).hex $(TARGET).map $(IMEM_BIN) $(IMAGE_HDR)
