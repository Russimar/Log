# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Visão Geral

Biblioteca Delphi de logging chamada **GravarLog**, distribuída como pacote Boss. Oferece gravação local em arquivo `.txt` e envio opcional para uma API REST via HTTP, com interface fluente (`IGravarLog`).

## Gerenciamento de Dependências

Usa o **Boss** (gerenciador de pacotes Delphi). O diretório `modules/` é gerado automaticamente e não deve ser versionado.

- Instalar dependências: `boss install`
- Adicionar dependência: `boss install <pacote>`

## Estrutura do Projeto

```
src/
  GravarLog.pas        — Interface IGravarLog e implementação TGravarLog (ponto de entrada)
  GravarLog.Utils.pas  — Enums TLogTipo e TNivelLog com helpers
  GravarLog.Auth.pas   — Geração de Bearer Token via SHA2(AppName:AppKey)
```

`GravarLog.Utils.pas` foi recentemente extraído de `GravarLog.pas` e ainda está como arquivo não rastreado (`??` no git status).

## Compilação Condicional

O comportamento é controlado por defines no topo de `GravarLog.pas`:

| Define | Efeito |
|---|---|
| *(nenhum)* | Apenas log local em arquivo |
| `DESATIVAR_LOG_LOCAL` | Desativa gravação em arquivo |
| `ATIVAR_LOG_NUVEM` | Habilita envio para API REST (ativa `GravarLog.Auth` e HTTP) |
| `CONSOLE` | Também escreve no console via `Writeln` |

Quando `ATIVAR_LOG_NUVEM` está ativo, o envio é feito em background com `TTask.Run` (fire-and-forget). Falhas de rede nunca propagam exceções.

## Uso da Interface

```delphi
// Log simples (legado)
TGravarLog.New.doSaveLog('mensagem', 'arquivo.txt');

// Log estruturado
TGravarLog.New('http://api-server:8080')
  .doSaveLog('Falha ao conectar', ltError, 'TMinhaClasse', 'MeuSistema');
```

O arquivo de log local é criado em `<dir do executável>/Log/<nome_exe><ddmmyyyy>.txt`.

## Autenticação da API

Quando `ATIVAR_LOG_NUVEM` está ativo, o Bearer Token é gerado em `TGravarLogAuth.GerarBearer` como `SHA2(AppName + ':' + AppKey)`. Os valores de `AppName` e `AppKey` são lidos de:
- **Windows**: campo `VersionInfo` do executável
- **Android**: `ApplicationInfo.metaData`
- **Outras plataformas**: retorna string vazia (sem autenticação)

## Endpoint da API

`POST <ServerURL>/log` com body JSON contendo os campos: `tipo`, `mensagem`, e opcionalmente `origem`, `sistema`, `modulo`, `usuario`, `detalhes`, `versao`, `tags`, `dadosAdicionais`.
