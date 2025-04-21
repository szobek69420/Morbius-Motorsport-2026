cls
mkdir build
..\build_tools\nasm.exe -fobj main.asm -o build/main.o
..\build_tools\nasm.exe -fobj window/window.asm -o build/window.o
..\build_tools\nasm.exe -fobj game_loop/game_loop.asm -o build/game_loop.o
..\build_tools\nasm.exe -fobj sun/sun.asm -o build/sun.o
..\build_tools\nasm.exe -fobj world/chunk_manager4d.asm -o build/chunk_manager4d.o
..\build_tools\nasm.exe -fobj world/chunk4d.asm -o build/chunk4d.o
..\build_tools\nasm.exe -fobj world/block.asm -o build/block.o
..\build_tools\nasm.exe -fobj camera/camera.asm -o build/camera.o
..\build_tools\nasm.exe -fobj audio/audio.asm -o build/audio.o
..\build_tools\nasm.exe -fobj input/input.asm -o build/input.o
..\build_tools\nasm.exe -fobj glfw/glfw.asm -o build/glfw.o
..\build_tools\nasm.exe -fobj opengl/opengl.asm -o build/opengl.o
..\build_tools\nasm.exe -fobj shader/shader.asm -o build/shader.o
..\build_tools\nasm.exe -fobj physics/physics4D.asm -o build/physics4D.o
..\build_tools\nasm.exe -fobj physics/collider_group_4D.asm -o build/collider_group_4D.o
..\build_tools\nasm.exe -fobj physics/aabb4D.asm -o build/aabb4D.o
..\build_tools\nasm.exe -fobj utils/qsort.asm -o build/qsort.o
..\build_tools\nasm.exe -fobj utils/thread_safe_queue.asm -o build/thread_safe_queue.o
..\build_tools\nasm.exe -fobj utils/thread_safe_value.asm -o build/thread_safe_value.o
..\build_tools\nasm.exe -fobj utils/multithreading.asm -o build/multithreading.o
..\build_tools\nasm.exe -fobj utils/queue.asm -o build/queue.o
..\build_tools\nasm.exe -fobj utils/vector.asm -o build/vector.o
..\build_tools\nasm.exe -fobj utils/string.asm -o build/string.o
..\build_tools\nasm.exe -fobj utils/console.asm -o build/console.o
..\build_tools\nasm.exe -fobj utils/memory.asm -o build/memory.o
..\build_tools\nasm.exe -fobj utils/file.asm -o build/file.o
..\build_tools\nasm.exe -fobj glm3/vec3.asm -o build/vec3.o
..\build_tools\nasm.exe -fobj glm3/vec4.asm -o build/vec4.o
..\build_tools\nasm.exe -fobj glm3/mat3.asm -o build/mat3.o
..\build_tools\nasm.exe -fobj glm3/mat4.asm -o build/mat4.o
..\build_tools\nasm.exe -fobj player/player.asm -o build/player.o
..\build_tools\nasm.exe -fobj hypershapes/hyperplane.asm -o build/hyperplane.o
..\build_tools\nasm.exe -fobj renderable/hypercube_renderable.asm -o build/hypercube_renderable.o
..\build_tools\nasm.exe -fobj renderable/renderable.asm -o build/renderable.o
..\build_tools\nasm.exe -fobj renderer/text/font.asm -o build/font.o
..\build_tools\nasm.exe -fobj renderer/text/text_renderer.asm -o build/text_renderer.o
..\build_tools\nasm.exe -fobj image/image.asm -o build/image.o
..\build_tools\nasm.exe -fobj renderer/texture/texture_handler.asm -o build/texture_handler.o
..\build_tools\alink.exe -subsys console -oPE ^
build/main.o ^
build/window.o ^
build/sun.o ^
build/player.o ^
build/game_loop.o ^
build/chunk_manager4d.o ^
build/chunk4d.o ^
build/block.o ^
build/camera.o ^
build/input.o ^
build/glfw.o ^
build/texture_handler.o ^
build/image.o ^
build/text_renderer.o ^
build/font.o ^
build/hypercube_renderable.o ^
build/renderable.o ^
build/opengl.o ^
build/shader.o ^
build/player.o ^
build/physics4D.o ^
build/collider_group_4D.o ^
build/aabb4D.o ^
build/hyperplane.o ^
build/mat4.o ^
build/mat3.o ^
build/vec4.o ^
build/vec3.o ^
build/audio.o ^
build/qsort.o ^
build/thread_safe_queue.o ^
build/thread_safe_value.o ^
build/multithreading.o ^
build/queue.o ^
build/vector.o ^
build/string.o ^
build/console.o ^
build/memory.o ^
build/file.o ^
glfw3dll.lib ^
-o build/test.exe
copy build\test.exe ..\game_files
rmdir build /s /q
cd ..
cd game_files
test.exe
cd ..
cd src