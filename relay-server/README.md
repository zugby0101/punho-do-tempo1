# Servidor intermediário (relay) do Punho do Tempo

Com este servidor, os amigos jogam online **sem abrir portas no roteador**:
o anfitrião e os convidados só fazem conexões de saída para o servidor, que
repassa as mensagens entre eles. O jogo continua rodando no computador do anfitrião;
o servidor não processa nada do jogo, então é bem leve.

- Salas com código de 4 letras (até 4 jogadores por sala)
- Uso de banda: cerca de 20–25 KB/s por convidado (medido em teste)
- Só depende do pacote [`ws`](https://www.npmjs.com/package/ws)

## Publicar de graça no Render (recomendado)

1. Crie uma conta em https://render.com (dá para entrar com o GitHub).
2. Clique em **New + → Blueprint** e escolha o repositório do jogo.
   O arquivo `render.yaml` na raiz já configura tudo (plano gratuito).
3. Quando terminar, o Render mostra um endereço como
   `https://punho-do-tempo-relay.onrender.com`.
4. No jogo: **O → CONFIGURAR SERVIDOR** e digite o endereço trocando `https://` por `wss://`
   (ou só `punho-do-tempo-relay.onrender.com` — o jogo completa).

> O plano gratuito do Render "dorme" depois de ~15 minutos sem uso e leva
> cerca de 1 minuto para acordar. Se a conexão falhar na primeira tentativa,
> abra o endereço no navegador, espere aparecer "Punho do Tempo relay OK" e tente de novo.

Para que todo mundo que baixar o jogo já use o seu servidor, coloque o endereço em
`DEFAULT_RELAY_URL` no arquivo `scripts/net.gd`.

## Outras opções

- **Railway / Fly.io / Koyeb**: qualquer serviço que rode Node.js ou Docker e aceite
  WebSocket funciona. Use o `Dockerfile` desta pasta; a porta vem da variável `PORT`.
- **VPS própria** (ou um computador sempre ligado):
  ```bash
  cd relay-server
  npm install --omit=dev
  PORT=8080 node server.js
  ```
  Nesse caso só o servidor precisa da porta liberada — os jogadores não.
  Para usar `wss://` (recomendado), coloque-o atrás de um proxy com HTTPS (Caddy, Nginx).

## Rodar e testar localmente

```bash
cd relay-server
npm install
npm test          # teste automático: cria sala, entra, troca mensagens, encerra
npm start         # servidor em ws://localhost:8080
```

`STATS=1 npm start` mostra o tráfego a cada 10 segundos.

## Protocolo (resumo)

- Texto (JSON) para controle: `{"op":"host"}` → `{"op":"hosted","room":"ABCD"}`;
  `{"op":"join","room":"ABCD"}` → `{"op":"joined","id":2}`; o anfitrião recebe
  `peer_join` / `peer_leave`; os convidados recebem `room_closed` se o anfitrião sair.
- Binário para o jogo: o anfitrião envia `[2 bytes de destino (0 = todos)] + dados`;
  cada convidado envia só `dados` e o anfitrião recebe `[2 bytes com o id do convidado] + dados`.
