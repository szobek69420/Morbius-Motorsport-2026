[BITS 32]

;OpenGL functions follow stdcall!!!!!!!!!!!!!!!!!!!!

%macro load 2		;loader function (stdcall), gl function name
push name_%2
call %1
mov dword[%2], eax
test eax, eax
jz load_gl_functions_cringe
%endmacro

%macro glFunc 1		;gl function name
%1 resb 4
global %1
%endmacro

%macro glDefine 2		;name, value
%1 dd %2
global %1
%endmacro


section .rodata use32
	load_error db "load_gl_functions: there was an error",10,0
	print_version db "OpenGL version: %s",10,0
	print_vendor_and_renderer db "GPU: %s, %s",10,0
	print_int db "%d",10,0

	;defines (alphabetic order)
	glDefine GL_ALWAYS, 0x207
	glDefine GL_ARRAY_BUFFER, 0x8892
	glDefine GL_BACK, 0x405
	glDefine GL_BLEND, 0xbe2
	glDefine GL_CCW, 0x901
	glDefine GL_CLAMP, 0x2900
	glDefine GL_CLAMP_TO_EDGE, 0x812f
	glDefine GL_COLOR_ATTACHMENT0, 0x8ce0
	glDefine GL_COLOR_ATTACHMENT1, 0x8ce1
	glDefine GL_COLOR_ATTACHMENT2, 0x8ce2
	glDefine GL_COLOR_ATTACHMENT3, 0x8ce3
	glDefine GL_COLOR_ATTACHMENT4, 0x8ce4
	glDefine GL_COLOR_ATTACHMENT5, 0x8ce5
	glDefine GL_COLOR_ATTACHMENT6, 0x8ce6
	glDefine GL_COLOR_ATTACHMENT7, 0x8ce7
	glDefine GL_COLOR_ATTACHMENT8, 0x8ce8
	glDefine GL_COLOR_ATTACHMENT9, 0x8ce9
	glDefine GL_COLOR_ATTACHMENT10, 0x8cea
	glDefine GL_COLOR_ATTACHMENT11, 0x8ceb
	glDefine GL_COLOR_ATTACHMENT12, 0x8cec
	glDefine GL_COLOR_ATTACHMENT13, 0x8ced
	glDefine GL_COLOR_ATTACHMENT14, 0x8cee
	glDefine GL_COLOR_ATTACHMENT15, 0x8cef
	glDefine GL_COLOR_ATTACHMENT16, 0x8cf0
	glDefine GL_COLOR_ATTACHMENT17, 0x8cf1
	glDefine GL_COLOR_ATTACHMENT18, 0x8cf2
	glDefine GL_COLOR_ATTACHMENT19, 0x8cf3
	glDefine GL_COLOR_ATTACHMENT20, 0x8cf4
	glDefine GL_COLOR_ATTACHMENT21, 0x8cf5
	glDefine GL_COLOR_ATTACHMENT22, 0x8cf6
	glDefine GL_COLOR_ATTACHMENT23, 0x8cf7
	glDefine GL_COLOR_ATTACHMENT24, 0x8cf8
	glDefine GL_COLOR_ATTACHMENT25, 0x8cf9
	glDefine GL_COLOR_ATTACHMENT26, 0x8cfa
	glDefine GL_COLOR_ATTACHMENT27, 0x8cfb
	glDefine GL_COLOR_ATTACHMENT28, 0x8cfc
	glDefine GL_COLOR_ATTACHMENT29, 0x8cfd
	glDefine GL_COLOR_ATTACHMENT30, 0x8cfe
	glDefine GL_COLOR_ATTACHMENT31, 0x8cff
	glDefine GL_COLOR_BUFFER_BIT, 0x00004000
	glDefine GL_COMPILE_STATUS, 0x8b81
	glDefine GL_CONSTANT_ALPHA, 0x8003
	glDefine GL_CONSTANT_COLOR, 0x8001
	glDefine GL_CULL_FACE, 0xb44
	glDefine GL_CW, 0x900
	glDefine GL_DEPTH_ATTACHMENT, 0x8d00
	glDefine GL_DEPTH_BUFFER_BIT, 0x100
	glDefine GL_DEPTH_COMPONENT, 0x1902
	glDefine GL_DEPTH_STENCIL, 0x84f9
	glDefine GL_DEPTH_STENCIL_ATTACHMENT, 0x821a
	glDefine GL_DEPTH_TEST, 0xb71
	glDefine GL_DEPTH24_STENCIL8, 0x88f0
	glDefine GL_DRAW_FRAMEBUFFER, 0x8ca9
	glDefine GL_DST_ALPHA, 0x304
	glDefine GL_DST_COLOR, 0x306
	glDefine GL_DYNAMIC_DRAW, 0x88e8
	glDefine GL_ELEMENT_ARRAY_BUFFER, 0x8893
	glDefine GL_EQUAL, 0x202
	glDefine GL_FALSE, 0x0
	glDefine GL_FLOAT, 0x1406
	glDefine GL_FRAGMENT_SHADER, 0x8b30
	glDefine GL_FRAMEBUFFER, 0x8d40
	glDefine GL_FRAMEBUFFER_COMPLETE, 0x8cd5
	glDefine GL_FRONT, 0x404
	glDefine GL_FRONT_AND_BACK, 0x408
	glDefine GL_FUNC_ADD, 0x8006
	glDefine GL_FUNC_REVERSE_SUBTRACT, 0x800b
	glDefine GL_FUNC_SUBTRACT, 0x800a
	glDefine GL_GEOMETRY_SHADER, 0x8dd9
	glDefine GL_GEQUAL, 0x206
	glDefine GL_GREATER, 0x204
	glDefine GL_LESS, 0x201
	glDefine GL_LEQUAL, 0x203
	glDefine GL_LINEAR, 0x2601
	glDefine GL_LINES, 0x1
	glDefine GL_LINK_STATUS, 0x8b82
	glDefine GL_MAX, 0x8008
	glDefine GL_MIN, 0x8007
	glDefine GL_NEAREST, 0x2600
	glDefine GL_NEVER, 0x200
	glDefine GL_NOTEQUAL, 0x205
	glDefine GL_ONE, 0x1
	glDefine GL_ONE_MINUS_CONSTANT_ALPHA, 0x8004
	glDefine GL_ONE_MINUS_CONSTANT_COLOR, 0x8002
	glDefine GL_ONE_MINUS_DST_ALPHA, 0x305
	glDefine GL_ONE_MINUS_DST_COLOR, 0x307
	glDefine GL_ONE_MINUS_SRC_ALPHA, 0x303
	glDefine GL_ONE_MINUS_SRC_COLOR, 0x301
	glDefine GL_POINTS, 0x0
	glDefine GL_READ_FRAMEBUFFER, 0x8ca8
	glDefine GL_RED, 0x1903
	glDefine GL_RENDERBUFFER, 0x8d41
	glDefine GL_RENDERER, 0x1f01
	glDefine GL_REPEAT, 0x2901
	glDefine GL_RGB, 0x1907
	glDefine GL_RGB16F, 0x881b
	glDefine GL_RGB8, 0x8051
	glDefine GL_RGBA, 0x1908
	glDefine GL_RGBA16F, 0x881a
	glDefine GL_RGBA8, 0x8058
	glDefine GL_SRC_ALPHA, 0x302
	glDefine GL_SRC_COLOR, 0x300
	glDefine GL_STATIC_DRAW, 0x88e4
	glDefine GL_STENCIL_ATTACHMENT, 0x8d20
	glDefine GL_STENCIL_INDEX, 0x1901
	glDefine GL_TEXTURE_2D, 0xde1
	glDefine GL_TEXTURE_2D_ARRAY, 0x8c1a
	glDefine GL_TEXTURE_MAG_FILTER, 0x2800
	glDefine GL_TEXTURE_MIN_FILTER, 0x2801
	glDefine GL_TEXTURE_WRAP_S, 0x2802
	glDefine GL_TEXTURE_WRAP_T, 0x2803
	glDefine GL_TEXTURE0, 0x84c0
	glDefine GL_TEXTURE1, 0x84c1
	glDefine GL_TEXTURE2, 0x84c2
	glDefine GL_TEXTURE3, 0x84c3
	glDefine GL_TEXTURE4, 0x84c4
	glDefine GL_TEXTURE5, 0x84c5
	glDefine GL_TEXTURE6, 0x84c6
	glDefine GL_TEXTURE7, 0x84c7
	glDefine GL_TEXTURE8, 0x84c8
	glDefine GL_TEXTURE9, 0x84c9
	glDefine GL_TEXTURE10, 0x84ca
	glDefine GL_TEXTURE11, 0x84cb
	glDefine GL_TEXTURE12, 0x84cc
	glDefine GL_TEXTURE13, 0x84cd
	glDefine GL_TEXTURE14, 0x84ce
	glDefine GL_TEXTURE15, 0x84cf
	glDefine GL_TEXTURE16, 0x84d0
	glDefine GL_TEXTURE17, 0x84d1
	glDefine GL_TEXTURE18, 0x84d2
	glDefine GL_TEXTURE19, 0x84d3
	glDefine GL_TEXTURE20, 0x84d4
	glDefine GL_TEXTURE21, 0x84d5
	glDefine GL_TEXTURE22, 0x84d6
	glDefine GL_TEXTURE23, 0x84d7
	glDefine GL_TEXTURE24, 0x84d8
	glDefine GL_TEXTURE25, 0x84d9
	glDefine GL_TEXTURE26, 0x84da
	glDefine GL_TEXTURE27, 0x84db
	glDefine GL_TEXTURE28, 0x84dc
	glDefine GL_TEXTURE29, 0x84dd
	glDefine GL_TEXTURE30, 0x84de
	glDefine GL_TEXTURE31, 0x84df
	glDefine GL_TRIANGLE_FAN, 0x6
	glDefine GL_TRIANGLES, 0x4
	glDefine GL_TRUE, 0x1
	glDefine GL_UNPACK_ALIGNMENT, 0xcf5
	glDefine GL_UNSIGNED_BYTE, 0x1401
	glDefine GL_UNSIGNED_INT, 0x1405
	glDefine GL_UNSIGNED_INT_24_8, 0x84fa
	glDefine GL_VENDOR, 0x1f00
	glDefine GL_VERSION, 0x1f02
	glDefine GL_VERTEX_SHADER, 0x8b31
	glDefine GL_ZERO, 0x0
	

	;function names (alphabetic order)
	name_glActiveTexture db "glActiveTexture",0
	name_glAttachShader db "glAttachShader",0
	name_glBlendEquation db "glBlendEquation",0
	name_glBlendFunc db "glBlendFunc",0
	name_glBlendFuncSeparate db "glBlendFuncSeparate",0
	name_glBindBuffer db "glBindBuffer",0
	name_glBindFramebuffer db "glBindFramebuffer",0
	name_glBindRenderbuffer db "glBindRenderbuffer",0
	name_glBindTexture db "glBindTexture",0
	name_glBindVertexArray db "glBindVertexArray",0
	name_glBlitFramebuffer db "glBlitFramebuffer",0
	name_glBufferData db "glBufferData",0
	name_glBufferSubData db "glBufferSubData",0
	name_glCheckFramebufferStatus db "glCheckFramebufferStatus",0
	name_glClear db "glClear",0
	name_glClearColor db "glClearColor",0
	name_glClearDepth db "glClearDepth",0
	name_glCompileShader db "glCompileShader",0
	name_glCreateProgram db "glCreateProgram",0
	name_glCreateShader db "glCreateShader",0
	name_glCullFace db "glCullFace",0
	name_glDeleteBuffers db "glDeleteBuffers",0
	name_glDeleteFramebuffers db "glDeleteFramebuffers",0
	name_glDeleteProgram db "glDeleteProgram",0
	name_glDeleteRenderbuffers db "glDeleteRenderbuffers",0
	name_glDeleteShader db "glDeleteShader",0
	name_glDeleteTextures db "glDeleteTextures",0
	name_glDeleteVertexArrays db "glDeleteVertexArrays",0
	name_glDepthFunc db "glDepthFunc",0
	name_glDepthMask db "glDepthMask",0
	name_glDisable db "glDisable",0
	name_glDisableVertexAttribArray db "glDisableVertexAttribArray",0
	name_glDrawArrays db "glDrawArrays",0
	name_glDrawArraysInstanced db "glDrawArraysInstanced",0
	name_glDrawBuffers db "glDrawBuffers",0
	name_glDrawElements db "glDrawElements",0
	name_glDrawElementsInstanced db "glDrawElementsInstanced",0
	name_glEnable db "glEnable",0
	name_glEnableVertexAttribArray db "glEnableVertexAttribArray",0
	name_glFramebufferRenderbuffer db "glFramebufferRenderbuffer",0
	name_glFramebufferTexture2D db "glFramebufferTexture2D",0
	name_glFrontFace db "glFrontFace",0
	name_glGenBuffers db "glGenBuffers",0
	name_glGenerateMipmap db "glGenerateMipmap",0
	name_glGenFramebuffers db "glGenFramebuffers",0
	name_glGenRenderbuffers db "glGenRenderbuffers",0
	name_glGenTextures db "glGenTextures",0
	name_glGenVertexArrays db "glGenVertexArrays",0
	name_glGetError db "glGetError",0
	name_glGetProgramInfoLog db "glGetProgramInfoLog",0
	name_glGetProgramiv db "glGetProgramiv",0
	name_glGetShaderInfoLog db "glGetShaderInfoLog",0
	name_glGetShaderiv db "glGetShaderiv",0
	name_glGetString db "glGetString",0
	name_glGetUniformLocation db "glGetUniformLocation",0
	name_glLinkProgram db "glLinkProgram",0
	name_glPixelStorei db "glPixelStorei",0
	name_glReadPixels db "glReadPixels",0
	name_glRenderbufferStorage db "glRenderbufferStorage",0
	name_glShaderSource db "glShaderSource",0
	name_glTexImage2D db "glTexImage2D",0
	name_glTexParameteri db "glTexParameteri",0
	name_glTexStorage3D db "glTexStorage3D",0
	name_glTexSubImage3D db "glTexSubImage3D",0
	name_glUniform1f db "glUniform1f",0
	name_glUniform1fv db "glUniform1fv",0
	name_glUniform1i db "glUniform1i",0
	name_glUniform1iv db "glUniform1iv",0
	name_glUniform2f db "glUniform2f",0
	name_glUniform2fv db "glUniform2fv",0
	name_glUniform2i db "glUniform2i",0
	name_glUniform2iv db "glUniform2iv",0
	name_glUniform3f db "glUniform3f",0
	name_glUniform3fv db "glUniform3fv",0
	name_glUniform3i db "glUniform3i",0
	name_glUniform3iv db "glUniform3iv",0
	name_glUniform4f db "glUniform4f",0
	name_glUniform4fv db "glUniform4fv",0
	name_glUniform4i db "glUniform4i",0
	name_glUniform4iv db "glUniform4iv",0
	name_glUniformMatrix2fv db "glUniformMatrix2fv",0
	name_glUniformMatrix3fv db "glUniformMatrix3fv",0
	name_glUniformMatrix4fv db "glUniformMatrix4fv",0
	name_glUseProgram db "glUseProgram",0
	name_glVertexAttribDivisor db "glVertexAttribDivisor",0
	name_glVertexAttribIPointer db "glVertexAttribIPointer",0
	name_glVertexAttribPointer db "glVertexAttribPointer",0
	name_glViewport db "glViewport",0


