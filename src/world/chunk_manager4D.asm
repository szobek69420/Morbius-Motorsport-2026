[BITS 32]

;layout:
;struct ChunkManager4D{
;	vector<Chunk4D*> loadedChunks;								0
;	Mutex* loadedChunksMutex;									16
;	tsQueue<ChunkGraphicsUpdate4D*> pendingGraphicsUpdates;		20
;	GLuint shader;												28
;	HyperPlane hyperPlane;										32
;	hashMap<ivec3, ChangedBlockInfo>* changedBlocks;			96 //doesn't need a mutex as it is used only on the chunk generation thread
;	padding of 12 bytes
;	tsQueue<PendingChangedBlockInfo> pendingChangedBlocks;		112
;	TextureArrayInfo* blockTextures;							120
;	vector<ivec3> veteranChunks;								124 //chunks that have been loaded at least once
;	vector<struct{ivec3;Renderable*;int id}> fanthomChunks;			140 //fanthom chunks are remaining renderables of no longer existing chunks, they are kept during a reload to prevent flickering
;	Mutex* fanthomChunkMutex;									156
;}			160 bytes overall