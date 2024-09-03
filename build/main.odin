package main

import "core:os"
import "core:c/libc"
import "core:fmt"
import "core:strings"

main :: proc(){
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
        when ODIN_OS == .Windows {
            run(`
                cd src/manymouse
                call "C:\Program Files (x86)\Microsoft Visual Studio\2019\BuildTools\VC\Auxiliary\Build\vcvars64.bat"
                cl /c /EHsc all.c
                ar r manymouse_windows.a all.obj
            `);
        } else when ODIN_OS == .Linux {
            run(`
                cd src/manymouse
                mkdir linux
                cd linux
                g++ -c ../linux_evdev.c  ../x11_xinput2.c ../manymouse.c ../windows_wminput.c ../macosx_hidmanager.c ../macosx_hidutilities.c
                ar r manymouse.a linux_evdev.o x11_xinput2.o manymouse.o windows_wminput.o macosx_hidmanager.o macosx_hidutilities.o
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

        -release:
            Builds the game in release mode

        -full:
            Builds the dependencies such as manymouse.

`