section .bss use32
	;function pointers (alphabetic order)
	glFunc glActiveTexture
	glFunc glAttachShader
	glFunc glBlendEquation
	glFunc glBlendFunc
	glFunc glBlendFuncSeparate
	glFunc glBindBuffer
	glFunc glBindFramebuffer
	glFunc glBindRenderbuffer
	glFunc glBindTexture
	glFunc glBindVertexArray
	glFunc glBlitFramebuffer
	glFunc glBufferData
	glFunc glBufferSubData
	glFunc glCheckFramebufferStatus
	glFunc glClear
	glFunc glClearColor
	glFunc glClearDepth
	glFunc glCompileShader
	glFunc glCreateProgram
	glFunc glCreateShader
	glFunc glCullFace
	glFunc glDeleteBuffers
	glFunc glDeleteFramebuffers
	glFunc glDeleteProgram
	glFunc glDeleteRenderbuffers
	glFunc glDeleteShader
	glFunc glDeleteTextures
	glFunc glDeleteVertexArrays
	glFunc glDepthFunc
	glFunc glDepthMask
	glFunc glDisable
	glFunc glDisableVertexAttribArray
	glFunc glDrawArrays
	glFunc glDrawArraysInstanced
	glFunc glDrawBuffers
	glFunc glDrawElements
	glFunc glDrawElementsInstanced
	glFunc glEnable
	glFunc glEnableVertexAttribArray
	glFunc glFramebufferRenderbuffer
	glFunc glFramebufferTexture2D
	glFunc glFrontFace
	glFunc glGenBuffers
	glFunc glGenerateMipmap
	glFunc glGenFramebuffers
	glFunc glGenRenderbuffers
	glFunc glGenTextures
	glFunc glGenVertexArrays
	glFunc glGetError
	glFunc glGetProgramInfoLog
	glFunc glGetProgramiv
	glFunc glGetShaderInfoLog
	glFunc glGetShaderiv
	glFunc glGetString
	glFunc glGetUniformLocation
	glFunc glLinkProgram
	glFunc glPixelStorei
	glFunc glReadPixels
	glFunc glRenderbufferStorage
	glFunc glShaderSource
	glFunc glTexImage2D
	glFunc glTexParameteri
	glFunc glTexStorage3D
	glFunc glTexSubImage3D
	glFunc glUniform1f
	glFunc glUniform1fv
	glFunc glUniform1i
	glFunc glUniform1iv
	glFunc glUniform2f
	glFunc glUniform2fv
	glFunc glUniform2i
	glFunc glUniform2iv
	glFunc glUniform3f
	glFunc glUniform3fv
	glFunc glUniform3i
	glFunc glUniform3iv
	glFunc glUniform4f
	glFunc glUniform4fv
	glFunc glUniform4i
	glFunc glUniform4iv
	glFunc glUniformMatrix2fv
	glFunc glUniformMatrix3fv
	glFunc glUniformMatrix4fv
	glFunc glUseProgram
	glFunc glVertexAttribDivisor
	glFunc glVertexAttribIPointer
	glFunc glVertexAttribPointer
	glFunc glViewport

