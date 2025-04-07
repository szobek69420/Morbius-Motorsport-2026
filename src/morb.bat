cls
mkdir build
nasm -fobj main.asm -o build/main.o
nasm -fobj window/window.asm -o build/window.o
nasm -fobj game_loop/game_loop.asm -o build/game_loop.o
nasm -fobj world/chunk_manager4d.asm -o build/chunk_manager4d.o
nasm -fobj world/chunk4d.asm -o build/chunk4d.o
nasm -fobj world/block.asm -o build/block.o
nasm -fobj camera/camera.asm -o build/camera.o
nasm -fobj input/input.asm -o build/input.o
nasm -fobj glfw/glfw.asm -o build/glfw.o
nasm -fobj opengl/opengl.asm -o build/opengl.o
nasm -fobj shader/shader.asm -o build/shader.o
nasm -fobj physics/physics4D.asm -o build/physics4D.o
nasm -fobj physics/collider_group_4D.asm -o build/collider_group_4D.o
nasm -fobj physics/aabb4D.asm -o build/aabb4D.o
nasm -fobj utils/qsort.asm -o build/qsort.o
nasm -fobj utils/thread_safe_queue.asm -o build/thread_safe_queue.o
nasm -fobj utils/thread_safe_value.asm -o build/thread_safe_value.o
nasm -fobj utils/multithreading.asm -o build/multithreading.o
nasm -fobj utils/queue.asm -o build/queue.o
nasm -fobj utils/vector.asm -o build/vector.o
nasm -fobj utils/string.asm -o build/string.o
nasm -fobj utils/console.asm -o build/console.o
nasm -fobj utils/memory.asm -o build/memory.o
nasm -fobj utils/file.asm -o build/file.o
nasm -fobj glm3/vec3.asm -o build/vec3.o
nasm -fobj glm3/vec4.asm -o build/vec4.o
nasm -fobj glm3/mat3.asm -o build/mat3.o
nasm -fobj glm3/mat4.asm -o build/mat4.o
nasm -fobj player/player.asm -o build/player.o
nasm -fobj hypershapes/hyperplane.asm -o build/hyperplane.o
nasm -fobj renderable/hypercube_renderable.asm -o build/hypercube_renderable.o
nasm -fobj renderable/renderable.asm -o build/renderable.o
nasm -fobj renderer/text/font.asm -o build/font.o
nasm -fobj renderer/text/text_renderer.asm -o build/text_renderer.o
nasm -fobj image/image.asm -o build/image.o
nasm -fobj renderer/texture/texture_handler.asm -o build/texture_handler.o
alink.exe -subsys console -oPE ^
build/main.o ^
build/window.o ^
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
cd build
del *.o
del test.exe
cd ..
cd ..
cd game_files
test.exe
cd ..
cd src