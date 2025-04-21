[BITS 32]

;struct WaveHeader{
;	char chunkId[4];			;0	//should be "RIFF"
;	uint32 chunkSize;			;4	//file size - 8
;	char fileType[4];			;8	//should be "WAVE"
;	char formatChunkMarker[4];	;12	//should be "fmt "
;	uint32 formatChunkSize;		;16
;	uint16 audioFormat;			;20	//1 is PCM
;	uint16 numberOfChannels;	;22
;	uint32 sampleRate;			;24
;	uint32 byteRate;			;28
;	uint16 bytesPerSampleFrame;	;32
;	uint16 bitsPerSample;		;34
;}	36 bytes overall

section .rodata use32
	error_read_failure db "audio_readWaveHeader: couldn't read the file %s",10,0
	error_invalid_chunkId db "audio_readWaveHeader: couldn't read wave header of %s due to an invalid chunk ID",10,0
	error_invalid_fileType db "audio_readWaveHeader: couldn't read wave header of %s due to an invalid file type",10,0
	error_invalid_formatChunkMarker db "audio_readWaveHeader: couldn't read wave header of %s due to missing format chunk marker",10,0

section .text use32
	
	global audio_playSound
	

;returns zero, if there was no problem
;int audio_readWaveHeader(const char* filePath, WaveHeader* headerBuffer)
audio_readWaveHeader:
	push ebp
	mov ebp, esp
	
	
	
	mov esp, ebp
	pop ebp
	ret