section .text use32

	global load_gl_functions	;int load_gl_functions(function* (*glFunctionLoader)(const char*)) ,  returns 0 if an error happened
	
	extern my_printf
	
load_gl_functions:
	push ebp
	mov ebp, esp
	
	;load functions (alphabetic order)
	load dword[ebp+8], glActiveTexture
	load dword[ebp+8], glAttachShader
	load dword[ebp+8], glBlendEquation
	load dword[ebp+8], glBlendFunc
	load dword[ebp+8], glBlendFuncSeparate
	load dword[ebp+8], glBindBuffer
	load dword[ebp+8], glBindFramebuffer
	load dword[ebp+8], glBindRenderbuffer
	load dword[ebp+8], glBindTexture
	load dword[ebp+8], glBindVertexArray
	load dword[ebp+8], glBlitFramebuffer
	load dword[ebp+8], glBufferData
	load dword[ebp+8], glBufferSubData
	load dword[ebp+8], glCheckFramebufferStatus
	load dword[ebp+8], glClear
	load dword[ebp+8], glClearColor
	load dword[ebp+8], glClearDepth
	load dword[ebp+8], glCompileShader
	load dword[ebp+8], glCreateProgram
	load dword[ebp+8], glCreateShader
	load dword[ebp+8], glCullFace
	load dword[ebp+8], glDeleteBuffers
	load dword[ebp+8], glDeleteFramebuffers
	load dword[ebp+8], glDeleteProgram
	load dword[ebp+8], glDeleteRenderbuffers
	load dword[ebp+8], glDeleteShader
	load dword[ebp+8], glDeleteTextures
	load dword[ebp+8], glDeleteVertexArrays
	load dword[ebp+8], glDepthFunc
	load dword[ebp+8], glDepthMask
	load dword[ebp+8], glDisable
	load dword[ebp+8], glDisableVertexAttribArray
	load dword[ebp+8], glDrawArrays
	load dword[ebp+8], glDrawArraysInstanced
	load dword[ebp+8], glDrawBuffers
	load dword[ebp+8], glDrawElements
	load dword[ebp+8], glDrawElementsInstanced
	load dword[ebp+8], glEnable
	load dword[ebp+8], glEnableVertexAttribArray
	load dword[ebp+8], glFramebufferRenderbuffer
	load dword[ebp+8], glFramebufferTexture2D
	load dword[ebp+8], glFrontFace
	load dword[ebp+8], glGenBuffers
	load dword[ebp+8], glGenerateMipmap
	load dword[ebp+8], glGenFramebuffers
	load dword[ebp+8], glGenRenderbuffers
	load dword[ebp+8], glGenTextures
	load dword[ebp+8], glGenVertexArrays
	load dword[ebp+8], glGetError
	load dword[ebp+8], glGetProgramInfoLog
	load dword[ebp+8], glGetProgramiv
	load dword[ebp+8], glGetShaderInfoLog
	load dword[ebp+8], glGetShaderiv
	load dword[ebp+8], glGetString
	load dword[ebp+8], glGetUniformLocation
	load dword[ebp+8], glLinkProgram
	load dword[ebp+8], glPixelStorei
	load dword[ebp+8], glReadPixels
	load dword[ebp+8], glRenderbufferStorage
	load dword[ebp+8], glShaderSource
	load dword[ebp+8], glTexImage2D
	load dword[ebp+8], glTexParameteri
	load dword[ebp+8], glTexStorage3D
	load dword[ebp+8], glTexSubImage3D
	load dword[ebp+8], glUniform1i
	load dword[ebp+8], glUniform1iv
	load dword[ebp+8], glUniform1f
	load dword[ebp+8], glUniform1fv
	load dword[ebp+8], glUniform2i
	load dword[ebp+8], glUniform2iv
	load dword[ebp+8], glUniform2f
	load dword[ebp+8], glUniform2fv
	load dword[ebp+8], glUniform3i
	load dword[ebp+8], glUniform3iv
	load dword[ebp+8], glUniform3f
	load dword[ebp+8], glUniform3fv
	load dword[ebp+8], glUniform4i
	load dword[ebp+8], glUniform4iv
	load dword[ebp+8], glUniform4f
	load dword[ebp+8], glUniform4fv
	load dword[ebp+8], glUniformMatrix2fv
	load dword[ebp+8], glUniformMatrix3fv
	load dword[ebp+8], glUniformMatrix4fv
	load dword[ebp+8], glUseProgram
	load dword[ebp+8], glVertexAttribDivisor
	load dword[ebp+8], glVertexAttribIPointer
	load dword[ebp+8], glVertexAttribPointer
	load dword[ebp+8], glViewport
	
	;get version
	cmp dword[glGetString], 0
	je load_gl_functions_cringe
	
	push dword[GL_VERSION]
	call [glGetString]
	test eax, eax
	jz load_gl_functions_cringe
	
	push eax
	push print_version
	call my_printf
	add esp, 8
	
	;get vendor and renderer
	push dword[GL_RENDERER]
	call [glGetString]
	test eax, eax
	jz load_gl_functions_cringe
	push eax
	push dword[GL_VENDOR]
	call [glGetString]
	test eax, eax
	jz load_gl_functions_cringe
	push eax
	push print_vendor_and_renderer
	call my_printf
	add esp, 12
	
	
	jmp load_gl_functions_successful
	load_gl_functions_cringe:
		push load_error
		call my_printf
	
		mov eax, 0
		mov esp, ebp
		pop ebp
		ret
	
	load_gl_functions_successful:
	mov eax, 69
	mov esp, ebp
	pop ebp
	ret