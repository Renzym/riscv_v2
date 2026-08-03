#!/usr/bin/env python3

import argparse
import glob
import os
import re
import shutil
import subprocess
import sys
from pathlib import Path


def die(message: str) -> None:
    print(f"ERROR: {message}", file=sys.stderr)
    raise SystemExit(1)


def is_wsl() -> bool:
    try:
        text = Path("/proc/version").read_text(encoding="utf-8", errors="ignore").lower()
    except OSError:
        return False
    return "microsoft" in text or "wsl" in text


def win_path(path: Path) -> str:
    path = path.resolve()
    if is_wsl():
        try:
            return subprocess.check_output(
                ["wslpath", "-w", str(path)],
                text=True,
                stderr=subprocess.DEVNULL,
            ).strip()
        except (OSError, subprocess.CalledProcessError):
            pass
    return str(path)


def xilinx_path(path: Path) -> str:
    return win_path(path).replace("\\", "/")


def find_first(candidates):
    for pattern in candidates:
        matches = sorted(glob.glob(pattern))
        if matches:
            return Path(matches[0]).resolve()
    return None


def find_tool(name: str, patterns):
    path = shutil.which(name)
    if path:
        return Path(path).resolve()
    return find_first(patterns)


def native_install_path(value: str) -> str:
    if is_wsl() and re.match(r"^[A-Za-z]:[\\/]", value):
        try:
            return subprocess.check_output(
                ["wslpath", "-u", value],
                text=True,
                stderr=subprocess.DEVNULL,
            ).strip()
        except (OSError, subprocess.CalledProcessError):
            pass
    return value.replace("\\", "/")


def vitis_patterns(suffix: str):
    roots = []
    for variable in ["XILINX_VITIS", "RDI_APPROOT"]:
        value = os.environ.get(variable)
        if value:
            roots.append(native_install_path(value))

    roots.extend(
        [
            "/mnt/*/Xilinx/Vitis/*",
            "/mnt/*/*/Vitis/*",
        ]
    )
    for drive in "ABCDEFGHIJKLMNOPQRSTUVWXYZ":
        roots.append(f"{drive}:/Xilinx/Vitis/*")
        roots.append(f"{drive}:/*/Vitis/*")
    return [f"{root.rstrip('/')}/{suffix}" for root in roots]


def run(cmd, cwd=None, env=None):
    printable = " ".join(f'"{c}"' if " " in str(c) else str(c) for c in cmd)
    print(printable)
    subprocess.run(cmd, cwd=cwd, env=env, check=True)


def run_bat(bat: Path, args):
    run(["cmd.exe", "/C", win_path(bat), *[str(a) for a in args]])


def run_windows_make(make: Path, cwd: Path, path_entries):
    path_prefix = ";".join(win_path(Path(p)) for p in path_entries)
    batch = cwd / "run_vitis_make.bat"
    batch.write_text(
        "\r\n".join(
            [
                "@echo off",
                f'cd /d "{win_path(cwd)}"',
                f'set "PATH={path_prefix};%PATH%"',
                f'"{win_path(make)}"',
                "",
            ]
        ),
        encoding="ascii",
    )
    run(["cmd.exe", "/C", win_path(batch)])


def copy_sources(loader: Path, image_header: Path, app_src: Path) -> None:
    app_src.mkdir(parents=True, exist_ok=True)
    shutil.copy2(loader, app_src / "run_gcc_program.c")
    shutil.copy2(image_header, app_src / image_header.name)
    print(f"Copied loader/header to {app_src}")


def ensure_app_project_reference(workspace: Path, platform: str, app: str) -> None:
    project_file = workspace / app / ".project"
    if not project_file.exists():
        return

    text = project_file.read_text(encoding="utf-8", errors="ignore")
    if f"<project>{platform}</project>" in text:
        return

    text = text.replace(
        "<projects>\n\t</projects>",
        f"<projects>\n\t\t<project>{platform}</project>\n\t</projects>",
    )
    project_file.write_text(text, encoding="utf-8")


