[BITS 32]

;layout
;struct tsQueue{
;	Mutex* mutex;			;0
;	Queue* queue;			;4
;}		8 bytes overall

section .text use32

	global tsQueue_init			;void tsQueue_init(tsQueue* buffer, int elementSize, int maxSize)
	global tsQueue_destroy		;void tsQueue_destroy(tsQueue* pqueue)
	
	;returns 0 if there were no problems
	global tsQueue_push			;int tsQueue_push(tsQueue* pqueue, element elementToPush)
	;returns 0 if there were no problems
	;the element doesn't need to be copied onto the stack
	;the element will be added to the queue, not the pointer of the element
	global tsQueue_pushBuffer	;int tsQueue_pushBuffer(tsQueue* pqueue, element* bufferToPush)
	;eturns 0 if there were no problems
	;the elements in the buffer will be added to the queue
	global tsQueue_pushArray	;int tsQueue_pushArray(tsQueue* pqueue, element* arrayOfElement, int elementCount)
	;returns 0 if there were no problems
	global tsQueue_pushFront	;int tsQueue_pushFront(tsQueue* pqueue, element elementToPush)
	;returns 0 if there were no problems
	;the element doesn't need to be copied onto the stack
	;the element will be added to the queue, not the pointer of the element
	global tsQueue_pushBufferFront	;int tsQueue_pushBufferFront(tsQueue* pqueue, element* bufferToPush)
	;eturns 0 if there were no problems
	;the elements in the buffer will be added to the queue
	global tsQueue_pushArrayFront		;int queue_pushArrayFront(tsQueue* pqueue, element* arrayOfElements, int elementCount)
	;returns 0 if there were no problems
	global tsQueue_pop			;int tsQueue_pop(tsQueue* pqueue, element* nullableBuffer)
	;returns 0 if there were no problems
	global tsQueue_peek			;int tsQueue_peek(tsQueue* pqueue, element* buffer)
	
	;index is calculated from the start of the queue, not the start of the allocated element array
	global tsQueue_at			;element* tsQueue_at(tsQueue* pqueue, int index)
	
	global tsQueue_clear		;void tsQueue_clear(tsQueue* pqueue)
	
	global tsQueue_isEmpty		;int tsQueue_isEmpty(tsQueue* pqueue)
	
	global tsQueue_size			;int tsQueue_size(tsQueue* pqueue)
	
	;returns the index of the first matching element, otherwise -1 is returned
	;the comparator must return 0 if a match is found
	global tsQueue_search		;int tsQueue_search(tsQueue* pqueue, int (*comparator)(element*, void* searchKey), void* searchKey)
	
	global tsQueue_forEach		;void tsQueue_forEach(tsQueue* pqueue, void (*function)(element*, void* param), void* param)
	
	global tsQueue_printInfo	;void tsQueue_printInfo(tsQueue* pqueue)
	
	
	extern queue_init
	extern queue_destroy
	extern queue_pushBuffer
	extern queue_pushArray
	extern queue_pushBufferFront
	extern queue_pushArrayFront
	extern queue_pop
	extern queue_peek
	extern queue_at
	extern queue_clear
	extern queue_isEmpty
	extern queue_search
	extern queue_forEach
	extern queue_printInfo
	
	extern mutex_create
	extern mutex_destroy
	extern mutex_lock
	extern mutex_unlock
	
	extern my_malloc
	extern my_free
	
tsQueue_init:
	push ebp
	mov ebp, esp
	
	;create mutex
	call mutex_create
	mov ecx, dword[ebp+8]
	mov dword[ecx], eax
	
	;alloc space for queue
	push 20
	call my_malloc
	mov ecx, dword[ebp+8]
	mov dword[ecx+4], eax
	
	
	;create queue
	push dword[ebp+16]
	push dword[ebp+12]
	push eax
	call queue_init
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsQueue_destroy:
	push ebp
	mov ebp, esp
	
	;destroy mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_destroy
	
	;destroy queue
	mov eax, dword[ebp+8]
	push dword[eax+4]
	call queue_destroy
	
	;dealloc queue
	call my_free
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsQueue_push:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call pushBuffer (it is simpler than calling push)
	lea eax, [ebp+12]
	push eax					;element*
	mov eax, dword[ebp+8]
	push dword[eax+4]			;queue*
	call queue_pushBuffer
	mov dword[ebp-4], eax
	
	;release mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsQueue_pushBuffer:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call pushBuffer
	push dword[ebp+12]			;element*
	mov eax, dword[ebp+8]
	push dword[eax+4]			;queue*
	call queue_pushBuffer
	mov dword[ebp-4], eax
	
	;release mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
