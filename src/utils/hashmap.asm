[BITS 32]

;struct hashmapelement{
;	int keySizeInBytes;		;0
;	int valueSizeInBytes;	;4
;	void* pkey;				;8
;	void* pvalue;			;12
;}	16 bytes overall

;struct hashmap{
;	vector<haspmapelement> buckets[256];	;0
;}	4096 bytes overall

section .text use32