def write_platform_recreate_tcl(workspace: Path, xsa: Path, platform: str) -> None:
    platform_tcl = workspace / platform / "platform.tcl"
    if not platform_tcl.parent.exists():
        return

    out_path = xilinx_path(workspace)
    xsa_path = xilinx_path(xsa)
    tcl_path = win_path(platform_tcl)
    text = f"""# 
# Usage: To re-create this platform project launch xsct with below options.
# xsct {tcl_path}
# 
# OR launch xsct and run below command.
# source {tcl_path}
# 
# To create the platform in a different location, modify the -out option of "platform create" command.
# -out option specifies the output directory of the platform project.

platform create -name {{{platform}}}\\
-hw {{{xsa_path}}}\\
-out {{{out_path}}}

platform write
domain create -name {{standalone_ps7_cortexa9_0}} -display-name {{standalone_ps7_cortexa9_0}} -os {{standalone}} -proc {{ps7_cortexa9_0}} -runtime {{cpp}} -arch {{32-bit}} -support-app {{empty_application}}
platform generate -domains 
platform active {{{platform}}}
domain active {{zynq_fsbl}}
domain active {{standalone_ps7_cortexa9_0}}
platform generate -quick
platform generate
platform clean
platform generate
"""
    platform_tcl.write_text(text, encoding="utf-8")


def configure_classic_workspace(workspace: Path) -> None:
    settings = (
        workspace
        / ".metadata"
        / ".plugins"
        / "org.eclipse.core.runtime"
        / ".settings"
    )
    settings.mkdir(parents=True, exist_ok=True)
    ui_prefs = settings / "org.eclipse.ui.prefs"
    ui_prefs.write_text(
        "\n".join(
            [
                "PERSPECTIVE_BAR_EXTRAS=com.xilinx.ide.application.ui.perspectve,org.eclipse.debug.ui.DebugPerspective",
                "SHOW_OPEN_ON_PERSPECTIVE_BAR=false",
                "SHOW_TEXT_ON_PERSPECTIVE_BAR=true",
                "eclipse.preferences.version=1",
                "showIntro=false",
                "",
            ]
        ),
        encoding="ascii",
    )


def repair_classic_layout(workspace: Path) -> None:
    workbench = (
        workspace
        / ".metadata"
        / ".plugins"
        / "org.eclipse.e4.workbench"
        / "workbench.xmi"
    )
    if not workbench.exists():
        return

    text = workbench.read_text(encoding="ascii", errors="ignore")

    stack_pattern = re.compile(
        r'(<children\s+xsi:type="advanced:PerspectiveStack"'
        r'(?=[^>]*elementId="org\.eclipse\.ui\.ide\.perspectivestack")[^>]*)(>)'
        r'(\s*<tags>Minimized</tags>)?'
        r'(\s*<tags>MinimizedByZoom</tags>)?'
    )

    def restore_perspective(match):
        opening = re.sub(r'\s+visible="false"', '', match.group(1))
        return opening + match.group(2)

    text = stack_pattern.sub(restore_perspective, text, count=1)

    intro_pattern = re.compile(
        r'(<children\s+xsi:type="advanced:Placeholder"'
        r'(?=[^>]*elementId="org\.eclipse\.ui\.internal\.introview")[^>]*)(>)'
    )

    def hide_intro(match):
        opening = re.sub(r'\s+toBeRendered="[^"]*"', '', match.group(1))
        return opening + ' toBeRendered="false"' + match.group(2)

    text = intro_pattern.sub(hide_intro, text, count=1)
    workbench.write_text(text, encoding="ascii")
    print("Restored Classic Vitis Design perspective and hid Welcome view")


def write_classic_launcher(workspace: Path) -> None:
    launcher = workspace / "open_vitis_classic.bat"
    launcher.write_text(
        "\r\n".join(
            [
                "@echo off",
                'python "%~dp0..\\..\\GCC\\vitis_make_flow.py" ^',
                '  --repo-root "%~dp0..\\.." ^',
                '  --workspace "%~dp0" ^',
                "  --open-only",
                "",
            ]
        ),
        encoding="ascii",
    )


def verify_workspace_projects(workspace: Path, projects) -> None:
    registry = (
        workspace
        / ".metadata"
        / ".plugins"
        / "org.eclipse.core.resources"
        / ".projects"
    )
    missing = [name for name in projects if not (registry / name).exists()]
    if missing:
        die(
            "Classic Vitis workspace did not register project(s): "
            + ", ".join(missing)
        )


def patch_debug_makefiles(debug_dir: Path, bsp_include: Path, bsp_lib: Path) -> None:
    subdir_mk = debug_dir / "src" / "subdir.mk"
    makefile = debug_dir / "makefile"

    if subdir_mk.exists():
        text = subdir_mk.read_text(encoding="utf-8", errors="ignore")
        include_arg = f"-I{xilinx_path(bsp_include)}"
        if include_arg not in text:
            text = text.replace(
                "-mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard -MMD",
                f"-mcpu=cortex-a9 -mfpu=vfpv3 -mfloat-abi=hard {include_arg} -MMD",
            )
            subdir_mk.write_text(text, encoding="utf-8")

    if makefile.exists():
        text = makefile.read_text(encoding="utf-8", errors="ignore")
        lib_arg = f"-L{xilinx_path(bsp_lib)}"
        if lib_arg not in text:
            text = text.replace(
                '$(USER_OBJS) $(LIBS)',
                f'$(USER_OBJS) {lib_arg} $(LIBS)',
            )
        text = text.replace("-specs=Xilinx.spec", "-specs=../src/Xilinx.spec")
        makefile.write_text(text, encoding="utf-8")


