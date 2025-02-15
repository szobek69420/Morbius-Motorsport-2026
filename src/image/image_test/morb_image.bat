nasm -fobj ../../utils/string.asm -o string.o
nasm -fobj ../../utils/file.asm -o file.o
nasm -fobj ../../utils/console.asm -o console.o
nasm -fobj ../../utils/memory.asm -o memory.o
nasm -fobj ../image.asm -o image.o
nasm -fobj image_test.asm -o image_test.o
alink.exe -subsys console -oPE ^
image_test.o ^
image.o ^
string.o ^
console.o ^
memory.o ^
file.o ^
-o image_test.exe
del *.o
image_test.exe
del image_test.exe