// XPENC Local AI — see xpenc_local_ai.h. A thin, defensive layer over
// llama.cpp and whisper.cpp: every failure comes back as a code or message,
// never an abort, so a bad model file can't take the app down with it.
#include "xpenc_local_ai.h"

#include <algorithm>
#include <cstdio>
#include <cstring>
#include <mutex>
#include <string>
#include <vector>

#include "llama.h"
#include "whisper.h"

namespace {

constexpr int32_t kAbiVersion = 1;

void quiet_log(enum ggml_log_level, const char *, void *) {}

std::once_flag g_backend_once;
void ensure_backend() {
  std::call_once(g_backend_once, [] {
    llama_log_set(quiet_log, nullptr);
    whisper_log_set(quiet_log, nullptr);
    llama_backend_init();
  });
}

void set_err(char * err, int32_t err_len, const char * msg) {
  if (err == nullptr || err_len <= 0) return;
  std::snprintf(err, static_cast<size_t>(err_len), "%s", msg);
}

struct Llm {
  llama_model * model = nullptr;
  llama_context * ctx = nullptr;
  const llama_vocab * vocab = nullptr;
  llama_sampler * sampler = nullptr;
  int32_t n_batch = 512;
  int32_t max_tokens = 0;
  int32_t generated = 0;
  bool done = true;
  llama_token pending = LLAMA_TOKEN_NULL;  // sampled, not yet decoded

  ~Llm() {
    if (sampler) llama_sampler_free(sampler);
    if (ctx) llama_free(ctx);
    if (model) llama_model_free(model);
  }
};

// ChatML — what most small instruct models (Qwen, SmolLM…) were tuned on.
// Used only when the model's own template isn't one llama.cpp knows.
std::string chatml(const llama_chat_message * msgs, int32_t n) {
  std::string out;
  for (int32_t i = 0; i < n; i++) {
    out += "<|im_start|>";
    out += msgs[i].role;
    out += "\n";
    out += msgs[i].content;
    out += "<|im_end|>\n";
  }
  out += "<|im_start|>assistant\n";
  return out;
}

bool format_chat(const Llm & llm, const llama_chat_message * msgs, int32_t n,
                 std::string & out) {
  const char * tmpl = llama_model_chat_template(llm.model, nullptr);
  size_t total = 0;
  for (int32_t i = 0; i < n; i++) total += std::strlen(msgs[i].content) + 32;
  std::vector<char> buf(total * 2 + 256);
  int32_t len = llama_chat_apply_template(tmpl, msgs, n, true, buf.data(),
                                          static_cast<int32_t>(buf.size()));
  if (len > static_cast<int32_t>(buf.size())) {
    buf.resize(static_cast<size_t>(len) + 1);
    len = llama_chat_apply_template(tmpl, msgs, n, true, buf.data(),
                                    static_cast<int32_t>(buf.size()));
  }
  if (len < 0) {
    out = chatml(msgs, n);
    return true;
  }
  out.assign(buf.data(), static_cast<size_t>(len));
  return true;
}

}  // namespace

