# Fase 1 - Incremento 2: motor de progressão local

## Objetivo

Implementar a primeira versão concreta do motor de progressão em Dart puro,
mantendo decisões pedagógicas independentes da interface, persistência e rede.

## Entregue

- `DefaultProgressionEngine` determinístico;
- cálculo dos estados `locked`, `available`, `inProgress` e `completed`;
- desbloqueio local imediato a partir de factos concluídos;
- avaliação de pré-requisitos compostos `ALL` e `ANY`;
- manutenção de caminhos paralelos disponíveis;
- preferências usadas somente para ordenar recomendações;
- atividades iniciadas priorizadas para retoma;
- rejeição de `PathElementId` duplicado em todo o percurso;
- seis testes comportamentais do motor.

## Regras de precedência

1. atividade concluída resulta em `completed`;
2. atividade iniciada resulta em `inProgress`;
3. pré-requisitos satisfeitos resultam em `available`;
4. os restantes elementos ficam `locked`.

## Invariantes

1. O motor não depende de Flutter, SQLite, HTTP ou estado da interface.
2. Uma preferência nunca bloqueia um caminho alternativo.
3. A ordem original do percurso é preservada entre recomendações de igual
   prioridade.
4. A mesma identidade de elemento não pode aparecer duas vezes no percurso.

## Fora do escopo deste incremento

- persistência dos factos e tentativas;
- integração com o mapa Flutter;
- serialização e catálogo remoto;
- sincronização multidispositivo;
- regras editoriais adicionais de recomendação.

## Validação em DEV

Executar a partir de `C:\DEV\Flutter\dailytalk_mobile`:

```powershell
dart format lib\domain\learning test\domain\learning
flutter analyze
flutter test test\domain\learning
flutter test
```

## Versão

Este incremento utiliza `1.0.3+4`. O valor visível enviado pela aplicação é
`1.0.3`.
