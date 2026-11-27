pacman::p_load(read.dbc, arrow, tidyverse)

# ---- 0. Função de correção de encoding ---------------------------------

corrigir_encoding_utf8 <- function(df, encoding_origem = "latin1") {
  df[] <- lapply(df, function(coluna) {
    if (is.character(coluna)) {
      Encoding(coluna) <- encoding_origem
      coluna <- iconv(coluna, from = encoding_origem, to = "UTF-8", sub = "byte")
    }
    coluna
  })
  df
}

# ---- 1. Configurações ---------------------------------------------------

caminho_csv <- "sia_alterados_ontem.csv"  

# Se TRUE, converte apenas as linhas com existe_parquet == FALSE
# Se FALSE (padrão), converte TODAS as linhas, regravando tudo.
somente_pendentes <- FALSE

encoding_origem <- "latin1"   

# ---- 2. Leitura do CSV de controle ---------------------------------------

registros <- read_csv(caminho_csv, show_col_types = FALSE)

if (somente_pendentes) {
  registros <- registros %>% filter(existe_parquet == FALSE)
}

cat(sprintf("Total de arquivos a converter: %d\n\n", nrow(registros)))

# ---- 3. Função de conversão individual -----------------------------------

converter_dbc_para_parquet <- function(caminho_origem, caminho_destino,
                                       encoding_origem = "latin1") {

  dir_destino <- dirname(caminho_destino)
  if (!dir.exists(dir_destino)) {
    dir.create(dir_destino, recursive = TRUE)
  }
  
  resultado <- tryCatch({
    dados <- read.dbc::read.dbc(caminho_origem)
    dados <- corrigir_encoding_utf8(dados, encoding_origem)
    arrow::write_parquet(dados, caminho_destino)
    list(status = "OK", n_linhas = nrow(dados), erro = NA_character_)
  }, error = function(e) {
    list(status = "ERRO", n_linhas = NA_integer_, erro = conditionMessage(e))
  })
  
  data.frame(
    caminho_origem  = caminho_origem,
    caminho_destino = caminho_destino,
    status          = resultado$status,
    n_linhas        = resultado$n_linhas,
    erro            = resultado$erro,
    stringsAsFactors = FALSE
  )
}

# ---- 4. Loop de conversão -------------------------------------------------

log_conversao <- vector("list", nrow(registros))

for (i in seq_len(nrow(registros))) {
  origem  <- registros$caminho_origem[i]
  destino <- registros$caminho_destino[i]
  
  cat(sprintf("[%d/%d] %s -> %s\n", i, nrow(registros), basename(origem), destino))
  
  log_conversao[[i]] <- converter_dbc_para_parquet(origem, destino, encoding_origem)
  
  gc(verbose = FALSE)
}

log_final <- do.call(rbind, log_conversao)

# ---- 5. Resumo e gravação do log ------------------------------------------

caminho_log <- file.path(dirname(caminho_csv), "log_conversao_sia_alterados.csv")
write_csv(log_final, caminho_log)

cat("\n===== RESUMO =====\n")
cat(sprintf("Sucesso: %d\n", sum(log_final$status == "OK")))
cat(sprintf("Erro:    %d\n", sum(log_final$status == "ERRO")))
cat(sprintf("Log salvo em: %s\n", caminho_log))

if (any(log_final$status == "ERRO")) {
  cat("\nArquivos com erro:\n")
  print(log_final[log_final$status == "ERRO", c("caminho_origem", "erro")])
}
