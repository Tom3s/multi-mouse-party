# Multi Mouse Party (Name work in progress)

## Build

```
odin build build -out:build.exe
```

linux:
```
./build.exe [arguments]
```

windows:
```
build.exe [arguments]
```

For help run:
```
./build.exe help
```

It only needs to be build once, the program rebuilds itself if it changed (it watches build/main.odin only).

## Coding guildlines

Tabs.

Everything by default is snake_case if not specified.

Type names follow My_Type case.

Const names follor SHOUTING_CASE.

Brackets go on the same line e.g.:
```odin
if true{
    // ...
}

/* 
    You are fired for this
*/
if true
{
}
```


