package main

import "core:os"
import "core:c/libc"
import "core:fmt"
import "core:strings"

// Do not care about memory allocation
// this is a script kinda
main :: proc(){
    self_rebuild();

    args := parse_args();
    switch args.kind{
    case .Build:
        build(args);
    case.Help:
        fmt.println(HELP);
    }
}

Args :: struct{
    kind: enum{
        Help,
        Build,
    },
    build: struct{
        mode: enum{
            Debug,
            Release,
        },
        full: bool,
        run:  bool,
    },
}

parse_args :: proc() -> Args{
    os_args := os.args[1:];
    args: Args;

    for arg in os_args{
        switch arg{
        case "build":
            args.kind = .Build;
        case "help":
            args.kind = .Help;
        case "-release":
            assert(args.kind == .Build);
            args.build.mode = .Release;
        case "-full":
            assert(args.kind == .Build);
            args.build.full = true;
        case "-run":
            assert(args.kind == .Build);
            args.build.run = true;
        case: 
            fmt.println("Unkown argument", arg);
            panic("");
        }
    }

    return args;
}

build :: proc(args: Args){
    build := args.build;

    if build.full{
        // Todo(Ferenc): Check if we build release 

        when ODIN_OS == .Windows {
            builder: strings.Builder;
            strings.builder_init(&builder);
            strings.write_string(&builder, `cd src/manymouse & `);

            // Todo(Ferenc): Do better visual studio version checking
            strings.write_string(&builder, `call "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat" & `);
            strings.write_string(&builder, `call "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\VC\Auxiliary\Build\vcvars64.bat" & `);

            strings.write_string(&builder, `cl /O2 /c /EHsc all.c & `);
            strings.write_string(&builder, `ar r manymouse_windows.a all.obj & `);
            strings.write_string(&builder, `del *.obj & `);
            cmd := strings.to_string(builder);
            run(cmd);
        } else when ODIN_OS == .Linux {
            run(`
                cd src/manymouse
                mkdir linux
                cd linux
                g++ -O2 -c ../linux_evdev.c  ../x11_xinput2.c ../manymouse.c ../windows_wminput.c ../macosx_hidmanager.c ../macosx_hidutilities.c
                ar r manymouse.a linux_evdev.o x11_xinput2.o manymouse.o windows_wminput.o macosx_hidmanager.o macosx_hidutilities.o
                rm *.o
            `);
        } else {
            panic("Unkown OS");
        }
    }

    switch build.mode{
    case .Debug:
        run(`odin build src -collection:src=src -debug -out:main.exe`);
    case .Release:
        run(`odin build src -collection:src=src -o:speed -out:main.exe`);
    }

    if args.build.run{
        when ODIN_OS == .Windows {
            run(`.\main.exe`);
        } else when ODIN_OS == .Linux {
            run(`./main.exe`);
        } else {
            panic("Unkown OS");
        }
    }
}


self_rebuild :: proc(){
    main_str  := read_file_or_empty("build/main.odin");
    cache_str := read_file_or_empty("build/cache.tmp");

    cache_hd, err := os.open("build/cache.tmp", os.O_WRONLY | os.O_CREATE | os.O_TRUNC, 0o700);
    assert(err == os.ERROR_NONE);
    os.write_string(cache_hd, main_str);
    os.close(cache_hd);

    if main_str != cache_str{
        fmt.println("Rebuilding self");

        when ODIN_OS == .Windows{
            fmt.println("Self rebuild on windows is not supported because it is fucking terrible os");
            fmt.println("Use 'odin build build -out:build.exe' manually in the command line");
        } else when ODIN_OS == .Linux{
            run(`rm build.exe`);
            run(`odin build build -out:build.exe`);
            os.execvp(os.args[0], os.args[1:]);
        } else {
            panic("Unkown OS");
        }

        os.exit(0);
    }

    read_file_or_empty :: proc(path: string) -> string{
        hd, err := os.open(path, os.O_RDONLY);
        if err != os.ERROR_NONE do return "";

        size, err2 := os.file_size(hd);
        if err2 != os.ERROR_NONE do return "";

        buffer := make([]u8, size);
        os.read_full(hd, buffer[:]);
        str := cast(string) buffer;
        return str;
    }
}

run :: proc(str: string){
    fmt.println("[Running]", str);
    cstr := strings.clone_to_cstring(str);
    libc.system(cstr);
}

HELP :: \
`
It is a tool for building the game or other stuff

Usage:
    build [arguments]

Argument:
    help
        Prints this message.

    build
        It builds the game, by default it builds in debug mode.

        -run:
            Runs the game after build

        -release:
            Builds the game in release mode

        -full:
            Builds the dependencies such as manymouse.

`
