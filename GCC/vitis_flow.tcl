if {$argc < 1} {
    puts "usage:"
    puts "  vitis_flow.tcl create <workspace> <xsa> <platform> <app>"
    puts "  vitis_flow.tcl build  <workspace> <app>"
    puts "  vitis_flow.tcl run    <workspace> <app> <bitstream>"
    exit 2
}

set mode [lindex $argv 0]

proc fail {msg} {
    puts stderr $msg
    exit 1
}

proc create_or_update_vitis {workspace xsa platform app} {
    file mkdir $workspace
    setws $workspace

    set platform_dir [file join $workspace $platform]
    set system_dir [file join $workspace "${app}_system"]
    set app_dir [file join $workspace $app]
    set domain_name standalone_ps7_cortexa9_0

    if {![file exists $platform_dir]} {
        platform create \
            -name $platform \
            -hw $xsa \
            -out $workspace
        platform active $platform
        platform write
        catch {
            domain create \
                -name $domain_name \
                -display-name $domain_name \
                -os standalone \
                -proc ps7_cortexa9_0 \
                -runtime cpp \
                -arch 32-bit \
                -support-app {empty_application}
        }
        platform generate
    } else {
        puts "Platform already exists: $platform_dir"
        catch {platform active $platform}
    }

    # platform create generates the files but does not always add the platform
    # to Eclipse's workspace registry when XSCT is run headlessly.
    if {[catch {importprojects $platform_dir} import_error]} {
        puts "Platform import: $import_error"
    }

    if {![file exists $app_dir]} {
        catch {platform active $platform}
        app create \
            -name $app \
            -platform $platform \
            -domain $domain_name \
            -template {Empty Application(C)}
    } else {
        puts "Application already exists: $app_dir"
        catch {importprojects $app_dir}
        if {[file exists $system_dir]} {
            catch {importprojects $system_dir}
        }
    }
}

proc build_vitis_app {workspace app} {
    setws $workspace
    set srcdir [file join $workspace $app src]
    if {[file exists $srcdir]} {
        catch {importsources -name $app -path $srcdir}
    }
    app build -name $app
}

proc program_and_run {workspace app bitstream} {
    set elf_file [file join $workspace $app Debug "$app.elf"]
    if {![file exists $bitstream]} {
        fail "missing bitstream: $bitstream"
    }
    if {![file exists $elf_file]} {
        fail "missing app ELF: $elf_file"
    }

    connect
    targets -set -nocase -filter {name =~ "*xc7z*"}
    fpga -file $bitstream

    targets -set -nocase -filter {name =~ "*Cortex-A9*#0"}
    rst -processor
    dow $elf_file
    con
}

switch -- $mode {
    create {
        if {$argc != 5} {
            fail "usage: vitis_flow.tcl create <workspace> <xsa> <platform> <app>"
        }
        create_or_update_vitis [lindex $argv 1] [lindex $argv 2] [lindex $argv 3] [lindex $argv 4]
    }
    build {
        if {$argc != 3} {
            fail "usage: vitis_flow.tcl build <workspace> <app>"
        }
        build_vitis_app [lindex $argv 1] [lindex $argv 2]
    }
    run {
        if {$argc != 4} {
            fail "usage: vitis_flow.tcl run <workspace> <app> <bitstream>"
        }
        program_and_run [lindex $argv 1] [lindex $argv 2] [lindex $argv 3]
    }
    default {
        fail "unknown mode: $mode"
    }
}
