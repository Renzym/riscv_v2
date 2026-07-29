#!/usr/bin/env python3

import argparse
from pathlib import Path


def emit_header(input_path: Path, output_path: Path, tag: str) -> None:
    data = input_path.read_bytes()
    if len(data) % 4 != 0:
        raise ValueError(
            f"Input size {len(data)} is not a multiple of 4 bytes: {input_path}"
        )

    words = [
        int.from_bytes(data[i : i + 4], byteorder="little", signed=False)
        for i in range(0, len(data), 4)
    ]

    lines = [
        "#ifndef RV32IM_PROGRAM_IMAGE_H",
        "#define RV32IM_PROGRAM_IMAGE_H",
        "",
        "#include <stdint.h>",
        "",
        f'#define RV32IM_IMAGE_TAG "{tag}"',
        "",
        "static const uint32_t riscv_code[] = {",
    ]

    for word in words:
        lines.append(f"    0x{word:08x}U,")

    lines.extend(
        [
            "};",
            "",
            "#define RISCV_CODE_WORD_COUNT \\",
            "    ((uint32_t)(sizeof(riscv_code) / sizeof(riscv_code[0])))",
            "",
            "#define RV32I_IMAGE_TAG RV32IM_IMAGE_TAG",
            "",
            "#endif",
            "",
        ]
    )

    output_path.write_text("\n".join(lines), encoding="ascii")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--tag", required=True)
    args = parser.parse_args()

    emit_header(Path(args.input), Path(args.output), args.tag)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
