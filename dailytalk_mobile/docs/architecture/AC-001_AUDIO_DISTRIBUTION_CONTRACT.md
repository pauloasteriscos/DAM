# AC-001 - Contrato de Distribuição de Áudio por Idioma e Fase

## Unidade
A unidade de distribuição é `idioma + fase`, não o caminho de prática.

## Seed
As Lições 1 e 2 de cada fase constituem o conjunto inicial de áudio disponível.

## Gatilho de expansão
A conclusão durável local da Lição 1, quando produz progresso apto a sincronização, autoriza a obtenção dos restantes áudios da mesma combinação `idioma + fase`.

Abrir e abandonar uma atividade sem conclusão não autoriza download.

Não é necessário aguardar ACK remoto.

## Offline-first
Se a conclusão ocorrer offline, a intenção fica pendente até regressar conectividade.

## Reprodução
Tocar no áudio nunca inicia download de rede.
O áudio só é reproduzível quando o asset já está local e validado.

## Validação individual
Transferência concluída -> MIME válido -> tamanho válido -> SHA-256 válido -> cache local -> áudio disponível.

## Independência pedagógica
A ausência de áudio nunca bloqueia execução, conclusão ou sincronização da atividade.