def build_vitis_elf(workspace: Path, platform: str, app: str, repo_root: Path) -> None:
    debug_dir = workspace / app / "Debug"
    domain_root = workspace / platform / "ps7_cortexa9_0"
    bsp_candidates = [
        domain_root / "standalone_ps7_cortexa9_0" / "bsp" / "ps7_cortexa9_0",
        domain_root / "standalone_domain" / "bsp" / "ps7_cortexa9_0",
    ]
    bsp_root = next((path for path in bsp_candidates if path.exists()), bsp_candidates[0])
    bsp_include = bsp_root / "include"
    bsp_lib = bsp_root / "lib"

    if not (bsp_include / "xil_io.h").exists():
        die(f"missing BSP include path: {bsp_include}")
    if not (bsp_lib / "libxil.a").exists():
        die(f"missing BSP library: {bsp_lib / 'libxil.a'}")

    patch_debug_makefiles(debug_dir, bsp_include, bsp_lib)

    make = find_tool(
        "make.exe",
        vitis_patterns("gnuwin/bin/make.exe"),
    )
    arm_bin = find_first(
        vitis_patterns("gnu/aarch32/nt/gcc-arm-none-eabi/bin")
    )
    if not make:
        die("could not find Vitis GNU make.exe")
    if not arm_bin:
        die("could not find Vitis ARM GCC bin directory")

    run_windows_make(make, debug_dir, [arm_bin, make.parent])

    elf = debug_dir / f"{app}.elf"
    if not elf.exists():
        die(f"Vitis app build finished but ELF was not created: {elf}")
    print(f"Built Vitis ELF: {elf}")


def open_vitis(workspace: Path) -> None:
    vitis = find_tool(
        "vitis.bat",
        vitis_patterns("bin/vitis.bat"),
    )
    if not vitis:
        die("could not find vitis.bat")
    subprocess.Popen(
        [
            "cmd.exe",
            "/C",
            "start",
            "",
            win_path(vitis),
            "-classic",
            "-workspace",
            win_path(workspace),
        ]
    )


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--repo-root", required=True)
    parser.add_argument("--workspace", required=True)
    parser.add_argument("--xsa")
    parser.add_argument("--platform", default="design_1_wrapper")
    parser.add_argument("--app", default="rv32im")
    parser.add_argument("--loader")
    parser.add_argument("--image-header")
    parser.add_argument("--tcl")
    parser.add_argument("--build", action="store_true")
    parser.add_argument("--open-only", action="store_true")
    args = parser.parse_args()

    repo_root = Path(args.repo_root).resolve()
    workspace = Path(args.workspace).resolve()

    if args.open_only:
        configure_classic_workspace(workspace)
        repair_classic_layout(workspace)
        write_classic_launcher(workspace)
        open_vitis(workspace)
        return 0

    xsa = Path(args.xsa).resolve()
    loader = Path(args.loader).resolve()
    image_header = Path(args.image_header).resolve()
    tcl = Path(args.tcl).resolve()
    app_src = workspace / args.app / "src"

    for required in [xsa, loader, image_header, tcl]:
        if not required.exists():
            die(f"missing required file: {required}")

    xsct = find_tool(
        "xsct.bat",
        vitis_patterns("bin/xsct.bat"),
    )
    if not xsct:
        die("could not find xsct.bat")

    run_bat(xsct, [win_path(tcl), "create", win_path(workspace), win_path(xsa), args.platform, args.app])
    ensure_app_project_reference(workspace, args.platform, args.app)
    write_platform_recreate_tcl(workspace, xsa, args.platform)
    copy_sources(loader, image_header, app_src)

    if args.build:
        run_bat(xsct, [win_path(tcl), "build", win_path(workspace), args.app])
        ensure_app_project_reference(workspace, args.platform, args.app)
        write_platform_recreate_tcl(workspace, xsa, args.platform)
        build_vitis_elf(workspace, args.platform, args.app, repo_root)

    configure_classic_workspace(workspace)
    repair_classic_layout(workspace)
    write_classic_launcher(workspace)
    verify_workspace_projects(
        workspace, [args.platform, args.app, f"{args.app}_system"]
    )
    print(f"Classic Vitis workspace ready: {workspace}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
