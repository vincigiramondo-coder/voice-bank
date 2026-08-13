# Third-party notices

Voice Bank source is MIT licensed, but downloaded dependencies and models keep their own licenses. This source repository does not redistribute their wheels, executables, dynamic libraries, or model weights.

| Component | Version or identifier | Source | License | Delivery |
| --- | --- | --- | --- | --- |
| FunASR | 1.3.1 | https://github.com/modelscope/FunASR | MIT | Installed by the user |
| ModelScope SDK | 1.35.3 | https://github.com/modelscope/modelscope | Apache-2.0 | Installed by the user |
| Paraformer model | `iic/speech_seaco_paraformer_large_asr_nat-zh-cn-16k-common-vocab8404-pytorch`, revision `v2.0.9` | https://www.modelscope.cn/models/iic/speech_seaco_paraformer_large_asr_nat-zh-cn-16k-common-vocab8404-pytorch | Apache-2.0 | Downloaded by FunASR; not bundled |
| Punctuation model | `iic/punc_ct-transformer_zh-cn-common-vocab272727-pytorch`, revision `v2.0.4` | https://www.modelscope.cn/models/iic/punc_ct-transformer_zh-cn-common-vocab272727-pytorch | Apache-2.0 | Downloaded by FunASR; not bundled |
| PyTorch / torchaudio | 2.11.0 / 2.11.0 | https://github.com/pytorch/pytorch | BSD-3-Clause | Installed by the user |
| Ollama | Optional, external | https://github.com/ollama/ollama | MIT | Installed separately by the user |
| Gemma 4 | Optional digest `sha256:c6eb396dbd5992bbe3f5cdb947e8bbc0ee413d7c17e2beaae69f5d569cf982eb` (resolved from `gemma4:latest` on 2026-08-11) | https://ollama.com/library/gemma4 | Apache-2.0 model terms | Downloaded separately; not bundled |
| FFmpeg | External system dependency | https://ffmpeg.org | LGPL/GPL depending on build | Installed separately; not bundled |

The full Python environment includes additional transitive packages under their own licenses, including notice-bearing licenses such as MPL-2.0 and LGPL-2.1-or-later. Anyone distributing a future binary bundle must generate a complete dependency notice and perform a separate redistribution review.
