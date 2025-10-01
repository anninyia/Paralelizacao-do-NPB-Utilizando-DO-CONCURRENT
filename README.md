# [INCOMPLETO] 🔬 Comparação de Paralelismo em Fortran, _OpenMP_ e _MPI_ com _NAS Parallel Benchmarks_ (NPB)

Este repositório explora e compara diferentes abordagens de paralelismo em Fortran, utilizando:

- 🚀 _DO CONCURRENT_ (paralelismo nativo da linguagem);
- 🧵 _OpenMP_;
- 🌐 _MPI_

Foram implementados três algoritmos do NAS Parallel Benchmark (NPB):

- _Conjugate Gradient_ (_CG_)
- _Multi-Grid_ (_MG_)
- _Fast-Fourier Transform_ (_FFT_)

## 📊 Principais resultados:

- O _DO CONCURRENT_ apresenta desempenho competitivo em aplicações com acesso regular à memória (_CG_ e _MG_).
- Em algoritmos com comunicação global intensiva (_FFT_), o desempenho foi inferior em comparação ao MPI e OpenMP.

## 💡 Este estudo demonstra empiricamente a viabilidade do DO CONCURRENT como alternativa para paralelismo em CPU, oferecendo código mais legível e de fácil manutenção, sem abrir mão da eficiência.
