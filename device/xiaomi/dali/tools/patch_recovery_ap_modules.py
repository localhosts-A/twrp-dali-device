#!/usr/bin/env python3
"""Create Recovery-only AP-mode copies of the stock SCP and Goodix modules."""

from __future__ import annotations

import argparse
import hashlib
import os
import struct
from pathlib import Path


ELF_HEADER = struct.Struct("<16sHHIQQQIHHHHHH")
SECTION_HEADER = struct.Struct("<IIQQQQIIQQ")
SYMBOL = struct.Struct("<IBBHQQ")

EXPECTED_SHA256 = {
    "scp": "4c934228f5db352d9290a51a3c9e54b4dd68bb4a63327431ce3e8d0ccfce9c95",
    "goodix": "84aaed071f358060995c9190efefa9f8e63a835576cd1a0d6096c93983208ddf",
}

PACIASP = bytes.fromhex("3f2303d5")
MOV_W0_ZERO = bytes.fromhex("00008052")
MOV_W0_ONE = bytes.fromhex("20008052")
AUTIASP = bytes.fromhex("bf2303d5")
RET = bytes.fromhex("c0035fd6")


def c_string(blob: bytes, offset: int) -> str:
    end = blob.find(b"\0", offset)
    if end < 0:
        raise ValueError("unterminated ELF string")
    return blob[offset:end].decode("ascii")


def sections(data: bytes) -> list[dict[str, int | str]]:
    if len(data) < ELF_HEADER.size:
        raise ValueError("truncated ELF header")
    header = ELF_HEADER.unpack_from(data)
    ident = header[0]
    if ident[:4] != b"\x7fELF" or ident[4] != 2 or ident[5] != 1:
        raise ValueError("expected ELF64 little-endian input")
    if header[2] != 183:
        raise ValueError("expected AArch64 module")

    shoff = header[6]
    shentsize = header[11]
    shnum = header[12]
    shstrndx = header[13]
    if shentsize != SECTION_HEADER.size or shstrndx >= shnum:
        raise ValueError("unsupported section table")

    raw = []
    for index in range(shnum):
        offset = shoff + index * shentsize
        values = SECTION_HEADER.unpack_from(data, offset)
        raw.append(
            {
                "index": index,
                "name_offset": values[0],
                "type": values[1],
                "offset": values[4],
                "size": values[5],
                "link": values[6],
                "entsize": values[9],
            }
        )

    names = raw[shstrndx]
    name_blob = data[int(names["offset"]): int(names["offset"]) + int(names["size"])]
    for section in raw:
        section["name"] = c_string(name_blob, int(section["name_offset"]))
    return raw


def symbol_offset(data: bytes, symbol_name: str) -> tuple[int, int]:
    table = sections(data)
    symtab = next((section for section in table if section["name"] == ".symtab"), None)
    if symtab is None or int(symtab["entsize"]) != SYMBOL.size:
        raise ValueError("ELF symbol table is missing or unsupported")
    strings = table[int(symtab["link"])]
    string_blob = data[int(strings["offset"]): int(strings["offset"]) + int(strings["size"])]

    count = int(symtab["size"]) // SYMBOL.size
    for index in range(count):
        entry_offset = int(symtab["offset"]) + index * SYMBOL.size
        name_offset, _info, _other, section_index, value, size = SYMBOL.unpack_from(data, entry_offset)
        if c_string(string_blob, name_offset) != symbol_name:
            continue
        if section_index == 0 or section_index >= len(table):
            raise ValueError(f"{symbol_name} has no file-backed section")
        section = table[section_index]
        return int(section["offset"]) + value, size
    raise ValueError(f"missing symbol: {symbol_name}")


def patch_function(
    source: Path,
    destination: Path,
    kind: str,
    symbol_name: str,
    return_instruction: bytes,
) -> None:
    data = bytearray(source.read_bytes())
    source_hash = hashlib.sha256(data).hexdigest()
    if source_hash != EXPECTED_SHA256[kind]:
        raise ValueError(f"unexpected {kind} source SHA-256: {source_hash}")

    offset, size = symbol_offset(data, symbol_name)
    if size < 16:
        raise ValueError(f"{symbol_name} is too small to patch")
    expected_prefix = PACIASP + bytes.fromhex("fd7b")
    if data[offset:offset + len(expected_prefix)] != expected_prefix:
        raise ValueError(f"unexpected {symbol_name} prologue at 0x{offset:x}")

    # Keep pointer authentication balanced. The SCP module must report a
    # successful load so its exports resolve; Goodix reports failure only from
    # its optional scp_tp_init() path and continues with the AP touch path.
    data[offset:offset + 16] = PACIASP + return_instruction + AUTIASP + RET

    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)
    os.chmod(destination, source.stat().st_mode & 0o777)
    print(
        f"{kind}: symbol={symbol_name} file_offset=0x{offset:x} "
        f"source_sha256={source_hash} output_sha256={hashlib.sha256(data).hexdigest()}"
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--scp", type=Path, required=True)
    parser.add_argument("--goodix", type=Path, required=True)
    parser.add_argument("--out-dir", type=Path, required=True)
    args = parser.parse_args()

    patch_function(
        args.scp,
        args.out_dir / "scp.ko",
        "scp",
        "init_module",
        MOV_W0_ZERO,
    )
    patch_function(
        args.goodix,
        args.out_dir / "goodix_core_dali.ko",
        "goodix",
        "scp_tp_init",
        MOV_W0_ONE,
    )


if __name__ == "__main__":
    main()
