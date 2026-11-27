# Conversão em lote de arquivos .DBC (DATASUS) para Parquet

Script em R que converte, em lote, arquivos `.dbc` do DATASUS (SIA, SIH, SINAN, SIM etc.) para o formato **Parquet**, corrigindo o encoding de Latin-1 para UTF-8 no caminho.

## Por que Parquet

Os `.dbc` do DATASUS são arquivos DBF comprimidos, lentos para ler e sem tipagem confiável. Convertidos para Parquet, ficam muito menores em disco e podem ser lidos de forma seletiva (só as colunas e partições necessárias) com `arrow`, `duckdb` ou `polars`, o que torna viável trabalhar com anos de produção ambulatorial num computador comum ou alimentar um *data lake*.

## Como funciona

O script é guiado por um **CSV de controle** com, no mínimo, as colunas:

| coluna | descrição |
|---|---|
| `caminho_origem` | caminho completo do `.dbc` |
| `caminho_destino` | caminho completo do `.parquet` a gerar (as pastas são criadas se não existirem) |
| `existe_parquet` | `TRUE`/`FALSE` — usada apenas se `somente_pendentes <- TRUE` |

Para cada linha, o arquivo é lido com `read.dbc`, as colunas de texto são recodificadas para UTF-8 e o resultado é gravado com `arrow::write_parquet()`. Erros em um arquivo não interrompem o lote: tudo é registrado em `log_conversao_sia_alterados.csv`, com status, número de linhas e mensagem de erro, e um resumo é impresso ao final.

## Uso

```r
install.packages(c("read.dbc", "arrow", "readr", "dplyr"))
```

1. Monte o CSV de controle (por exemplo, listando os `.dbc` novos ou alterados desde a última execução).
2. No início do script, ajuste `caminho_csv` e, se quiser converter apenas o que falta, `somente_pendentes <- TRUE`.
3. Execute `conversao_dbc_parquet.R`.

Organizar o destino por sistema, UF e ano (por exemplo, `datalake/sia/pa/2026/PADF2601.parquet`) permite depois ler tudo como um único conjunto particionado com `arrow::open_dataset()`.
