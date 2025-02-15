nasm -fobj ../string.asm -o string.o
nasm -fobj ../file.asm -o file.o
nasm -fobj ../console.asm -o console.o
nasm -fobj ../memory.asm -o memory.o
nasm -fobj ../multithreading.asm -o multithreading.o
nasm -fobj thread_test.asm -o thread_test.o
alink.exe -subsys console -oPE ^
thread_test.o ^
multithreading.o ^
string.o ^
console.o ^
memory.o ^
file.o ^
-o thread_test.exe
del *.o
thread_test.exe
del thread_test.exe