extern "C" {

int32_t xai_abi_version(void) { return kAbiVersion; }

// ── Chat model ───────────────────────────────────────────────────────────────

void * xai_llm_load(const char * path, int32_t n_ctx, int32_t n_threads,
                    char * err, int32_t err_len) {
  ensure_backend();
  auto * llm = new Llm();

  llama_model_params mp = llama_model_default_params();
  mp.n_gpu_layers = 0;
  llm->model = llama_model_load_from_file(path, mp);
  if (llm->model == nullptr) {
    set_err(err, err_len, "This file isn't a model XPENC can open (GGUF).");
    delete llm;
    return nullptr;
  }
  llm->vocab = llama_model_get_vocab(llm->model);

  llama_context_params cp = llama_context_default_params();
  cp.n_ctx = static_cast<uint32_t>(n_ctx > 0 ? n_ctx : 2048);
  cp.n_batch = static_cast<uint32_t>(llm->n_batch);
  cp.n_ubatch = static_cast<uint32_t>(llm->n_batch);
  cp.n_seq_max = 1;
  cp.n_threads = n_threads > 0 ? n_threads : 4;
  cp.n_threads_batch = cp.n_threads;
  cp.no_perf = true;
  llm->ctx = llama_init_from_model(llm->model, cp);
  if (llm->ctx == nullptr) {
    set_err(err, err_len, "Not enough memory to run this model.");
    delete llm;
    return nullptr;
  }
  return llm;
}

void xai_llm_free(void * handle) { delete static_cast<Llm *>(handle); }

int32_t xai_llm_desc(void * handle, char * buf, int32_t len) {
  auto * llm = static_cast<Llm *>(handle);
  if (llm == nullptr || buf == nullptr || len <= 0) return -1;
  return llama_model_desc(llm->model, buf, static_cast<size_t>(len));
}

int32_t xai_llm_n_ctx(void * handle) {
  auto * llm = static_cast<Llm *>(handle);
  return llm == nullptr ? 0 : static_cast<int32_t>(llama_n_ctx(llm->ctx));
}

int32_t xai_llm_begin(void * handle, const char ** roles,
                      const char ** contents, int32_t n, const char * grammar,
                      float temp, int32_t max_tokens) {
  auto * llm = static_cast<Llm *>(handle);
  if (llm == nullptr || n <= 0) return -1;

  std::vector<llama_chat_message> msgs(static_cast<size_t>(n));
  for (int32_t i = 0; i < n; i++) msgs[i] = {roles[i], contents[i]};
  std::string prompt;
  if (!format_chat(*llm, msgs.data(), n, prompt)) return -1;

  const int32_t n_ctx = static_cast<int32_t>(llama_n_ctx(llm->ctx));
  std::vector<llama_token> tokens(prompt.size() + 16);
  int32_t n_tok = llama_tokenize(llm->vocab, prompt.c_str(),
                                 static_cast<int32_t>(prompt.size()),
                                 tokens.data(),
                                 static_cast<int32_t>(tokens.size()), true,
                                 true);
  if (n_tok < 0) {
    tokens.resize(static_cast<size_t>(-n_tok));
    n_tok = llama_tokenize(llm->vocab, prompt.c_str(),
                           static_cast<int32_t>(prompt.size()), tokens.data(),
                           static_cast<int32_t>(tokens.size()), true, true);
  }
  if (n_tok <= 0) return -1;
  const int32_t room = std::max<int32_t>(16, max_tokens);
  if (n_tok + room > n_ctx) return -2;

  if (llm->sampler) {
    llama_sampler_free(llm->sampler);
    llm->sampler = nullptr;
  }
  llama_sampler * chain =
      llama_sampler_chain_init(llama_sampler_chain_default_params());
  if (grammar != nullptr && grammar[0] != '\0') {
    llama_sampler * g = llama_sampler_init_grammar(llm->vocab, grammar, "root");
    if (g == nullptr) {
      llama_sampler_free(chain);
      return -4;
    }
    llama_sampler_chain_add(chain, g);
  }
  llama_sampler_chain_add(
      chain, llama_sampler_init_penalties(llama_vocab_n_tokens(llm->vocab), 64,
                                          1.1f, 0.0f, 0.0f));
  if (temp <= 0.0f) {
    llama_sampler_chain_add(chain, llama_sampler_init_greedy());
  } else {
    llama_sampler_chain_add(chain, llama_sampler_init_top_k(40));
    llama_sampler_chain_add(chain, llama_sampler_init_top_p(0.9f, 1));
    llama_sampler_chain_add(chain, llama_sampler_init_temp(temp));
    llama_sampler_chain_add(chain, llama_sampler_init_dist(LLAMA_DEFAULT_SEED));
  }
  llm->sampler = chain;

  llama_memory_clear(llama_get_memory(llm->ctx), true);
  for (int32_t i = 0; i < n_tok; i += llm->n_batch) {
    const int32_t chunk = std::min(llm->n_batch, n_tok - i);
    if (llama_decode(llm->ctx, llama_batch_get_one(tokens.data() + i, chunk)) !=
        0) {
      return -3;
    }
  }
  llm->max_tokens = room;
  llm->generated = 0;
  llm->pending = LLAMA_TOKEN_NULL;
  llm->done = false;
  return 0;
}

int32_t xai_llm_next(void * handle, char * buf, int32_t len) {
  auto * llm = static_cast<Llm *>(handle);
  if (llm == nullptr || llm->done || llm->sampler == nullptr) return 0;

  // The last piece handed out still has to go through the model.
  if (llm->pending != LLAMA_TOKEN_NULL) {
    llama_token t = llm->pending;
    llm->pending = LLAMA_TOKEN_NULL;
    if (llama_decode(llm->ctx, llama_batch_get_one(&t, 1)) != 0) {
      llm->done = true;
      return -3;
    }
  }
  if (llm->generated >= llm->max_tokens) {
    llm->done = true;
    return 0;
  }

  const llama_token token = llama_sampler_sample(llm->sampler, llm->ctx, -1);
  if (llama_vocab_is_eog(llm->vocab, token)) {
    llm->done = true;
    return 0;
  }
  llm->generated++;
  llm->pending = token;
  const int32_t n = llama_token_to_piece(llm->vocab, token, buf, len, 0, false);
  return n < 0 ? 0 : n;
}

// ── Speech to text ───────────────────────────────────────────────────────────

void * xai_stt_load(const char * path, char * err, int32_t err_len) {
  ensure_backend();
  whisper_context_params cp = whisper_context_default_params();
  cp.use_gpu = false;
  whisper_context * ctx = whisper_init_from_file_with_params(path, cp);
  if (ctx == nullptr) {
    set_err(err, err_len, "This file isn't a speech model XPENC can open.");
  }
  return ctx;
}

void xai_stt_free(void * handle) {
  if (handle) whisper_free(static_cast<whisper_context *>(handle));
}

int32_t xai_stt_transcribe(void * handle, const float * pcm, int32_t n,
                           const char * lang, int32_t n_threads, char * out,
                           int32_t out_len) {
  auto * ctx = static_cast<whisper_context *>(handle);
  if (ctx == nullptr || pcm == nullptr || n <= 0 || out == nullptr) return -1;

  whisper_full_params p = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
  p.n_threads = n_threads > 0 ? n_threads : 4;
  p.translate = false;
  p.no_timestamps = true;
  p.single_segment = false;
  p.print_special = false;
  p.print_progress = false;
  p.print_realtime = false;
  p.print_timestamps = false;
  p.suppress_nst = true;
  p.language = (lang != nullptr && lang[0] != '\0') ? lang : "auto";
  p.detect_language = false;
  if (whisper_full(ctx, p, pcm, n) != 0) return -2;

  std::string text;
  const int segments = whisper_full_n_segments(ctx);
  for (int i = 0; i < segments; i++) {
    const char * s = whisper_full_get_segment_text(ctx, i);
    if (s) text += s;
  }
  const size_t start = text.find_first_not_of(' ');
  text = start == std::string::npos ? "" : text.substr(start);
  const int32_t len = static_cast<int32_t>(
      std::min(text.size(), static_cast<size_t>(out_len > 0 ? out_len - 1 : 0)));
  std::memcpy(out, text.data(), static_cast<size_t>(len));
  out[len] = '\0';
  return len;
}

}  // extern "C"
