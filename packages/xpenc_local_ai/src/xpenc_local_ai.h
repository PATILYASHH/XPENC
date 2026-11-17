// XPENC Local AI — the C surface Dart calls through dart:ffi.
//
// Everything is synchronous and runs on the caller's thread: Dart calls it
// from a background isolate so the UI never waits on it. One chat (llm) and
// one speech model (stt) are open at a time; each handle is owned by the
// isolate that loaded it.
#pragma once

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#if defined(XAI_BUILD)
#define XAI_API __attribute__((visibility("default")))
#else
#define XAI_API
#endif

// Version of this C surface; Dart refuses a library that doesn't match.
XAI_API int32_t xai_abi_version(void);

// ── Chat model (llama.cpp, any GGUF) ────────────────────────────────────────

// Loads the GGUF at [path]. Returns NULL on failure with a reason in [err].
XAI_API void * xai_llm_load(const char * path, int32_t n_ctx, int32_t n_threads,
                            char * err, int32_t err_len);
XAI_API void xai_llm_free(void * llm);

// The model's own description ("qwen2 0.5B Q4_K - Medium"), and its context.
XAI_API int32_t xai_llm_desc(void * llm, char * buf, int32_t len);
XAI_API int32_t xai_llm_n_ctx(void * llm);

// Starts an answer to [n] chat messages, formatted with the model's own chat
// template. [grammar] (GBNF, may be NULL) forces the shape of the answer.
// [temp] <= 0 is greedy. Returns 0, or a negative error:
//   -1 bad template, -2 prompt longer than the context, -3 decode failed,
//   -4 grammar didn't parse.
XAI_API int32_t xai_llm_begin(void * llm, const char ** roles,
                              const char ** contents, int32_t n,
                              const char * grammar, float temp,
                              int32_t max_tokens);

// The next piece of the answer, as raw UTF-8 bytes (a character may split
// across two pieces). Returns the byte count, 0 when the answer is done, or
// a negative error (-3 decode failed).
XAI_API int32_t xai_llm_next(void * llm, char * buf, int32_t len);

// ── Speech to text (whisper.cpp) ────────────────────────────────────────────

XAI_API void * xai_stt_load(const char * path, char * err, int32_t err_len);
XAI_API void xai_stt_free(void * stt);

// Transcribes [n] samples of 16 kHz mono float PCM. [lang] is a whisper code
// ("en", "hi", …) or "auto". Returns the text's byte count, or negative.
XAI_API int32_t xai_stt_transcribe(void * stt, const float * pcm, int32_t n,
                                   const char * lang, int32_t n_threads,
                                   char * out, int32_t out_len);

#ifdef __cplusplus
}
#endif
