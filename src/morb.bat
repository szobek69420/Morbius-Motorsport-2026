setlocal

set BARE_COMMAND=..\build_tools\nasm.exe
set OPTIMIZATION_FLAG=-O0

if "%~1" == "harder" (set OPTIMIZATION_FLAG=-Ox)

set COMMAND=%BARE_COMMAND% %OPTIMIZATION_FLAG%

mkdir build
%COMMAND% -fobj main.asm -o build/main.o
%COMMAND% -fobj window/window.asm -o build/window.o
%COMMAND% -fobj game_loop/game_states.asm -o build/game_states.o
%COMMAND% -fobj game_loop/settings_loop.asm -o build/settings_loop.o
%COMMAND% -fobj game_loop/menu_loop.asm -o build/menu_loop.o
%COMMAND% -fobj game_loop/game_loop.asm -o build/game_loop.o
%COMMAND% -fobj inventory/inventory_ui.asm -o build/inventory_ui.o
%COMMAND% -fobj inventory/inventory_atlas.asm -o build/inventory_atlas.o
%COMMAND% -fobj inventory/hand.asm -o build/hand.o
%COMMAND% -fobj sun/sun.asm -o build/sun.o
%COMMAND% -fobj sun/sky.asm -o build/sky.o
%COMMAND% -fobj world/chunk_manager4d.asm -o build/chunk_manager4d.o
%COMMAND% -fobj world/chunk4d.asm -o build/chunk4d.o
%COMMAND% -fobj world/block.asm -o build/block.o
%COMMAND% -fobj camera/camera.asm -o build/camera.o
%COMMAND% -fobj audio/sigmaudio_conversion.asm -o build/sigmaudio_conversion.o
%COMMAND% -fobj audio/sigmaudio.asm -o build/sigmaudio.o
%COMMAND% -fobj audio/audio.asm -o build/audio.o
%COMMAND% -fobj input/input.asm -o build/input.o
%COMMAND% -fobj glfw/glfw.asm -o build/glfw.o
%COMMAND% -fobj opengl/opengl.asm -o build/opengl.o
%COMMAND% -fobj shader/shader.asm -o build/shader.o
%COMMAND% -fobj ui/ui_slider.asm -o build/ui_slider.o
%COMMAND% -fobj ui/ui_button.asm -o build/ui_button.o
%COMMAND% -fobj ui/ui_text.asm -o build/ui_text.o
%COMMAND% -fobj ui/ui_image.asm -o build/ui_image.o
%COMMAND% -fobj ui/ui_canvas.asm -o build/ui_canvas.o
%COMMAND% -fobj ui/ui_empty.asm -o build/ui_empty.o
%COMMAND% -fobj ui/ui_element.asm -o build/ui_element.o
%COMMAND% -fobj physics/physics4D.asm -o build/physics4D.o
%COMMAND% -fobj physics/collider_group_4D.asm -o build/collider_group_4D.o
%COMMAND% -fobj physics/aabb4D.asm -o build/aabb4D.o
%COMMAND% -fobj debug/memory_usage_diagram.asm -o build/memory_usage_diagram.o
%COMMAND% -fobj utils/animation_curve.asm -o build/animation_curve.o
%COMMAND% -fobj utils/perlin.asm -o build/perlin.o
%COMMAND% -fobj utils/math.asm -o build/math.o
%COMMAND% -fobj utils/qsort.asm -o build/qsort.o
%COMMAND% -fobj utils/thread_safe_vector.asm -o build/thread_safe_vector.o
%COMMAND% -fobj utils/thread_safe_queue.asm -o build/thread_safe_queue.o
%COMMAND% -fobj utils/thread_safe_value.asm -o build/thread_safe_value.o
%COMMAND% -fobj utils/multithreading.asm -o build/multithreading.o
%COMMAND% -fobj utils/queue.asm -o build/queue.o
%COMMAND% -fobj utils/hashmap.asm -o build/hashmap.o
%COMMAND% -fobj utils/vector.asm -o build/vector.o
%COMMAND% -fobj utils/string.asm -o build/string.o
%COMMAND% -fobj utils/console.asm -o build/console.o
%COMMAND% -fobj utils/meminfo.asm -o build/meminfo.o
%COMMAND% -fobj utils/memory.asm -o build/memory.o
%COMMAND% -fobj utils/file.asm -o build/file.o
%COMMAND% -fobj utils/ctype.asm -o build/ctype.o
%COMMAND% -fobj utils/cvt.asm -o build/cvt.o
%COMMAND% -fobj glm3/vec3.asm -o build/vec3.o
%COMMAND% -fobj glm3/vec4.asm -o build/vec4.o
%COMMAND% -fobj glm3/mat3.asm -o build/mat3.o
%COMMAND% -fobj glm3/mat4.asm -o build/mat4.o
%COMMAND% -fobj settings/settings.asm -o build/settings.o
%COMMAND% -fobj player/player.asm -o build/player.o
%COMMAND% -fobj hypershapes/hyperplane.asm -o build/hyperplane.o
%COMMAND% -fobj renderable/hypercube_renderable.asm -o build/hypercube_renderable.o
%COMMAND% -fobj renderable/geometry_importer.asm -o build/geometry_importer.o
%COMMAND% -fobj renderable/renderable.asm -o build/renderable.o
%COMMAND% -fobj renderer/text/font.asm -o build/font.o
%COMMAND% -fobj renderer/text/text_renderer.asm -o build/text_renderer.o
%COMMAND% -fobj renderer/post_processing/post_processing.asm -o build/post_processing.o
%COMMAND% -fobj renderer/framebuffer/framebuffer.asm -o build/framebuffer.o
%COMMAND% -fobj image/image.asm -o build/image.o
%COMMAND% -fobj renderer/texture/texture_handler.asm -o build/texture_handler.o
..\build_tools\alink.exe -subsys console -oPE ^
build/main.o ^
build/window.o ^
build/settings.o ^
build/sun.o ^
build/sky.o ^
build/inventory_ui.o ^
build/inventory_atlas.o ^
build/hand.o ^
build/player.o ^
build/game_states.o ^
build/settings_loop.o ^
build/menu_loop.o ^
build/game_loop.o ^
build/chunk_manager4d.o ^
build/chunk4d.o ^
build/block.o ^
build/camera.o ^
build/input.o ^
build/glfw.o ^
build/post_processing.o ^
build/framebuffer.o ^
build/texture_handler.o ^
build/image.o ^
build/text_renderer.o ^
build/font.o ^
build/hypercube_renderable.o ^
build/geometry_importer.o ^
build/renderable.o ^
build/opengl.o ^
build/shader.o ^
build/player.o ^
build/ui_slider.o ^
build/ui_button.o ^
build/ui_text.o ^
build/ui_image.o ^
build/ui_canvas.o ^
build/ui_empty.o ^
build/ui_element.o ^
build/physics4D.o ^
build/collider_group_4D.o ^
build/aabb4D.o ^
build/hyperplane.o ^
build/mat4.o ^
build/mat3.o ^
build/vec4.o ^
build/vec3.o ^
build/sigmaudio_conversion.o ^
build/sigmaudio.o ^
build/audio.o ^
build/memory_usage_diagram.o ^
build/animation_curve.o ^
build/perlin.o ^
build/math.o ^
build/qsort.o ^
build/thread_safe_vector.o ^
build/thread_safe_queue.o ^
build/thread_safe_value.o ^
build/multithreading.o ^
build/queue.o ^
build/hashmap.o ^
build/vector.o ^
build/string.o ^
build/console.o ^
build/meminfo.o ^
build/memory.o ^
build/file.o ^
build/ctype.o ^
build/cvt.o ^
glfw3dll.lib ^
-o build/test.exe
copy build\test.exe ..\game_files
rmdir build /s /q
cd ..
cd game_files
test.exe

endlocal