# Ride a Fish (Roblox)

Jogo de domar peixes debaixo d'água, inspirado no Rodeo Stampede: você mergulha, pula de peixe em peixe com um arpão, doma os que a sua stamina permite e leva para o aquário, onde eles rendem dinheiro.

**Estado atual: versão 0.1, a primeira versão jogável, para testar no Studio.**

## O que já existe

| Parte | O que tem |
|-------|-----------|
| Mapa | Praia em estilo Lego (studs), 6 lotes, praça com barracas, estátua, placar, zona de mergulho e a pista submarina com 3 áreas (Recife Raso, Floresta de Algas, Abismo), obstáculos, portais e parede de "em breve" no fim |
| Corrida | Mergulho, peixes nadando e desviando, arpão para o peixe marcado, doma por tempo, derrubada por falta de stamina, peixe domado cansa, queda no fundo, reviver, "Voltar à praia" |
| Peixes | 24 espécies (8 por área), 5 raridades, 5 mutações, 5 tamanhos e 3 habilidades (Salto, Turbo, Casco). Um modelo só, que muda cor e proporções |
| Base | Aquário com os peixes nadando dentro e renda por segundo, esteira de treino na frente do aquário, placas para melhorar esteira e aquário |
| Lojas | VENDER PEIXES (com confirmação e proteção dos raros) e AURAS (multiplicador +0.5 na esteira, só com dinheiro do jogo) |
| Telas | HUD (Loja, Índex, Aquário, stamina e dinheiro com "+"), Loja de Robux, Índex com prêmios, Aquário, Vender, Auras, tela da corrida |
| Salvamento | DataStore com trava de sessão (o mesmo esquema do Exploradores de Animais) |

## Como testar no Studio

1. Clone este repositório no computador (VS Code: `Ctrl+Shift+P` > `Git: Clone`).
2. Abra a pasta no PowerShell e rode `rokit install` (instala o Rojo 7.7.1).
3. Rode `rojo serve`. Se o Exploradores de Animais também estiver aberto, use outra porta: `rojo serve --port 34873`.
4. No Roblox Studio, crie um lugar novo (Baseplate), abra a aba **Plugins > Rojo** e clique em **Connect** (na mesma porta).
5. Aperte **Play**. O mapa é construído quando o jogo começa. A base e o spawn padrão do lugar novo são apagados sozinhos.

Para o salvamento funcionar no Studio: publique o jogo e ligue **Game Settings > Security > Enable Studio Access to API Services**. Sem isso, o jogo roda normalmente, mas não salva.

## Controles

| Ação | PC | Celular |
|------|----|---------|
| Começar a corrida | Entrar no anel azul dentro da água | Igual |
| Arpão no peixe marcado / pular | Espaço | Botão PULAR |
| Desviar | A / D (ou setas) | Analógico |
| Treinar stamina | Subir na esteira do seu lote (você fica preso andando; pule para sair) | Igual (botão de pular) |
| Melhorar esteira/aquário | Tecla E perto da placa | Tocar no botão da placa |

As cores embaixo do nome de cada peixe dizem se você consegue domar: **verde ✓** (tem stamina), **amarelo !** (tem 80% ou mais, ainda não dá) e **vermelho ✗**.

## Onde mexer

| Arquivo | Para que serve |
|---------|----------------|
| `src/shared/Config.lua` | Todos os números: stamina inicial, esteira, aquário, corrida, venda, prêmios, Robux |
| `src/shared/Fish.lua` | Os 24 peixes (nome, stamina, renda, velocidade, cores), mutações e tamanhos |
| `src/shared/Progression.lua` | Auras e as contas de esteira, aquário e prêmios |
| `src/shared/Track.lua` | A pista: profundidade, áreas, cores da água, obstáculos e geração dos peixes |
| `src/shared/Layout.lua` | Onde ficam os lotes, barracas, placar e a zona de mergulho |
| `src/shared/FishModel.lua` | O modelo 3D do peixe (peças estilo Lego) |
| `src/server/MapService.lua` | Constrói o mapa inteiro |
| `src/server/RideService.lua` | Confere cada doma no servidor (anti-trapaça) |
| `src/client/RideController.client.lua` | A corrida do lado do jogador |
| `src/client/UIKit.lua` | O visual das telas (botões, janelas, cores) |

Regra de ouro: **dinheiro, stamina e peixes só mudam no servidor**. O cliente desenha a corrida, mas o servidor gera a mesma lista de peixes (mesmo seed) e confere se a doma é possível.

## Robux

Os Ids em `Config.GAMEPASSES` e `Config.PRODUCTS` estão em `0`. Assim:

- no Studio, os botões dão o item de graça, só para você testar;
- no jogo publicado, aparecem como "Em breve" e não cobram nada.

Quando criar os gamepasses e produtos no Creator Hub, troque o `0` pelo número de cada um.

## Ainda não existe (próximos passos)

- Modelos próprios para cada espécie (hoje é um modelo só para todas)
- Roleta com giro grátis a cada 15-30 min e giros premiados do índex
- Canhão para chegar mais rápido a uma área
- Prêmio por completar todas as mutações de um bioma
- Usar peixes já domados na corrida
- Ganho offline e balanceamento geral (os números de hoje são provisórios)
- Os outros jogadores veem você se mexendo, mas não o peixe que você monta (cada corrida é só sua)