tsQueue_pushArray:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call pushArray
	push dword[ebp+16]			;length of array
	push dword[ebp+12]			;array
	mov eax, dword[ebp+8]
	push dword[eax+4]			;queue*
	call queue_pushArray
	mov dword[ebp-4], eax
	
	;release mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
tsQueue_pushFront:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call pushBufferFront (it is simpler than calling push)
	lea eax, [ebp+12]
	push eax					;element*
	mov eax, dword[ebp+8]
	push dword[eax+4]			;queue*
	call queue_pushBufferFront
	mov dword[ebp-4], eax
	
	;release mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsQueue_pushBufferFront:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call pushBufferFront
	push dword[ebp+12]			;element*
	mov eax, dword[ebp+8]
	push dword[eax+4]			;queue*
	call queue_pushBufferFront
	mov dword[ebp-4], eax
	
	;release mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsQueue_pushArrayFront:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call pushArrayFront
	push dword[ebp+16]			;length of array
	push dword[ebp+12]			;array
	mov eax, dword[ebp+8]
	push dword[eax+4]			;queue*
	call queue_pushArrayFront
	mov dword[ebp-4], eax
	
	;release mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
tsQueue_pop:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call pop
	push dword[ebp+12]			;element*
	mov eax, dword[ebp+8]
	push dword[eax+4]			;queue*
	call queue_pop
	mov dword[ebp-4], eax
	
	;release mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsQueue_peek:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call peek
	push dword[ebp+12]			;element*
	mov eax, dword[ebp+8]
	push dword[eax+4]			;queue*
	call queue_peek
	mov dword[ebp-4], eax
	
	;release mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsQueue_at:
	push ebp
	mov ebp, esp
	
	sub esp, 4			;return value
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call at
	push dword[ebp+12]			;index
	mov eax, dword[ebp+8]
	push dword[eax+4]			;queue*
	call queue_at
	mov dword[ebp-4], eax
	
	;release mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
tsQueue_clear:
	push ebp
	mov ebp, esp
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call clear
	mov eax, dword[ebp+8]
	push dword[eax+4]			;queue*
	call queue_clear
	
	;release mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsQueue_isEmpty:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;return value
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call clear
	mov eax, dword[ebp+8]
	push dword[eax+4]			;queue*
	call queue_isEmpty
	mov dword[ebp-4], eax		;save return value
	
	;release mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsQueue_size:
	push ebp
	mov ebp, esp
	
	sub esp, 4				;return value
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;get size
	mov eax, dword[ebp+8]
	mov eax, dword[eax+4]
	mov eax, dword[eax+4]
	mov dword[ebp-4], eax
	
	;release mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsQueue_search:
	push ebp
	mov ebp, esp
	
	sub esp, 4					;return value
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call search
	push dword[ebp+16]
	push dword[ebp+12]
	mov eax, dword[ebp+8]
	push dword[eax+4]			;queue*
	call queue_search
	mov dword[ebp-4], eax
	
	;release mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
tsQueue_forEach:
	push ebp
	mov ebp, esp
	
	sub esp, 4					;return value
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call forEach
	push dword[ebp+16]
	push dword[ebp+12]
	mov eax, dword[ebp+8]
	push dword[eax+4]			;queue*
	call queue_forEach
	mov dword[ebp-4], eax
	
	;release mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	;set return value
	mov eax, dword[ebp-4]
	
	mov esp, ebp
	pop ebp
	ret
	
	
	
tsQueue_printInfo:
	push ebp
	mov ebp, esp
	
	;lock mutex
	mov eax, dword[ebp+8]
	push -1
	push dword[eax]
	call mutex_lock
	
	;call printInfo
	mov eax, dword[ebp+8]
	push dword[eax+4]			;queue*
	call queue_printInfo
	
	;release mutex
	mov eax, dword[ebp+8]
	push dword[eax]
	call mutex_unlock
	
	
	mov esp, ebp
	pop ebp
	ret